"""An image on FAC must be usable when the scratch mirror does not have it.

`lab/chpc.env` picks CHPC_CONTAINERS once, by asking whether the fast mirror
DIRECTORY exists -- not whether it holds the image being asked for. Group
scratch is purged at 30 days, so the mirror goes stale on a schedule while the
FAC copy stays put, and before the fallback below `chpc-tool exec` refused such
an image with "image not found" naming a scratch path while the file sat
readable two directories away. chai1_2.sif and protenix_2.sif were both stuck
at STATUS=built for exactly that reason on 2026-09-25.

Every caller -- exec, test, doctor, and the SIF_* variables tool_exports emits
-- resolves through `_image_path`, so these cases cover all of them.
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "lab/bin/chpc-tool"

CONF = """NAME=faketool
VERSION=1
KIND=container
STATUS=built
IMAGE={image}
GPU=0
"""


class ImageResolutionTests(unittest.TestCase):
    def registry(self, root: Path, image: str = "fake_1.sif") -> dict[str, str]:
        """A one-entry registry, a mirror dir and a canonical dir, all empty."""
        entry = root / "tools/faketool"
        entry.mkdir(parents=True)
        (entry / "tool.conf").write_text(CONF.format(image=image))
        (root / "mirror").mkdir()
        (root / "lab/containers").mkdir(parents=True)
        # Ambient CHPC_* stripped, not merged. A developer shell that has
        # sourced corehpc/env.sh would otherwise contribute CHPC_ENV and the
        # real share paths, and the test would be measuring that machine.
        base = {k: v for k, v in os.environ.items() if not k.startswith("CHPC_")}
        return {
            **base,
            "CHPC_TOOLS": str(root / "tools"),
            "CHPC_CONTAINERS": str(root / "mirror"),
            "CHPC_LAB": str(root / "lab"),
            "CHPC_ON_CLUSTER": "1",
        }

    def run_cli(self, env: dict[str, str], *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/bash", str(TOOL), *args], env=env, capture_output=True, text=True
        )

    def test_the_mirror_is_preferred_when_it_has_the_image(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            env = self.registry(root)
            (root / "mirror/fake_1.sif").write_text("x")
            (root / "lab/containers/fake_1.sif").write_text("x")
            result = self.run_cli(env, "path", "faketool")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), str(root / "mirror/fake_1.sif"))

    def test_the_canonical_copy_is_used_when_the_mirror_lacks_it(self) -> None:
        """The fix. Before it, this resolved to a mirror path that did not exist."""
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            env = self.registry(root)
            (root / "lab/containers/fake_1.sif").write_text("x")
            result = self.run_cli(env, "path", "faketool")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), str(root / "lab/containers/fake_1.sif"))

    def test_a_usable_image_outside_the_mirror_is_reported_not_silently_used(self) -> None:
        """A silent fallback is how a scratch purge goes unnoticed."""
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            env = self.registry(root)
            (root / "lab/containers/fake_1.sif").write_text("x")
            result = self.run_cli(env, "doctor", "faketool")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("not in the scratch mirror", result.stdout)
            self.assertIn("chpc-stage-containers", result.stdout)

    def test_the_drift_note_survives_a_tool_that_writes_its_own_doctor_line(self) -> None:
        """A tool_doctor message REPLACES the default one.

        The drift note therefore cannot live in that message, or it would be
        visible only on entries with no tool_doctor -- which is to say, silent
        on chai1, protenix and boltz, the three this was found on.
        """
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            env = self.registry(root)
            (root / "tools/faketool/tool.conf").write_text(
                CONF.format(image="fake_1.sif")
                + 'tool_doctor() { echo "weight cache /somewhere"; }\n'
            )
            (root / "lab/containers/fake_1.sif").write_text("x")
            result = self.run_cli(env, "doctor", "faketool")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("weight cache /somewhere", result.stdout)
            self.assertIn("not in the scratch mirror", result.stdout)

    def test_an_image_in_the_mirror_draws_no_drift_warning(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            env = self.registry(root)
            (root / "mirror/fake_1.sif").write_text("x")
            result = self.run_cli(env, "doctor", "faketool")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("not in the scratch mirror", result.stdout)

    def test_a_missing_image_names_both_places_it_looked(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            env = self.registry(root)
            result = self.run_cli(env, "doctor", "faketool")
            self.assertEqual(result.returncode, 1, result.stdout)
            self.assertIn(str(root / "mirror/fake_1.sif"), result.stdout)
            self.assertIn(str(root / "lab/containers/fake_1.sif"), result.stdout)

    def test_exec_refuses_a_missing_image_naming_where_it_would_be_staged(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            env = self.registry(root)
            result = self.run_cli(env, "exec", "faketool", "--", "true")
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("image not found", result.stderr)
            self.assertIn(str(root / "mirror/fake_1.sif"), result.stderr)

    def test_an_absolute_image_path_is_used_verbatim(self) -> None:
        """An IMAGE that is already a path names one file and neither root."""
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            elsewhere = root / "elsewhere.sif"
            elsewhere.write_text("x")
            env = self.registry(root, image=str(elsewhere))
            result = self.run_cli(env, "path", "faketool")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), str(elsewhere))

    def test_the_exported_sif_variable_follows_the_same_fallback(self) -> None:
        """tool_exports resolves through _image_path, so a job gets the usable one."""
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            entry = root / "tools/faketool"
            env = self.registry(root)
            (entry / "tool.conf").write_text(
                CONF.format(image="fake_1.sif")
                + 'tool_exports() { echo "SIF_FAKE=\\"$(_image_path)\\""; }\n'
            )
            (root / "lab/containers/fake_1.sif").write_text("x")
            result = self.run_cli(env, "export", "faketool")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(str(root / "lab/containers/fake_1.sif"), result.stdout)


if __name__ == "__main__":
    unittest.main()
