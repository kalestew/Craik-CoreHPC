"""The published wrapper is `chpc-tool exec` under the tool's own name.

Until 2026-09-26 `$CHPC_LAB/bin/<tool>` ran apptainer itself with the image
name baked in: no `tool_exports`, no GPU_MAX_CC refusal, no fallback from the
scratch mirror to FAC, no `--writable-tmpfs`. rfdiffusion3 through its wrapper
hit the read-only-image error that `exec` avoids. Now the wrapper carries only
the tool's name and its ENTRY and hands over to the chpc-tool beside it, so
every guard lives in one place.

These cases generate a wrapper with the real `chpc-tool wrapper` and then run
it against a FAKE chpc-tool placed beside it, which prints its argv. That
asserts the hand-over exactly, without an image or a cluster.
"""

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
TOOL = REPO / "lab/bin/chpc-tool"

FAKE = """#!/bin/sh
printf '%s\\n' "$@"
"""


def env(root: Path) -> dict[str, str]:
    base = {k: v for k, v in os.environ.items() if not k.startswith("CHPC_")}
    return {
        **base,
        "CHPC_TOOLS": str(REPO / "tools"),
        "CHPC_LAB": str(root / "lab"),
        "CHPC_CONTAINERS": str(root / "lab/containers"),
        "CHPC_ON_CLUSTER": "0",
    }


class WrapperTests(unittest.TestCase):
    def wrapper(self, root: Path, tool: str) -> Path:
        dst = root / "lab/bin" / tool
        result = subprocess.run(
            ["/bin/bash", str(TOOL), "wrapper", tool, str(dst)],
            env=env(root), capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        fake = root / "lab/bin/chpc-tool"
        fake.write_text(FAKE)
        fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
        return dst

    def argv(self, wrapper: Path, *args: str) -> list[str]:
        result = subprocess.run([str(wrapper), *args], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.splitlines()

    def test_the_wrapper_is_exec_with_entry_always_prepended(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            w = self.wrapper(Path(td), "foldseek")
            # `foldseek version` must mean the program foldseek with the
            # argument version, which `exec` alone would not do: it prepends
            # ENTRY only before a flag.
            self.assertEqual(
                self.argv(w, "version"),
                ["exec", "foldseek", "--", "foldseek", "version"],
            )
            self.assertEqual(
                self.argv(w, "easy-search", "q.pdb", "db", "res.m8", "tmp"),
                ["exec", "foldseek", "--", "foldseek", "easy-search", "q.pdb", "db", "res.m8", "tmp"],
            )

    def test_arguments_with_spaces_survive(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            w = self.wrapper(Path(td), "pymol")
            self.assertEqual(
                self.argv(w, "-cq", "in.pdb", "-d", "hide everything; show cartoon"),
                ["exec", "pymol", "--", "pymol", "-cq", "in.pdb", "-d", "hide everything; show cartoon"],
            )

    def test_the_wrapper_carries_no_image_name(self) -> None:
        """A rebuilt image (new IMAGE in tool.conf) must need no new wrapper."""
        with tempfile.TemporaryDirectory() as td:
            w = self.wrapper(Path(td), "boltz")
            text = w.read_text()
            code = [l for l in text.splitlines() if not l.lstrip().startswith("#")]
            self.assertFalse([l for l in code if ".sif" in l or "apptainer" in l], code)
            self.assertIn("TOOL=boltz\n", text)
            self.assertIn('ENTRY="boltz"\n', text)

    def test_a_wrapper_without_chpc_tool_says_so(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            w = self.wrapper(root, "esm")
            (root / "lab/bin/chpc-tool").unlink()
            base = {k: v for k, v in os.environ.items() if k != "PATH"}
            # bash reachable, chpc-tool not: the system directories only.
            result = subprocess.run(
                [str(w), "--help"], env={**base, "PATH": "/usr/bin:/bin"},
                capture_output=True, text=True,
            )
            self.assertEqual(result.returncode, 127)
            self.assertIn("no chpc-tool beside", result.stderr)


if __name__ == "__main__":
    unittest.main()
