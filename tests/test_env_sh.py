"""env.sh must let chpc.env.local point CHPC_TOOLS elsewhere.

chpc.env.local.example has offered a CHPC_TOOLS override since the file
existed, and env.sh sourced that file BEFORE assigning CHPC_TOOLS
unconditionally from its own checkout, so the override never took. Nobody
noticed because the default is right for every project that pins this repo,
which is all of them; it is wrong for the one person developing a new tool
entry in a second checkout, who is exactly the person the override is for.
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
ENV_SH = REPO / "env.sh"


def source_and_print(local: Path | None, **extra: str) -> str:
    base = {k: v for k, v in os.environ.items() if not k.startswith("CHPC_")}
    e = {**base, **extra}
    if local is not None:
        e["CHPC_ENV_LOCAL"] = str(local)
    script = f'source "{ENV_SH}" >/dev/null 2>&1; printf "%s" "$CHPC_TOOLS"'
    result = subprocess.run(["/bin/bash", "-c", script], env=e, capture_output=True, text=True)
    return result.stdout


class EnvShTests(unittest.TestCase):
    def test_the_default_is_this_checkouts_registry(self) -> None:
        self.assertEqual(source_and_print(None), str(REPO / "tools"))

    def test_chpc_env_local_can_point_the_registry_elsewhere(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            other = Path(td) / "other/tools"
            other.mkdir(parents=True)
            local = Path(td) / "chpc.env.local"
            local.write_text(f"CHPC_TOOLS={other}\n")
            self.assertEqual(source_and_print(local), str(other))

    def test_the_example_files_form_works_too(self) -> None:
        """`${CHPC_TOOLS:-x}` in the local file behaves like a plain assignment."""
        with tempfile.TemporaryDirectory() as td:
            other = Path(td) / "other/tools"
            other.mkdir(parents=True)
            local = Path(td) / "chpc.env.local"
            local.write_text('CHPC_TOOLS="${CHPC_TOOLS:-%s}"\n' % other)
            self.assertEqual(source_and_print(local), str(other))

    def test_a_value_left_by_another_checkout_does_not_survive(self) -> None:
        """Sourcing a second checkout's env.sh must switch registries."""
        self.assertEqual(
            source_and_print(None, CHPC_TOOLS="/somewhere/else/tools"),
            str(REPO / "tools"),
        )


if __name__ == "__main__":
    unittest.main()
