"""The SSH example must not break hosts it does not name.

ssh reads the whole of ~/.ssh/config whichever host is named, and an option it
does not know is fatal -- unless an IgnoreUnknown *that applies to that host*
came first. UseKeychain exists only in Apple's ssh.

Until 2026-11-20 the example carried `IgnoreUnknown UseKeychain` inside the
`Host chpc...` block. That covers the chpc aliases and nothing else, so on
Linux every other host -- git remotes included -- died with "Bad configuration
option: usekeychain" as soon as the block was pasted in. A Mac never shows it,
which is how it survived, and why the structural tests below matter: they hold
the rule on any platform, while the `ssh -G` tests can only catch a regression
where ssh itself does not know the option.
"""
from __future__ import annotations

import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
EXAMPLE = REPO / "ssh/config.example"
DOC = REPO / "docs/01-access-and-ssh.md"

# Options only Apple's ssh understands. Using one needs a covering IgnoreUnknown.
APPLE_ONLY = ("usekeychain",)


def doc_block() -> str:
    """What docs/01 appends to ~/.ssh/config: the body of its heredoc."""
    found = re.search(r'cat >> "\$HOME/\.ssh/config" <<EOF\n(.*?)\nEOF\n', DOC.read_text(), re.S)
    if found is None:
        raise AssertionError("docs/01 no longer appends to ~/.ssh/config with a <<EOF heredoc")
    return found.group(1)


def directives(text: str) -> list[tuple[tuple[str, ...] | None, str, tuple[str, ...]]]:
    """(patterns of the enclosing Host/Match block, keyword, arguments) per directive.

    The scope is None for a directive above every Host and Match line, which is
    the one other place a setting applies to all hosts.
    """
    scope: tuple[str, ...] | None = None
    found = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        keyword, _, rest = line.partition(" ")
        keyword = keyword.lower()
        if keyword in ("host", "match"):
            scope = (keyword, *rest.split())
            continue
        found.append((scope, keyword, tuple(rest.split())))
    return found


def applies_to_every_host(scope: tuple[str, ...] | None) -> bool:
    return scope is None or scope == ("host", "*")


class SshConfigExample(unittest.TestCase):
    SOURCES = {"ssh/config.example": EXAMPLE.read_text, "docs/01 heredoc": doc_block}

    def test_apple_only_options_are_covered_for_every_host(self) -> None:
        for name, read in self.SOURCES.items():
            with self.subTest(source=name):
                ignored: set[str] = set()
                first_ignore_seen = False
                used = []
                for scope, keyword, args in directives(read()):
                    if keyword == "ignoreunknown":
                        # Only the first IgnoreUnknown that applies counts, so a
                        # second one cannot be what makes the file safe.
                        if applies_to_every_host(scope) and not first_ignore_seen:
                            ignored |= {item.lower() for arg in args for item in arg.split(",") if item}
                            first_ignore_seen = True
                        continue
                    if keyword in APPLE_ONLY:
                        used.append(keyword)
                        self.assertIn(
                            keyword, ignored,
                            f"{name}: {keyword} is used before an IgnoreUnknown that applies to "
                            "EVERY host (top of file, or its own `Host *` block). Inside the chpc "
                            "block it protects only chpc, and every other host fails on Linux.",
                        )
                self.assertTrue(used, f"{name}: no Apple-only option found; is this test still looking at the right text?")

    def test_ignoreunknown_is_not_scoped_to_the_chpc_block(self) -> None:
        for name, read in self.SOURCES.items():
            with self.subTest(source=name):
                for scope, keyword, _args in directives(read()):
                    if keyword == "ignoreunknown":
                        self.assertTrue(applies_to_every_host(scope), f"{name}: IgnoreUnknown sits in {scope}")

    def test_doc_appends_the_same_settings_as_the_example(self) -> None:
        def settings(text: str) -> list:
            return [
                (scope, keyword, ("<user>",) if keyword == "user" else args)
                for scope, keyword, args in directives(text)
            ]
        self.assertEqual(settings(doc_block()), settings(EXAMPLE.read_text()))

    @unittest.skipUnless(shutil.which("ssh"), "no ssh on PATH")
    def test_ssh_loads_it_for_chpc_and_for_unrelated_hosts(self) -> None:
        for name, read in self.SOURCES.items():
            text = read().replace("<campus-username>", "jdoe").replace("$CHPC_LOGIN", "jdoe")
            with tempfile.TemporaryDirectory() as tmp:
                config = Path(tmp) / "config"
                # An unrelated entry first, as a real ~/.ssh/config would have.
                config.write_text("Host github.com\n  User git\n\n" + text + "\n")
                for host, user in (("github.com", "git"), ("chpc", "jdoe"), ("chpc-bastion2", "jdoe")):
                    with self.subTest(source=name, host=host):
                        done = subprocess.run(
                            ["ssh", "-G", "-F", str(config), host],
                            stdin=subprocess.DEVNULL, text=True, capture_output=True, check=False,
                        )
                        self.assertEqual(done.returncode, 0, done.stderr)
                        self.assertIn(f"user {user}\n", done.stdout)


if __name__ == "__main__":
    unittest.main()
