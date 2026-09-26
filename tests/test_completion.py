"""Tab completion is documentation that a shell enforces.

The verbs and tool names it offers are the ones the docs teach, and the `--`
it offers after `exec <tool>` is the one run form they teach. These call the
completion functions the way bash would, without a terminal, so the check
needs no interactive shell and no cluster.
"""

from __future__ import annotations

import os
import shlex
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
COMPLETION = REPO / "lab" / "bin" / "chpc-completion.bash"
CLI = REPO / "lab" / "bin" / "chpc-tool"
TOOLS = REPO / "tools"

FUNCTION = {
    "chpc-tool": "_chpc_tool_complete",
    "chpc-assets": "_chpc_assets_complete",
    "chpc-jobstats": "_chpc_jobstats_complete",
}


def complete(words: list[str], cword: int, *, registry: bool = True) -> list[str]:
    """What the shell would offer for `words` with the cursor on word `cword`."""
    script = (
        '. "$1"; COMP_WORDS=(' + " ".join(shlex.quote(w) for w in words) + "); "
        f"COMP_CWORD={cword}; {FUNCTION[words[0]]}; "
        'printf "%s\\n" "${COMPREPLY[@]}"'
    )
    # Every ambient CHPC_* stripped, for the reason test_tool_conf.py gives: a
    # test that passes only in a shell that already sourced env.sh reports the
    # tester, not the file.
    env = {k: v for k, v in os.environ.items() if not k.startswith("CHPC_")}
    env["PATH"] = f"{CLI.parent}:{env.get('PATH', '')}"
    if registry:
        env["CHPC_TOOLS"] = str(TOOLS)
    result = subprocess.run(
        ["/bin/bash", "-c", script, "_", str(COMPLETION)],
        capture_output=True,
        text=True,
        env=env,
    )
    assert result.returncode == 0, result.stderr
    return [line for line in result.stdout.split("\n") if line]


def help_verbs() -> set[str]:
    out = subprocess.run(["/bin/bash", str(CLI), "--help"], capture_output=True, text=True).stdout
    verbs = {line.split()[1] for line in out.split("\n") if line.strip().startswith("chpc-tool ")}
    return {v for v in verbs if v.isalpha()}   # the first help line is "chpc-tool -- resolve and run ..."


class CompletionTests(unittest.TestCase):
    def test_the_first_word_completes_to_a_verb(self) -> None:
        self.assertCountEqual(complete(["chpc-tool", "ex"], 1), ["exec", "export"])

    def test_every_verb_in_help_is_offered(self) -> None:
        """The help text and the completion list are two copies of one fact."""
        offered = set(complete(["chpc-tool", ""], 1))
        self.assertTrue(help_verbs() <= offered, help_verbs() - offered)

    def test_exec_offers_tool_names_from_the_registry(self) -> None:
        names = complete(["chpc-tool", "exec", "bo"], 2)
        self.assertIn("boltz", names)
        self.assertTrue(all(n.startswith("bo") for n in names), names)

    def test_the_template_directory_is_never_a_tool(self) -> None:
        self.assertEqual(complete(["chpc-tool", "exec", "_"], 2), [])

    def test_after_the_tool_comes_the_double_dash(self) -> None:
        """`chpc-tool exec boltz predict x` runs a program called predict."""
        self.assertEqual(complete(["chpc-tool", "exec", "boltz", ""], 3), ["--"])

    def test_show_offers_env_and_names(self) -> None:
        offered = complete(["chpc-tool", "show", ""], 2)
        self.assertIn("--env", offered)
        self.assertIn("boltz", offered)

    def test_without_a_registry_path_it_asks_the_tool(self) -> None:
        """A shell that sourced the FAC chpc.env with no tools/ beside it still
        completes, through `chpc-tool list`, which resolves its own registry."""
        self.assertIn("boltz", complete(["chpc-tool", "doctor", "bo"], 2, registry=False))

    def test_assets_verbs(self) -> None:
        self.assertEqual(complete(["chpc-assets", "ver"], 1), ["verify"])
        self.assertIn("boltz", complete(["chpc-assets", "verify", "bo"], 2))

    def test_jobstats_flags(self) -> None:
        self.assertEqual(complete(["chpc-jobstats", "--m"], 1), ["--mine"])


if __name__ == "__main__":
    unittest.main()
