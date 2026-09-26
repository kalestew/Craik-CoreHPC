"""A tool_exports that globs must find its file from exec and test, not only
from export.

foldx's tool_exports locates the binary by glob, because FoldX filenames carry
their own expiry date (foldx_20270131). `chpc-tool export foldx` found it;
`chpc-tool exec foldx` and `chpc-tool test foldx` did not, because the exporter
they share switched globbing off (`set -f`, right for splitting VALUES that
are paths) before calling tool_exports, so the glob stayed a literal and the
variable came out empty. The self-test then reported the payload as not
installed, on a share where it was. Measured 2026-09-26.
"""

from __future__ import annotations

import os
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "lab/bin/chpc-tool"

CONF = """NAME=faketool
VERSION=1
KIND=native
STATUS=built
PREFIX={prefix}
tool_exports() {{
  _b=""
  for _c in "$PREFIX"/fake_*; do
    if [ -x "$_c" ]; then _b="$_c"; break; fi
  done
  echo "FAKE_BINARY=\\"$_b\\""
}}
"""


class ToolExportsGlobTests(unittest.TestCase):
    def registry(self, root: Path) -> tuple[dict[str, str], Path]:
        prefix = root / "software/fake"
        prefix.mkdir(parents=True)
        binary = prefix / "fake_20270131"
        binary.write_text("#!/bin/sh\necho hi\n")
        binary.chmod(binary.stat().st_mode | stat.S_IXUSR)
        entry = root / "tools/faketool"
        entry.mkdir(parents=True)
        (entry / "tool.conf").write_text(CONF.format(prefix=prefix))
        base = {k: v for k, v in os.environ.items() if not k.startswith("CHPC_")}
        env = {
            **base,
            "CHPC_TOOLS": str(root / "tools"),
            "CHPC_LAB": str(root / "lab"),
            "CHPC_CONTAINERS": str(root / "lab/containers"),
            "CHPC_ON_CLUSTER": "0",
        }
        return env, binary

    def run_cli(self, env: dict[str, str], *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/bash", str(TOOL), *args], env=env, capture_output=True, text=True
        )

    def test_export_finds_the_globbed_binary(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            env, binary = self.registry(Path(td))
            r = self.run_cli(env, "export", "faketool")
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn(f'FAKE_BINARY="{binary}"', r.stdout)

    def test_exec_finds_it_too(self) -> None:
        """The defect: exec's exporter ran tool_exports with globbing off."""
        with tempfile.TemporaryDirectory() as td:
            env, binary = self.registry(Path(td))
            r = self.run_cli(env, "exec", "faketool", "--", "sh", "-c", 'printf %s "$FAKE_BINARY"')
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(r.stdout, str(binary))

    def test_a_value_that_looks_like_a_glob_is_not_expanded(self) -> None:
        """Why set -f is there at all: the split must not glob a VALUE."""
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            env, _ = self.registry(root)
            (root / "tools/faketool/tool.conf").write_text(
                CONF.format(prefix=root / "software/fake")
                + 'tool_exports() { echo "FAKE_PATTERN=\\"$PREFIX/fake_*\\""; }\n'
            )
            r = self.run_cli(env, "exec", "faketool", "--", "sh", "-c", 'printf %s "$FAKE_PATTERN"')
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(r.stdout, f"{root / 'software/fake'}/fake_*")


if __name__ == "__main__":
    unittest.main()
