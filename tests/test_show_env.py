"""`chpc-tool show --env` is the registry's machine-readable face.

A tool.conf is sourced shell, so the only faithful reader of one is a shell.
Every other consumer has two choices and both are bad: reimplement bash's
quoting rules, or restate the registry's values in a second file. The second
file is the failure lab/README.md warns about -- it says the old image name the
day the image is rebuilt, and a job dies on a path that has not existed for a
week.

So the registry answers in a format a program can read, and these are the
properties that make that answer trustworthy: one assignment per line, every
value quoted so it can never be read as a key, the entry's exports EVALUATED
rather than echoed, and a value that cannot be carried refused out loud instead
of emitted as two lines.
"""

from __future__ import annotations

import os
import shlex
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
TOOL = REPO / "lab/bin/chpc-tool"
REGISTRY = REPO / "tools"


def parse(text: str) -> list[dict[str, str]]:
    """Split the output into one mapping per record, the way a consumer must.

    Deliberately strict: a line that is not exactly one shell-quoted assignment
    is a failure of the format, not something to skip past.
    """
    records: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in text.split("\n"):
        if not line:
            if current:
                records.append(current)
                current = {}
            continue
        key, _, raw = line.partition("=")
        values = shlex.split(raw)
        assert len(values) <= 1, f"{key} did not parse to one value: {raw!r}"
        current[key] = values[0] if values else ""
    if current:
        records.append(current)
    return records


