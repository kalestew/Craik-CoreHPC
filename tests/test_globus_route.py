"""A Globus transfer to the lab share has two legs, and the order is the point.

There is no Globus collection on FAC. So anything persistent moves in two
steps -- one Globus transfer to or from user scratch, and one cluster-local
copy -- and the failure this file exists to prevent is the one that reports
success: a transfer of a buffer that has not been filled yet, or a transfer
into a collection path computed against the wrong root, which lands the data
one directory from where it was asked for and tells nobody.

Everything here runs `chpc-globus.sh --dry-run`, which prints each command
instead of running it, so the whole route is asserted with no Globus account,
no login and no cluster.
"""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / "scripts/chpc-globus.sh"

SCRATCH_COLLECTION = "dd241e70-0935-4f48-b8c0-1351bc1e2c43"
LOCAL_COLLECTION = "00000000-0000-0000-0000-000000000000"


class Route(unittest.TestCase):
    """Compose a route in a controlled environment and read back the commands."""

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)

        # A `globus` that exists and does nothing, so `command -v` succeeds
        # without the test needing the real CLI.
        stub_bin = root / "bin"
        stub_bin.mkdir()
        (stub_bin / "globus").write_text("#!/bin/sh\nexit 0\n")
        (stub_bin / "globus").chmod(0o755)

        # An EMPTY local override, so env.sh does not reach the developer's own
        # chpc.env.local and this test says the same thing on every machine.
        self.local_env = root / "chpc.env.local"
        self.local_env.write_text("")

        self.source = root / "outputs"
        self.source.mkdir()
        self.staging_local = root / "staging"
        self.staging_local.mkdir()

    def compose(self, *args: str, **overrides: str) -> list[str]:
        """Run one dry-run invocation and return its lines, stderr included."""
        env = dict(os.environ)
        env.pop("CHPC_GLOBUS_LOCAL_COLLECTION", None)
        env.update(
            PATH=f"{self.tmp.name}/bin:{env['PATH']}",
            CHPC_ENV_LOCAL=str(self.local_env),
            CHPC_USER="testuser",
            CHPC_HOST="test-chpc",
            FAC_SHARE="TEST_SHARE",
            CHPC_GLOBUS_LOCAL_COLLECTION=LOCAL_COLLECTION,
            CHPC_GLOBUS_LOCAL_ROOT=str(self.tmp.name),
            CHPC_GLOBUS_STAGING_LOCAL=str(self.staging_local),
        )
        env.update(overrides)
        done = subprocess.run(
            ["bash", str(SCRIPT), *args, "--dry-run"],
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )
        self.assertEqual(done.returncode, 0, f"stderr:\n{done.stderr}")
        return [line for line in (done.stdout + done.stderr).splitlines() if line.strip()]

    # ── one leg ──────────────────────────────────────────────────────────────

    def test_a_transfer_inside_the_scratch_collection_is_one_leg(self) -> None:
        """Scratch IS a collection, so nothing needs a second hop or an ssh."""
        lines = self.compose("push", str(self.source), "/mnt/scratch/user/testuser/inbox")
        transfers = [line for line in lines if " transfer " in line]
        self.assertEqual(len(transfers), 1, lines)
        self.assertEqual([line for line in lines if line.startswith("SSH")], [], lines)
        self.assertIn(f"{SCRATCH_COLLECTION}:/inbox", transfers[0])

    def test_the_collection_path_is_the_posix_path_minus_the_root(self) -> None:
        """The relocation bug, asserted directly.

        `/mnt/scratch/user/testuser/a/b` is `/a/b` inside the collection, not
        the POSIX path and not the basename. Passing the POSIX path through
        transfers successfully into `/mnt/scratch/user/testuser/mnt/...`, and
        nothing downstream can tell.
        """
        lines = self.compose("push", str(self.source), "/mnt/scratch/user/testuser/a/b")
        transfer = next(line for line in lines if " transfer " in line)
        self.assertIn(f"{SCRATCH_COLLECTION}:/a/b", transfer)
        self.assertNotIn(f"{SCRATCH_COLLECTION}:/mnt/scratch", transfer)

    def test_the_scratch_root_follows_the_campus_username(self) -> None:
        """One shared UUID, a per-user root -- which is why it derives.

        A second lab member running this gets their own directory with nothing
        to declare. If the root were declared instead, the value that would be
        copied between people is the one that silently writes into somebody
        else's scratch.
        """
        lines = self.compose(
            "push", str(self.source), "/mnt/scratch/user/someone/inbox", CHPC_USER="someone"
        )
        transfer = next(line for line in lines if " transfer " in line)
        self.assertIn(f"{SCRATCH_COLLECTION}:/inbox", transfer)

    # ── two legs ─────────────────────────────────────────────────────────────

    def test_a_push_to_the_share_transfers_then_copies_then_repairs_the_acl(self) -> None:
        """FAC has no collection, so the trip is transfer, cp, fixacl -- in that order."""
        lines = self.compose("push", str(self.source), "/mnt/fac/TEST_SHARE/proj/incoming")
        kinds = [line.split()[0] for line in lines if line.startswith(("RUN", "SSH"))]
        self.assertEqual(kinds[0], "RUN", lines)
        self.assertIn("SSH", kinds, lines)
        self.assertLess(kinds.index("RUN"), kinds.index("SSH"), lines)

        remote = next(line for line in lines if line.startswith("SSH"))
        self.assertIn("mkdir -p /mnt/fac/TEST_SHARE/proj", remote)
        self.assertIn("cp -a /mnt/scratch/user/testuser/globus-staging/incoming", remote)
        self.assertIn("chpc-fac-fixacl /mnt/fac/TEST_SHARE/proj/incoming", remote)

    def test_a_pull_from_the_share_fills_the_buffer_before_transferring_it(self) -> None:
        """The order that distinguishes a retrieval from a success over nothing.

        A Globus transfer of a staging path that has not been copied into yet
        does not fail: it delivers an empty directory and reports SUCCEEDED.
        """
        lines = self.compose(
            "pull", "/mnt/fac/TEST_SHARE/runs/h8-abc", f"{self.staging_local}/h8-abc"
        )
        ordered = [line for line in lines if line.startswith(("RUN", "SSH"))]
        self.assertTrue(ordered[0].startswith("SSH"), ordered)
        self.assertIn("cp -a /mnt/fac/TEST_SHARE/runs/h8-abc", ordered[0])
        transfer = next(line for line in ordered if " transfer " in line)
        self.assertIn(f"{SCRATCH_COLLECTION}:/globus-staging/h8-abc", transfer)
        self.assertLess(ordered.index(ordered[0]), ordered.index(transfer))

    def test_the_buffer_is_on_scratch_and_never_on_the_share(self) -> None:
        """Scratch is purged at thirty days, which is correct for a buffer.

        The canonical copy is the one the buffer was filled from; putting the
        buffer on FAC would double every round's footprint on the 5 TB share.
        """
        lines = self.compose("push", str(self.source), "/mnt/fac/TEST_SHARE/proj/incoming")
        whole = "\n".join(lines)
        self.assertIn("/mnt/scratch/user/testuser/globus-staging/incoming", whole)
        # No buffer path anywhere sits on the share. Searched as a pattern
        # rather than per line, because the ssh leg legitimately names FAC --
        # it is copying INTO it -- and the question is where the buffer is.
        self.assertEqual(re.findall(r"/mnt/fac\S*globus-staging", whole), [], whole)

    # ── refusals ─────────────────────────────────────────────────────────────

    def test_a_path_outside_its_collection_root_is_refused_and_names_the_root(self) -> None:
        """Globus would accept it. That is exactly why this refuses it."""
        env = dict(os.environ)
        env.update(
            PATH=f"{self.tmp.name}/bin:{env['PATH']}",
            CHPC_ENV_LOCAL=str(self.local_env),
            CHPC_USER="testuser",
            CHPC_GLOBUS_LOCAL_COLLECTION=LOCAL_COLLECTION,
            CHPC_GLOBUS_LOCAL_ROOT="/somewhere/else",
            CHPC_GLOBUS_STAGING_LOCAL=str(self.staging_local),
        )
        done = subprocess.run(
            ["bash", str(SCRIPT), "push", str(self.source), "/mnt/scratch/user/testuser/x",
             "--dry-run"],
            capture_output=True, text=True, env=env, check=False,
        )
        self.assertEqual(done.returncode, 1)
        self.assertIn("/somewhere/else", done.stderr)
        self.assertIn(str(self.source), done.stderr)

    def test_a_buffer_outside_the_collection_stops_the_transfer_not_just_the_message(
        self,
    ) -> None:
        """The refusal has to abort, and once it did not.

        `collection_path` dies inside a command substitution, and
        `cmd "$(fn)"` DISCARDS the substitution's exit status -- so the message
        printed, the script carried on, and `globus transfer` was composed with an
        EMPTY destination path, which Globus reads as the collection root. A whole
        bundle would have been written there, recursively, and reported SUCCEEDED.
        Every collection path is now assigned to a variable first, where `set -e`
        can see the failure.
        """
        done = subprocess.run(
            ["bash", str(SCRIPT), "push", str(self.source),
             "/mnt/fac/TEST_SHARE/proj/incoming", "--dry-run"],
            capture_output=True, text=True, check=False,
            env={
                **os.environ,
                "PATH": f"{self.tmp.name}/bin:{os.environ['PATH']}",
                "CHPC_ENV_LOCAL": str(self.local_env),
                "CHPC_USER": "testuser",
                "CHPC_GLOBUS_LOCAL_COLLECTION": LOCAL_COLLECTION,
                "CHPC_GLOBUS_LOCAL_ROOT": str(self.tmp.name),
                "CHPC_GLOBUS_STAGING_LOCAL": str(self.staging_local),
                # A buffer somebody pointed at the share, which no collection
                # covers. Nothing else about this invocation is wrong.
                "CHPC_GLOBUS_STAGING": "/mnt/fac/TEST_SHARE/buffer",
            },
        )
        self.assertEqual(done.returncode, 1, done.stdout)
        self.assertIn("not under the collection root", done.stderr)
        self.assertNotIn("globus transfer", done.stdout)

    def test_an_undeclared_local_staging_directory_is_refused_before_anything_runs(self) -> None:
        """No default, because a guessed one fails at the END of a transfer."""
        env = dict(os.environ)
        env.pop("CHPC_GLOBUS_STAGING_LOCAL", None)
        env.update(
            PATH=f"{self.tmp.name}/bin:{env['PATH']}",
            CHPC_ENV_LOCAL=str(self.local_env),
            CHPC_USER="testuser",
            CHPC_GLOBUS_LOCAL_COLLECTION=LOCAL_COLLECTION,
        )
        done = subprocess.run(
            ["bash", str(SCRIPT), "push", str(self.source), "/mnt/scratch/user/testuser/x",
             "--dry-run"],
            capture_output=True, text=True, env=env, check=False,
        )
        self.assertEqual(done.returncode, 1)
        self.assertIn("CHPC_GLOBUS_STAGING_LOCAL", done.stderr)

    def test_an_unknown_verb_is_refused_rather_than_defaulting_to_one(self) -> None:
        """A typo must not resolve to a transfer."""
        done = subprocess.run(
            ["bash", str(SCRIPT), "psuh", "a", "b"],
            capture_output=True, text=True, check=False,
            env={**os.environ, "CHPC_ENV_LOCAL": str(self.local_env), "CHPC_USER": "testuser"},
        )
        self.assertEqual(done.returncode, 1)
        self.assertIn("psuh", done.stderr)


if __name__ == "__main__":
    unittest.main()
