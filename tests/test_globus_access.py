"""Exercise Globus preflight against a fake service, without login or network.

Unlike route-only dry runs, these tests execute the queue/wait flow and prove
that a rejected local folder cannot submit a transfer or start an SSH copy.
"""
from __future__ import annotations

import json
import os
import shlex
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts/chpc-globus.sh"
LOCAL = "00000000-0000-0000-0000-000000000000"
SCRATCH = "/mnt/scratch/user/testuser"


class LocalAccess(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.project = self.root / "projects with spaces" / "my project"
        self.project.mkdir(parents=True)
        self.log = self.root / "calls.jsonl"
        local_env = self.root / "chpc.env.local"
        local_env.write_text("")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        fake = bin_dir / "globus"
        fake.write_text(f"#!{sys.executable}\n" + '''import json, os, sys
args = sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps(args) + "\\n")
if args[0] == "ls":
    if os.environ.get("DENY_PATH") == args[1]:
        print("ExternalError: Path not allowed: local accessible folders reject this path", file=sys.stderr)
        sys.exit(1)
elif args[0] == "stat": print(os.environ.get("SOURCE_TYPE", "dir"))
elif args[0] == "whoami": print("lab-user@example.edu")
elif args[:2] == ["endpoint", "local-id"]: print(os.environ["CHPC_GLOBUS_LOCAL_COLLECTION"])
elif args[0] == "transfer" or args[:4] == ["api", "transfer", "post", "/transfer"]: print("test-task-id")
elif args[:2] == ["task", "generate-submission-id"]: print("test-submission-id")
elif args[:2] == ["task", "show"]: print("SUCCEEDED")
elif args[:2] == ["task", "wait"]:
    print("Task completed")
    sys.exit(int(os.environ.get("WAIT_FAIL", "0")))
''')
        fake.chmod(0o755)
        # Detect accidental SSH in scratch routes. Doctor may check a session.
        ssh = bin_dir / "ssh"
        ssh.write_text(f"#!{sys.executable}\n" + '''import json, os, sys
with open(os.environ["CALL_LOG"], "a") as log:
    log.write(json.dumps(["ssh"] + sys.argv[1:]) + "\\n")
sys.exit(0)
''')
        ssh.chmod(0o755)
        self.env = {
            **os.environ,
            "PATH": f"{bin_dir}:{os.environ['PATH']}",
            "GLOBUS": str(fake),
            "CALL_LOG": str(self.log),
            "CHPC_ENV_LOCAL": str(local_env),
            "CHPC_USER": "testuser",
            "CHPC_HOST": "test-chpc",
            "FAC_SHARE": "TEST_SHARE",
            "CHPC_GLOBUS_LOCAL_COLLECTION": LOCAL,
            "CHPC_GLOBUS_LOCAL_ROOT": "/",
            "CHPC_GLOBUS_STAGING_LOCAL": "",
            "CHPC_GLOBUS_STAGING": f"{SCRATCH}/globus-staging",
        }

    def invoke(self, *args: str, **env: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/bash", str(SCRIPT), *args],
            env={**self.env, **env}, text=True, capture_output=True, check=False,
        )

    def calls(self) -> list[list[str]]:
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_direct_push_checks_selected_project_and_passes_transfer_options(self) -> None:
        done = self.invoke("push", str(self.project), f"{SCRATCH}/project", "--exclude", ".git", "--exclude", "*.tmp", "--sync-level", "checksum")
        self.assertEqual(done.returncode, 0, done.stderr)
        calls = self.calls()
        self.assertEqual(calls[0], ["ls", f"{LOCAL}:{self.project}"])
        transfer = next(call for call in calls if call[0] == "transfer")
        self.assertEqual(transfer[1], f"{LOCAL}:{self.project}")
        self.assertEqual(transfer[-6:], ["--exclude", ".git", "--exclude", "*.tmp", "--sync-level", "checksum"])
        self.assertNotIn("--delete-destination-extra", transfer)
        self.assertFalse(any(call[0] == "ssh" for call in calls))
        self.assertEqual(done.stdout.strip(), "test-task-id")

    def test_denied_project_preserves_error_and_never_queues_or_copies(self) -> None:
        done = self.invoke("push", str(self.project), "/mnt/fac/TEST_SHARE/project", DENY_PATH=f"{LOCAL}:{self.project}")
        self.assertEqual(done.returncode, 1)
        self.assertIn("ExternalError: Path not allowed", done.stderr)
        self.assertIn("Globus Connect Personal: Settings/Preferences > Access", done.stderr)
        self.assertNotIn("CHPC_GLOBUS_STAGING_LOCAL is unset", done.stderr)
        self.assertEqual([call[0] for call in self.calls()], ["ls"])

    def test_file_source_checks_its_parent(self) -> None:
        source = self.project / "input with spaces.json"
        source.write_text("{}")
        done = self.invoke("push", str(source), f"{SCRATCH}/input.json")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.calls()[0], ["ls", f"{LOCAL}:{self.project}"])
        transfer = next(call for call in self.calls() if call[0] == "transfer")
        self.assertIn("--no-recursive", transfer)

    def test_new_pull_destination_checks_existing_parent_without_ssh(self) -> None:
        target = self.project / "new results" / "run 1"
        done = self.invoke("pull", f"{SCRATCH}/output", str(target))
        self.assertEqual(done.returncode, 0, done.stderr)
        calls = self.calls()
        self.assertEqual(calls[0], ["ls", f"{LOCAL}:{self.project}"])
        self.assertEqual(calls[1][0], "stat")
        self.assertFalse(any(call[0] == "ssh" for call in calls))
        transfer = next(call for call in calls if call[0] == "transfer")
        self.assertEqual(transfer[2], f"{LOCAL}:{target}")

    def test_pull_detects_file_using_globus(self) -> None:
        done = self.invoke("pull", f"{SCRATCH}/output.txt", str(self.project / "output.txt"), SOURCE_TYPE="file")
        self.assertEqual(done.returncode, 0, done.stderr)
        transfer = next(call for call in self.calls() if call[0] == "transfer")
        self.assertIn("--no-recursive", transfer)
        self.assertFalse(any(call[0] == "ssh" for call in self.calls()))

    def test_missing_source_type_aborts_instead_of_assuming_file(self) -> None:
        done = self.invoke("pull", f"{SCRATCH}/missing", str(self.project / "output"), SOURCE_TYPE="null")
        self.assertEqual(done.returncode, 1)
        self.assertIn("cannot determine source type", done.stderr)
        self.assertFalse(any(call[0] == "transfer" for call in self.calls()))

    def test_doctor_defaults_to_project_without_optional_staging(self) -> None:
        done = self.invoke("doctor")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn(["ls", f"{LOCAL}:{REPO}"], self.calls())
        self.assertIn("direct project transfers do not need", done.stdout)

    def test_doctor_checks_selected_file_parent_and_ignores_stale_staging(self) -> None:
        source = self.project / "input.json"
        source.write_text("{}")
        done = self.invoke("doctor", str(source), CHPC_GLOBUS_STAGING_LOCAL="/old/deleted/staging")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn(["ls", f"{LOCAL}:{self.project}"], self.calls())
        self.assertIn("optional fallback", done.stdout)
        self.assertFalse(any("/old/deleted" in " ".join(call) for call in self.calls()))

    def test_doctor_fails_for_denied_project_even_if_staging_configured(self) -> None:
        done = self.invoke("doctor", str(self.project), DENY_PATH=f"{LOCAL}:{self.project}", CHPC_GLOBUS_STAGING_LOCAL=str(self.root))
        self.assertEqual(done.returncode, 1)
        self.assertIn("Path not allowed", done.stderr)
        self.assertRegex(done.stdout, r"local_project\s+fail")

    def test_dry_run_makes_no_service_or_ssh_calls(self) -> None:
        done = self.invoke("push", str(self.project), f"{SCRATCH}/project", "--dry-run", "--wait", "0")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.calls(), [])
        self.assertIn("access check skipped", done.stderr)
        self.assertNotIn("task wait", done.stdout)

    def test_zero_wait_fac_push_never_queues(self) -> None:
        done = self.invoke("push", str(self.project), "/mnt/fac/TEST_SHARE/project", "--wait", "0")
        self.assertEqual(done.returncode, 1)
        self.assertIn("must finish before", done.stderr)
        self.assertFalse(any(call[0] in ("transfer", "ssh") for call in self.calls()))

    def test_root_boundary_and_dotdot_are_not_mapped_to_wrong_folder(self) -> None:
        sibling = self.project.parent / "my project-extra"
        sibling.mkdir()
        done = self.invoke("push", str(sibling), f"{SCRATCH}/project", CHPC_GLOBUS_LOCAL_ROOT=str(self.project))
        self.assertEqual(done.returncode, 1)
        self.assertIn("not under the collection root", done.stderr)
        done = self.invoke("push", str(self.project / ".." / sibling.name), f"{SCRATCH}/project", CHPC_GLOBUS_LOCAL_ROOT=str(self.project))
        self.assertEqual(done.returncode, 1)
        self.assertEqual(self.calls(), [])

    def test_custom_collection_root_maps_project_to_slash(self) -> None:
        done = self.invoke("push", str(self.project) + "/", f"{SCRATCH}/project", CHPC_GLOBUS_LOCAL_ROOT=str(self.project) + "/")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.calls()[0], ["ls", f"{LOCAL}:/"])
        transfer = next(call for call in self.calls() if call[0] == "transfer")
        self.assertEqual(transfer[1], f"{LOCAL}:/")

    def test_directory_exclusions_submit_real_api_rules_for_whole_subtrees(self) -> None:
        done = self.invoke("push", str(self.project), f"{SCRATCH}/project", "--exclude-dir", ".git", "--exclude-dir", ".venv", "--exclude", "*.pyc", "--sync-level", "checksum")
        self.assertEqual(done.returncode, 0, done.stderr)
        calls = self.calls()
        api = next(call for call in calls if call[0] == "api")
        request = json.loads(api[api.index("--body") + 1])
        self.assertEqual(request["submission_id"], "test-submission-id")
        self.assertEqual(request["DATA"], [{"DATA_TYPE": "transfer_item", "source_path": str(self.project), "destination_path": "/project", "recursive": True}])
        self.assertEqual(request["filter_rules"], [
            {"DATA_TYPE": "filter_rule", "method": "exclude", "name": "*.pyc", "type": "file"},
            {"DATA_TYPE": "filter_rule", "method": "exclude", "name": ".git", "type": "dir"},
            {"DATA_TYPE": "filter_rule", "method": "exclude", "name": ".venv", "type": "dir"},
        ])
        self.assertEqual(request["sync_level"], 3)
        self.assertTrue(request["verify_checksum"])
        self.assertFalse(request["notify_on_succeeded"])
        self.assertNotIn("delete_destination_extra", request)
        self.assertEqual(done.stdout.strip(), "test-task-id")

    def test_offline_preview_contains_parseable_directory_filter_request(self) -> None:
        done = self.invoke("push", str(self.project), f"{SCRATCH}/project", "--exclude-dir", ".git", "--exclude-dir", "cache [12]", "--label", "my \"label\"", "--dry-run")
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(self.calls(), [])
        api_line = next(line for line in done.stdout.splitlines() if " api transfer post " in line)
        argv = shlex.split(api_line)[1:]
        request = json.loads(argv[argv.index("--body") + 1])
        self.assertEqual(request["label"], 'my "label"')
        self.assertEqual(request["submission_id"], "<submission-id>")
        self.assertEqual(request["filter_rules"][1]["name"], "cache [12]")
        self.assertEqual(request["filter_rules"][1]["type"], "dir")
        self.assertIn("skip entire matching subtrees", done.stderr)

    def test_wait_failure_stops_fac_copy(self) -> None:
        done = self.invoke("push", str(self.project), "/mnt/fac/TEST_SHARE/project", WAIT_FAIL="1")
        self.assertEqual(done.returncode, 1)
        self.assertIn("Inspect its status", done.stderr)
        self.assertFalse(any(call[0] == "ssh" for call in self.calls()))

    def test_symlink_parent_path_is_rejected_instead_of_transferring_wrong_file(self) -> None:
        elsewhere = self.root / "elsewhere"
        (elsewhere / "child").mkdir(parents=True)
        (elsewhere / "input.txt").write_text("requested")
        (self.project / "input.txt").write_text("wrong")
        (self.project / "link").symlink_to(elsewhere / "child", target_is_directory=True)
        done = self.invoke("push", str(self.project / "link" / ".." / "input.txt"), f"{SCRATCH}/input.txt")
        self.assertEqual(done.returncode, 1)
        self.assertIn("ambiguous across symlinks", done.stderr)
        self.assertEqual(self.calls(), [])

    def test_invalid_and_missing_option_values_are_actionable(self) -> None:
        for options, expected in [(("--wait", "-1"), "non-negative integer"), (("--exclude",), "needs a value"), (("--sync-level", "fast"), "must be exists"), (("--type", "folder"), "must be file or directory")]:
            with self.subTest(options=options):
                done = self.invoke("push", str(self.project), f"{SCRATCH}/project", *options)
                self.assertEqual(done.returncode, 1)
                self.assertIn(expected, done.stderr)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
