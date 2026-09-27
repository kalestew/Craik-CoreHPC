"""Dispatch must finish both Globus transfers before a single sbatch transaction.

Exercise the real dispatcher, Globus route builder and Transfer API body with
fake external CLIs. Separately run the actual remote helper against a temporary
checkout and a recording sbatch. Nothing reaches a network or queues a real job.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
DIRECTORY_EXCLUSIONS = {".git", ".venv", ".chpc", "out", "outputs", "results", "logs", "prepared", "__pycache__"}


def executable(path, source):
    path.write_text(f"#!{sys.executable}\n" + source)
    path.chmod(0o755)


class SubmitTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="chpc-submit-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.repo = self.root / "checkout with spaces"
        (self.repo / "scripts/lib").mkdir(parents=True)
        (self.repo / "lab").mkdir()
        for relative in ("env.sh", "lab/chpc.env", "scripts/chpc-submit.sh",
                         "scripts/chpc-submit-remote.sh", "scripts/chpc-globus.sh",
                         "scripts/chpc-prime.sh", "scripts/lib/globus_transfer_request.py"):
            shutil.copy2(REPO / relative, self.repo / relative)
        self.source = self.root / "selected job's inputs"
        self.source.mkdir()
        (self.source / "run.sbatch").write_text("#!/bin/bash\necho example\n")
        (self.source / "input.txt").write_text("scientific input\n")
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.events = self.root / "events.jsonl"
        self.local = self.root / "local.env"
        self.local.write_text("")
        executable(self.bin / "globus", '''
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ['EVENTS'], 'a') as stream:
    stream.write(json.dumps({'kind': 'globus', 'args': args}) + '\\n')
if args[0] == 'ls':
    sys.exit(0)
if args[:2] == ['task', 'generate-submission-id']:
    print('11111111-1111-1111-1111-111111111111')
elif args[0] == 'transfer' or args[:3] == ['api', 'transfer', 'post']:
    counter = pathlib.Path(os.environ['COUNTER'])
    number = int(counter.read_text()) + 1 if counter.exists() else 1
    counter.write_text(str(number))
    print('00000000-0000-0000-0000-%012d' % number)
elif args[:2] == ['task', 'wait']:
    number = int(args[2].split('-')[-1])
    if str(number) == os.environ.get('FAIL_WAIT'):
        print('transfer is still pending', file=sys.stderr)
        sys.exit(7)
elif args[:2] == ['task', 'show']:
    number = int(args[2].split('-')[-1])
    print('FAILED' if str(number) == os.environ.get('FAIL_STATUS') else 'SUCCEEDED')
else:
    raise SystemExit('unexpected globus command: ' + repr(args))
''')
        executable(self.bin / "ssh", '''
import json, os, sys
args = sys.argv[1:]
with open(os.environ['EVENTS'], 'a') as stream:
    stream.write(json.dumps({'kind': 'ssh', 'args': args}) + '\\n')
if args[:2] == ['-O', 'check']:
    sys.exit(0)
if os.environ.get('SSH_FAIL'):
    print('connection lost after remote execution', file=sys.stderr)
    sys.exit(255)
print(os.environ.get('JOB_RESPONSE', '12345'))
''')
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(('CHPC_', 'SBATCH_', 'SLURM_'))}
        self.env.update(PATH=f"{self.bin}:{self.env['PATH']}", EVENTS=str(self.events),
                        COUNTER=str(self.root / "counter"), CHPC_USER="testuser",
                        CHPC_HOST="test-chpc", CHPC_ENV_LOCAL=str(self.local),
                        CHPC_GLOBUS_LOCAL_COLLECTION="aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                        CHPC_GLOBUS_LOCAL_ROOT=str(self.root), FAC_SHARE="TEST_SHARE",
                        COREHPC="/Users/laptop/old-corehpc")

    def invoke(self, *arguments, script="run.sbatch", **overrides):
        return subprocess.run(["/bin/bash", str(self.repo / "scripts/chpc-submit.sh"),
                               str(self.source), script, *arguments], env={**self.env, **overrides},
                              text=True, capture_output=True, timeout=30)

    def recorded(self):
        return [json.loads(line) for line in self.events.read_text().splitlines()] if self.events.exists() else []

    def receipt(self):
        return Path((self.repo / ".chpc/submissions/latest").read_text().strip())

    def test_dry_run_is_offline_and_creates_no_receipt(self):
        before = set(self.root.rglob("*"))
        result = self.invoke("--dry-run", "--", "boltz")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.recorded(), [])
        self.assertEqual(set(self.root.rglob("*")), before)
        self.assertIn("AFTER BOTH SUCCEED", result.stdout)
        self.assertIn("not the local checkout's registry", result.stderr)

    def test_both_successful_transfers_precede_ssh_and_receipt_names_the_log(self):
        result = self.invoke("--", "boltz")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "12345")
        events = self.recorded()
        show_indices = [i for i, event in enumerate(events)
                        if event["kind"] == "globus" and event["args"][:2] == ["task", "show"]]
        ssh_indices = [i for i, event in enumerate(events) if event["kind"] == "ssh"]
        self.assertEqual(len(show_indices), 2)
        self.assertLess(max(show_indices), min(ssh_indices))
        receipt = self.receipt()
        remote = (receipt / "remote-dir.txt").read_text().strip()
        self.assertTrue(remote.startswith("/mnt/scratch/user/testuser/chpc-run-"))
        self.assertEqual((receipt / "job-id.txt").read_text(), "12345\n")
        self.assertEqual((receipt / "status.txt").read_text(), "submitted\n")
        self.assertEqual((receipt / "log-path.txt").read_text(), remote + "/logs/slurm-12345.out\n")
        self.assertTrue((receipt / "transfer-inputs.txt").read_text().strip().endswith("000001"))
        self.assertTrue((receipt / "transfer-helper.txt").read_text().strip().endswith("000002"))

    def test_actual_api_request_excludes_directory_subtrees_and_only_selected_folder(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        request_call = next(event["args"] for event in self.recorded()
                            if event["kind"] == "globus" and event["args"][:3] == ["api", "transfer", "post"])
        request = json.loads(request_call[request_call.index("--body") + 1])
        self.assertEqual(request["DATA"][0]["source_path"], "/" + self.source.name)
        self.assertTrue(request["DATA"][0]["recursive"])
        self.assertTrue(request["verify_checksum"])
        filters = request["filter_rules"]
        self.assertEqual({rule["name"] for rule in filters if rule["type"] == "dir"}, DIRECTORY_EXCLUSIONS)
        self.assertEqual({rule["name"] for rule in filters if rule["type"] == "file"}, {".git", ".env", "chpc.env.local", "*.pyc"})
        helper = next(event["args"] for event in self.recorded()
                      if event["kind"] == "globus" and event["args"][0] == "transfer")
        self.assertIn("chpc-submit-remote.sh", helper[1])
        self.assertIn("/.chpc/submit/remote.sh", helper[2])
        self.assertIn("--no-recursive", helper)

    def test_failed_or_pending_transfer_never_reaches_ssh_or_sbatch(self):
        for environment in ({"FAIL_WAIT": "1"}, {"FAIL_WAIT": "2"}, {"FAIL_STATUS": "1"}, {"FAIL_STATUS": "2"}):
            with self.subTest(environment=environment):
                self.events.unlink(missing_ok=True)
                (self.root / "counter").unlink(missing_ok=True)
                result = self.invoke(**environment)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(event["kind"] == "ssh" for event in self.recorded()))
                self.assertFalse((self.receipt() / "job-id.txt").exists())
                self.assertIn("no job submitted", result.stderr)

    def test_shell_metacharacters_in_arguments_are_not_interpolated_into_ssh(self):
        argument = "a quoted ' argument; $(touch SHOULD_NOT_EXIST)"
        result = self.invoke("--corehpc", "/home/testuser/core hpc", "--", "protenix", argument)
        self.assertEqual(result.returncode, 0, result.stderr)
        command = (self.receipt() / "command.txt").read_text().strip()
        words = shlex.split(command)
        self.assertEqual(words[-3:], ["--", "protenix", argument])
        self.assertIn("/home/testuser/core hpc", words)
        self.assertNotIn("/Users/laptop/old-corehpc", command)

    def test_absent_or_invalid_job_response_is_preserved_as_uncertain(self):
        for environment in ({"SSH_FAIL": "1"}, {"JOB_RESPONSE": "login banner\n12345"}):
            with self.subTest(environment=environment):
                result = self.invoke(**environment)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.receipt() / "status.txt").read_text(), "submission-response-unknown\n")
                self.assertFalse((self.receipt() / "job-id.txt").exists())
                self.assertTrue((self.receipt() / "command.txt").is_file())

    def test_bad_paths_and_nonblocking_wait_are_rejected_before_any_transfer(self):
        (self.source / "results").mkdir()
        (self.source / "results/run.sbatch").write_text("#!/bin/bash\n")
        (self.source / "linked.sbatch").symlink_to(self.source / "run.sbatch")
        cases = (("../run.sbatch", ()), ("results/run.sbatch", ()), ("linked.sbatch", ()),
                 ("run.sbatch", ("--wait", "0")), ("run.sbatch", ("--corehpc", "/Users/me/corehpc")))
        for script, arguments in cases:
            with self.subTest(script=script, arguments=arguments):
                result = self.invoke(*arguments, script=script)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.recorded(), [])
                self.assertFalse((self.repo / ".chpc").exists())

    def test_included_symlink_inputs_are_rejected_but_excluded_subtrees_are_ignored(self):
        (self.source / "linked-input.txt").symlink_to(self.source / "input.txt")
        result = self.invoke("--dry-run")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("included symlinks", result.stderr)
        self.assertEqual(self.recorded(), [])
        (self.source / "linked-input.txt").unlink()
        (self.source / ".venv").symlink_to(self.root, target_is_directory=True)
        (self.source / ".git").write_text("gitdir: ../../ignored-submodule-metadata\n")
        result = self.invoke("--dry-run")
        self.assertEqual(result.returncode, 0, result.stderr)


class RemoteSubmitTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="chpc-submit-remote-")
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.work = self.root / "work folder"
        self.work.mkdir()
        (self.work / "job.sbatch").write_text("#!/bin/bash\n")
        self.checkout = self.root / "cluster checkout"
        self.checkout.mkdir()
        (self.checkout / "lab/bin").mkdir(parents=True)
        executable(self.checkout / "lab/bin/chpc-tool", "print('chosen checkout')\n")
        (self.checkout / "env.sh").write_text('''
printf '%s\\n' "CHPC_ENV_LOCAL=${CHPC_ENV_LOCAL-unset}" "CHPC_TOOLS=${CHPC_TOOLS-unset}" "CHPC_ENV=${CHPC_ENV-unset}" "CHPC_REPO=${CHPC_REPO-unset}" "CHPC_PROJECT=${CHPC_PROJECT-unset}" > "$ENV_CAPTURE"
export CHPC_ENV="$COREHPC/lab/chpc.env"
export CHPC_TOOLS="$COREHPC/tools"
''')
        self.bin = self.root / "bin"
        self.bin.mkdir()
        executable(self.bin / "sbatch", '''
import json, os, sys, time
with open(os.environ['EVENTS'], 'a') as stream:
    stream.write(json.dumps({'args': sys.argv[1:], 'env': {key: os.environ.get(key) for key in ('COREHPC', 'CHPC_ENV_LOCAL', 'CHPC_ENV', 'CHPC_TOOLS', 'CHPC_REPO', 'CHPC_PROJECT', 'FAC_SHARE', 'WORKDIR', 'PATH')}}) + '\\n')
time.sleep(float(os.environ.get('SBATCH_DELAY', '0')))
if os.environ.get('SBATCH_FAIL'):
    print('scheduler refused submission', file=sys.stderr)
    sys.exit(1)
print(os.environ.get('JOB_RESPONSE', '23456;cluster'))
''')
        self.events = self.root / "events.jsonl"
        self.env = {**os.environ, "PATH": f"{self.bin}:{os.environ['PATH']}", "EVENTS": str(self.events),
                    "ENV_CAPTURE": str(self.root / "environment-before-source.txt"),
                    "COREHPC": "/Users/laptop/corehpc", "CHPC_ENV_LOCAL": "/Users/laptop/config",
                    "CHPC_ENV": "/Users/laptop/lab/chpc.env", "CHPC_TOOLS": "/Users/laptop/tools",
                    "CHPC_REPO": "/Users/laptop/repo", "CHPC_PROJECT": "/Users/laptop/project",
                    "WORKDIR": "/Users/laptop/old-work"}
        self.command = ["/bin/bash", str(REPO / "scripts/chpc-submit-remote.sh"), str(self.work),
                        "job.sbatch", "TEST_SHARE", str(self.checkout), "--"]

    def invoke(self, *arguments, **overrides):
        return subprocess.run([*self.command, *arguments], env={**self.env, **overrides},
                              text=True, capture_output=True, timeout=30)

    def recorded(self):
        return [json.loads(line) for line in self.events.read_text().splitlines()] if self.events.exists() else []

    def test_remote_helper_clears_laptop_paths_and_persists_exact_job_and_log_paths(self):
        argument = "spaces ; $(not-a-command) ' literal"
        result = self.invoke("boltz", argument)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "23456;cluster")
        call, = self.recorded()
        self.assertEqual(call["args"][-3:], ["./job.sbatch", "boltz", argument])
        self.assertIn(f"--output={self.work}/logs/slurm-%j.out", call["args"])
        self.assertIn(f"--error={self.work}/logs/slurm-%j.out", call["args"])
        self.assertIn(f"--chdir={self.work}", call["args"])
        self.assertNotIn("/Users/", json.dumps({key: value for key, value in call["env"].items() if key != "PATH"}))
        self.assertEqual(call["env"]["COREHPC"], str(self.checkout))
        self.assertEqual(call["env"]["WORKDIR"], str(self.work))
        self.assertEqual(call["env"]["PATH"].split(":", 1)[0], str(self.checkout / "lab/bin"))
        self.assertTrue(all(line.endswith("=unset") for line in (self.root / "environment-before-source.txt").read_text().splitlines()))
        self.assertEqual((self.work / ".chpc/submit/job-id.txt").read_text(), "23456\n")

    def test_repeating_same_request_recovers_job_id_without_resubmitting(self):
        first = self.invoke("boltz")
        second = self.invoke("boltz")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(first.stdout, second.stdout)
        self.assertEqual(len(self.recorded()), 1)
        changed = self.invoke("chai1")
        self.assertNotEqual(changed.returncode, 0)
        self.assertEqual(len(self.recorded()), 1)

    def test_saved_raw_sbatch_result_recovers_even_if_final_receipt_write_was_interrupted(self):
        first = self.invoke()
        self.assertEqual(first.returncode, 0, first.stderr)
        (self.work / ".chpc/submit/job-id.txt").unlink()
        recovered = self.invoke()
        self.assertEqual(recovered.returncode, 0, recovered.stderr)
        self.assertEqual(len(self.recorded()), 1)
        self.assertEqual((self.work / ".chpc/submit/job-id.txt").read_text(), "23456\n")

    def test_failed_sbatch_keeps_guard_and_does_not_retry_automatically(self):
        first = self.invoke(SBATCH_FAIL="1")
        second = self.invoke()
        self.assertNotEqual(first.returncode, 0)
        self.assertNotEqual(second.returncode, 0)
        self.assertEqual(len(self.recorded()), 1)
        self.assertFalse((self.work / ".chpc/submit/job-id.txt").exists())

    def test_missing_installation_can_be_fixed_before_retry_without_an_uncertain_job(self):
        source = self.checkout / "env.sh"
        content = source.read_text()
        source.unlink()
        failed = self.invoke()
        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(self.recorded(), [])
        self.assertFalse((self.work / ".chpc/submit/submit.lock").exists())
        source.write_text(content)
        fixed = self.invoke()
        self.assertEqual(fixed.returncode, 0, fixed.stderr)
        self.assertEqual(len(self.recorded()), 1)

    def test_batch_filename_beginning_with_dash_cannot_be_an_sbatch_option(self):
        (self.work / "-job.sbatch").write_text("#!/bin/bash\n")
        self.command[self.command.index("job.sbatch")] = "-job.sbatch"
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.recorded()[0]["args"][-1], "./-job.sbatch")

    def test_selected_checkout_wins_when_its_bin_already_follows_a_stale_checkout(self):
        stale = self.root / "old checkout/bin"
        stale.mkdir(parents=True)
        executable(stale / "chpc-tool", "print('wrong checkout')\n")
        self.env["PATH"] = f"{stale}:{self.bin}:{self.checkout / 'lab/bin'}:{os.environ['PATH']}"
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        resolved = next(line for line in (self.work / ".chpc/submit/environment.txt").read_text().splitlines()
                        if line.startswith("chpc_tool: "))
        self.assertEqual(resolved, f"chpc_tool: {self.checkout / 'lab/bin/chpc-tool'}")

    def test_concurrent_recovery_cannot_start_two_jobs(self):
        first = subprocess.Popen(self.command, env={**self.env, "SBATCH_DELAY": "0.2"},
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        second = subprocess.Popen(self.command, env={**self.env, "SBATCH_DELAY": "0.2"},
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        first.communicate(timeout=30)
        second.communicate(timeout=30)
        self.assertIn(0, (first.returncode, second.returncode))
        self.assertEqual(len(self.recorded()), 1)


if __name__ == "__main__":
    unittest.main()
