"""A README's header is a claim about the registry; the registry is tool.conf.

Three entries shipped a header saying `planned` while their tool.conf said
built or verified, and one named an image that was no longer the one the entry
resolved. Nothing noticed, because nothing compared the two. These assert that
the README a person reads and the entry chpc-tool runs never disagree, and
that every built entry tells a new person how to run it -- in the one form the
docs teach, `chpc-tool exec <tool> -- <program>`.
"""

from __future__ import annotations

import re
import subprocess
import unittest
from pathlib import Path

from test_tool_conf import STUBS, env  # the same stub environment, so they cannot drift

TOOLS = Path(__file__).resolve().parents[1] / "tools"

# `chpc-tool exec <tool>` followed by something on the same line. A mention
# that ends at the tool name ("... via `chpc-tool exec boltz`.") is prose.
EXEC_WITH_ARGS = re.compile(r"chpc-tool exec ([A-Za-z0-9_-]+)( +)(\S)")
STATUS_ROW = re.compile(r"^\| *Status *\| *([^|]*)\|", re.MULTILINE)
GPU_MODELS = ("nvidia_l40s", "nvidia_h100_nvl")


def entries() -> list[Path]:
    found = sorted(d for d in TOOLS.iterdir() if d.is_dir() and not d.name.startswith("_") and (d / "tool.conf").exists())
    assert found, f"no entries under {TOOLS}"
    return found


def conf(entry: Path) -> dict[str, str]:
    """The values chpc-tool would see, by sourcing, not by reading the text."""
    keys = ("NAME", "KIND", "STATUS", "IMAGE", "GPU", "GPU_MAX_CC")
    tail = "; ".join(f'printf "%s\\n" "${{{k}-}}"' for k in keys)
    result = subprocess.run(
        ["bash", "-u", "-c", f'{STUBS} source "$1"; {tail}', "_", str(entry / "tool.conf")],
        capture_output=True, text=True, env=env(),
    )
    assert result.returncode == 0, result.stderr
    values = result.stdout.split("\n")
    return {k: values[i] for i, k in enumerate(keys)}


def status_word(readme: str) -> str:
    match = STATUS_ROW.search(readme)
    assert match, "no `| Status |` row in the header table"
    cell = match.group(1).strip().strip("`*_ ")
    return cell.split()[0].strip("`*_,;.") if cell else ""


class ToolReadmeTests(unittest.TestCase):
    def test_every_entry_past_planned_has_a_readme(self) -> None:
        """tools/README.md, Add a tool: the README is owed at the build."""
        for entry in entries():
            with self.subTest(tool=entry.name):
                if conf(entry)["STATUS"] != "planned":
                    self.assertTrue((entry / "README.md").exists(), f"{entry.name} is {conf(entry)['STATUS']} and has no README.md")

    def test_header_status_matches_tool_conf(self) -> None:
        for entry in entries():
            readme = entry / "README.md"
            if not readme.exists():
                continue
            with self.subTest(tool=entry.name):
                self.assertEqual(status_word(readme.read_text()), conf(entry)["STATUS"],
                                 f"{entry.name}/README.md header disagrees with tool.conf STATUS")

    def test_built_entries_say_how_to_run_them_and_planned_ones_do_not(self) -> None:
        """Each status owes a different section, and `external` owes its own.

        `external` is a terminus, not a rung (tools/README.md, Add a tool): the
        tool is deliberately not installed here, so there is no `## Run it` to
        write and promising one would be a lie. What it does owe is where the
        thing actually runs and what a local install would take, so the next
        person does not re-derive that -- hence `## Why there is nothing to
        install`. It still owes `## Do not miss`, because an external tool has
        traps like any other and they are the reason to read the page."""
        for entry in entries():
            readme = entry / "README.md"
            if not readme.exists():
                continue
            text = readme.read_text()
            status = conf(entry)["STATUS"]
            with self.subTest(tool=entry.name, status=status):
                if status == "planned":
                    self.assertIn("## Not built yet", text)
                    self.assertNotIn("## Run it", text)
                elif status == "external":
                    self.assertIn("## Why there is nothing to install", text)
                    self.assertIn("## Do not miss", text)
                    self.assertNotIn("## Run it", text)
                else:
                    self.assertIn("## Run it", text)
                    self.assertIn("## Do not miss", text)

    def test_every_exec_line_separates_the_tool_from_its_command(self) -> None:
        """`chpc-tool exec boltz predict x` runs a program called predict.

        The ENTRY rule (tools/README.md, The CLI): without ` -- ` the first
        argument is the program. Every command a README shows carries the
        dashes, so a copied line cannot fail that way."""
        for readme in sorted(TOOLS.glob("*/README.md")):
            if readme.parent.name.startswith("_"):
                continue
            for number, line in enumerate(readme.read_text().split("\n"), start=1):
                for match in EXEC_WITH_ARGS.finditer(line):
                    rest = line[match.start(3):]
                    with self.subTest(file=f"{readme.parent.name}/README.md", line=number):
                        self.assertTrue(rest.startswith("--"),
                                        f"{readme.parent.name}/README.md:{number} runs `exec {match.group(1)} {rest[:30]}` without ` -- `")

    def test_container_entries_name_their_actual_image(self) -> None:
        """chai1's README named chai1_1.sif for a week after IMAGE became chai1_2."""
        for entry in entries():
            readme = entry / "README.md"
            values = conf(entry)
            if not readme.exists() or values["KIND"] != "container" or not values["IMAGE"] or values["STATUS"] == "planned":
                continue
            with self.subTest(tool=entry.name):
                self.assertIn(values["IMAGE"], readme.read_text(), f"{entry.name}/README.md never names {values['IMAGE']}")

    def test_gpu_capped_entries_name_a_gpu_model(self) -> None:
        """An image without sm_120 must tell the reader which --gres to ask for."""
        for entry in entries():
            readme = entry / "README.md"
            values = conf(entry)
            if not readme.exists() or values["GPU"] != "1" or values["STATUS"] == "planned":
                continue
            try:
                cap = float(values["GPU_MAX_CC"])
            except ValueError:
                continue
            if cap >= 12.0:
                continue
            with self.subTest(tool=entry.name):
                text = readme.read_text()
                self.assertTrue(any(m in text for m in GPU_MODELS),
                                f"{entry.name} has GPU_MAX_CC={cap} and its README names no GPU model to ask for")


if __name__ == "__main__":
    unittest.main()