class ShowEnvTests(unittest.TestCase):
    def run_cli(self, *args: str, env: dict[str, str] | None = None):
        return subprocess.run(
            ["/bin/bash", str(TOOL), *args],
            env=env if env is not None else os.environ.copy(),
            capture_output=True,
            text=True,
        )

    # ── the whole registry, as it stands ──────────────────────────────────

    def test_every_entry_emits_a_parseable_record(self) -> None:
        """No argument means every tool. This is the bulk read a consumer does."""
        result = self.run_cli("show", "--env")
        self.assertEqual(result.returncode, 0, result.stderr)
        records = parse(result.stdout)
        entries = sorted(
            p.parent.name for p in REGISTRY.glob("*/tool.conf") if not p.parent.name.startswith("_")
        )
        self.assertEqual(sorted(r["NAME"] for r in records), entries)

    def test_every_entry_answers_the_questions_a_consumer_asks(self) -> None:
        """KIND, STATUS and a resolved IMAGE_PATH are always present.

        Always PRESENT, including empty -- a consumer reads a key and decides on
        its value, rather than distinguishing "absent" from "empty" and getting
        it wrong for the kinds that have no image.
        """
        result = self.run_cli("show", "--env")
        for record in parse(result.stdout):
            for key in ("NAME", "KIND", "STATUS", "GPU", "IMAGE_PATH", "TOOLDIR"):
                self.assertIn(key, record, record.get("NAME"))
            if record["KIND"] == "container":
                self.assertTrue(record["IMAGE_PATH"], record["NAME"])

    def test_note_is_not_emitted(self) -> None:
        """The registry's most escape-prone field stays out of its strictest format.

        NOTE routinely carries quotes and backticks, it is prose for a person
        reading `show`, and no consumer acts on it. Carrying it here would buy
        an escaping hazard for nobody.
        """
        result = self.run_cli("show", "--env")
        self.assertNotIn("\nNOTE=", "\n" + result.stdout)

    def test_an_export_carries_its_value_not_its_source_text(self) -> None:
        """tool_exports emits `SIF_BOLTZ="/a/b.sif"`. The value is /a/b.sif.

        The image NAME is read back from the record rather than written in
        here. This line used to say `endswith("boltz_2.sif")`, and a rebuild
        moved it -- boltz_2_gcc.sif, 2026-09-25 -- so the test failed for a
        reason that had nothing to do with what it is for. A filename is the
        one thing on this entry that is SUPPOSED to change when an image is
        rebuilt; what must not change is that the export resolves to a path
        instead of carrying the literal `$(_image_path)` back out.
        """
        result = self.run_cli("show", "--env", "boltz")
        self.assertEqual(result.returncode, 0, result.stderr)
        record = parse(result.stdout)[0]
        self.assertTrue(record["IMAGE"].endswith(".sif"), record["IMAGE"])
        self.assertTrue(record["EXPORT_SIF_BOLTZ"].endswith(record["IMAGE"]))
        self.assertFalse(record["EXPORT_SIF_BOLTZ"].startswith('"'))
        self.assertEqual(record["EXPORT_SIF_BOLTZ"], record["IMAGE_PATH"])

    # ── a synthetic entry, for the values a real one does not have ────────

    def registry(self, root: Path, conf: str) -> dict[str, str]:
        entry = root / "tools/faketool"
        entry.mkdir(parents=True)
        (entry / "tool.conf").write_text(conf)
        (root / "mirror").mkdir()
        (root / "lab/containers").mkdir(parents=True)
        # Ambient CHPC_* stripped, not merged: a shell that has sourced env.sh
        # would otherwise contribute the real share paths and the test would be
        # measuring that machine.
        base = {k: v for k, v in os.environ.items() if not k.startswith("CHPC_")}
        return {
            **base,
            "CHPC_TOOLS": str(root / "tools"),
            "CHPC_CONTAINERS": str(root / "mirror"),
            "CHPC_LAB": str(root / "lab"),
            "CHPC_REFDATA": str(root / "lab/data"),
        }

    def test_a_single_quote_in_a_value_survives(self) -> None:
        """The '\\'' escape, end to end: emitted as shell, read back by shlex."""
        conf = (
            "NAME=faketool\nKIND=native\nSTATUS=built\n"
            "PREFIX=\"/opt/o'brien/tool\"\nGPU=0\n"
        )
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            result = self.run_cli("show", "--env", "faketool", env=self.registry(root, conf))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(parse(result.stdout)[0]["PREFIX"], "/opt/o'brien/tool")

    def test_a_newline_in_a_value_is_refused_rather_than_split(self) -> None:
        """One assignment per line, or nothing.

        A format that can turn one value into two lines is not a format, and the
        consumer would silently read the tail as a key it does not know.
        """
        conf = 'NAME=faketool\nKIND=native\nSTATUS=built\nPREFIX="/one\n/two"\nGPU=0\n'
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            result = self.run_cli("show", "--env", "faketool", env=self.registry(root, conf))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("PREFIX", result.stderr)
            self.assertIn("newline", result.stderr)

    def test_image_path_follows_the_per_image_fallback(self) -> None:
        """The resolved path is the one exec would use, not a directory guess.

        `chpc.env` picks CHPC_CONTAINERS once, by asking whether the mirror
        DIRECTORY exists. This field answers per image, which is the whole
        reason a consumer should read it instead of composing a path itself.
        """
        conf = "NAME=faketool\nKIND=container\nSTATUS=built\nIMAGE=fake_1.sif\nGPU=0\n"
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            env = self.registry(root, conf)
            (root / "lab/containers/fake_1.sif").write_text("x")  # canonical only
            record = parse(self.run_cli("show", "--env", "faketool", env=env).stdout)[0]
            self.assertEqual(record["IMAGE_PATH"], str(root / "lab/containers/fake_1.sif"))
            self.assertEqual(record["IMAGE_MIRROR"], str(root / "mirror/fake_1.sif"))

            (root / "mirror/fake_1.sif").write_text("x")  # now both
            record = parse(self.run_cli("show", "--env", "faketool", env=env).stdout)[0]
            self.assertEqual(record["IMAGE_PATH"], str(root / "mirror/fake_1.sif"))

    def test_an_unknown_option_is_refused(self) -> None:
        """`show --emv boltz` must not silently print the human form."""
        result = self.run_cli("show", "--emv", "boltz")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--emv", result.stderr)

    def test_the_human_form_still_works(self) -> None:
        result = self.run_cli("show", "boltz")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("name        boltz", result.stdout)


if __name__ == "__main__":
    unittest.main()
