"""A tool.conf is SOURCED, so its prose is shell code until it is escaped.

Two entries in this registry shipped a NOTE that bash executed rather than
stored. chai1's held `shutil.which("kalign") is not None` in backticks, so
sourcing it ran `kalign` -- twice -- and lost the quotes around the argument.
protenix's held a bare $PROTENIX_ROOT_DIR, which under `set -u` aborted
`chpc-tool export protenix` outright. Neither was noticed because no one had
run chpc-tool against either entry since the NOTE was written.

The failure mode is the one this registry exists to prevent: a value that
looks right in the file and is something else by the time a job reads it. So
assert on what SOURCING produces, not on what the file contains.
"""

from __future__ import annotations

import os
import re
import subprocess
import unittest
from pathlib import Path

TOOLS = Path(__file__).resolve().parents[1] / "tools"

ASSIGN = re.compile(r'^([A-Z_][A-Z0-9_]*)="')

STUBS = (
    'TOOLDIR="$(dirname "$1")"; '
    "_image_path(){ echo /containers/stub.sif; }; "
    "_refdata(){ echo /data/stub; }; "
)

# The environment chpc-tool guarantees before it sources an entry (see the
# `: "${CHPC_...:=}"` block at the top of lab/bin/chpc-tool). Several entries
# set PREFIX from CHPC_SOFTWARE at TOP LEVEL, so under `set -u` they cannot be
# sourced without it -- that is correct of them, not a defect.
#
# Supplied explicitly, and every ambient CHPC_* stripped first, because the
# first version of this file inherited the caller's environment and therefore
# PASSED on a developer machine whose shell profile had already sourced
# corehpc/env.sh, while failing on a clean login shell. A test that depends on
# who is running it is worth less than no test: it reports the tester, not the
# registry.
ENV = {
    "CHPC_LAB": "/stub/lab",
    "CHPC_CONTAINERS": "/stub/lab/containers",
    "CHPC_SOFTWARE": "/stub/lab/software",
    "CHPC_REFDATA": "/stub/lab/data",
    "CHPC_LICENSES": "/stub/lab/licenses",
    "CHPC_USER_SCRATCH": "/stub/scratch/user",
    "CHPC_PROJECT": "/stub/project",
    "CHPC_ON_CLUSTER": "0",
}


def env() -> dict[str, str]:
    base = {k: v for k, v in os.environ.items() if not k.startswith("CHPC_")}
    return {**base, **ENV}


def confs() -> list[Path]:
    found = sorted(TOOLS.glob("*/tool.conf"))
    assert found, f"no tool.conf under {TOOLS}"
    return found


def literal(body: str) -> str:
    """The text a reader sees in the file.

    Inside double quotes bash treats a backslash as an escape only before
    $ ` " and \\ -- before anything else, such as the \\w of a regex, the
    backslash is literal and survives into the value.
    """
    out: list[str] = []
    index = 0
    while index < len(body):
        char = body[index]
        if char == "\\" and index + 1 < len(body) and body[index + 1] in '$`"\\':
            out.append(body[index + 1])
            index += 2
            continue
        out.append(char)
        index += 1
    return "".join(out)


def source(path: Path, name: str = "") -> subprocess.CompletedProcess[str]:
    tail = f'printf %s "${{{name}-}}"' if name else ":"
    return subprocess.run(
        ["bash", "-u", "-c", f'{STUBS} source "$1"; {tail}', "_", str(path)],
        capture_output=True,
        text=True,
        env=env(),
    )


class ToolConfTests(unittest.TestCase):
    def test_every_tool_conf_sources_without_running_or_expanding_anything(self) -> None:
        """No output on stderr: a command that ran, or a variable that was not set."""
        for path in confs():
            with self.subTest(tool=path.parent.name):
                result = source(path)
                self.assertEqual(
                    result.stderr,
                    "",
                    f"{path.parent.name}/tool.conf is not inert when sourced:\n{result.stderr}",
                )

    def test_every_quoted_value_survives_sourcing_unchanged(self) -> None:
        """What a reader sees and what a job receives are the same string."""
        for path in confs():
            for number, line in enumerate(path.read_text().split("\n"), start=1):
                match = ASSIGN.match(line)
                if not match or not line.rstrip().endswith('"'):
                    continue
                name = match.group(1)
                body = line[len(name) + 2 : line.rstrip().rfind('"')]
                with self.subTest(tool=path.parent.name, line=number, name=name):
                    self.assertEqual(
                        source(path, name).stdout,
                        literal(body),
                        f"{path.parent.name}/tool.conf:{number} {name} is rewritten by the shell",
                    )


if __name__ == "__main__":
    unittest.main()
