"""`chpc-tool exec` must survive a node that has nvidia-smi but no driver.

Every CPU partition node here ships the nvidia-smi BINARY while having no GPU
and no loaded driver. Asked for a compute capability there, nvidia-smi does two
things that a shell has to be written for:

  * it exits **9**, and
  * it prints "NVIDIA-SMI has failed because it couldn't communicate with the
    NVIDIA driver" on **stdout**, so `2>/dev/null` does not suppress it.

`lab/bin/chpc-tool` runs under `set -euo pipefail`, so the GPU_MAX_CC probe --
a bare `_cc=$(nvidia-smi ... | head -1 | tr -d ' ')` -- carried that 9 out of
the pipeline and `set -e` killed the tool before it ever reached apptainer.
The symptom was a silent exit 9 with no diagnostic, which reads as a broken
image: `chpc-tool exec rfdiffusion3` on the `community` partition died that way
on 2026-09-26, and rfdiffusion3's own test.sh says "CPU is fine" and so could
not pass anywhere.

The second half matters independently of the first. With the exit status
handled but the stdout prose still landing in `$_cc`, the comparison below
survives only because `a+0` turns prose into 0 -- and the refusal message one
line down would have printed that prose to the user as a device capability.
Both halves are asserted here.

The tests fake nvidia-smi and apptainer on PATH, so they run on a laptop with
no cluster and no GPU.
"""

from __future__ import annotations

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1] / "lab/bin/chpc-tool"

# GPU=1 with a ceiling: the combination that reaches the nvidia-smi probe.
CONF = """NAME=faketool
VERSION=1
KIND=container
STATUS=built
IMAGE=fake_1.sif
GPU=1
GPU_MAX_CC=9.0
"""

# The real message, verbatim from ccpu1-01, on stdout, exiting 9.
NVIDIA_SMI_NO_DRIVER = """#!/bin/sh
echo "NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver. Make sure that the latest NVIDIA driver is installed and running."
exit 9
"""

APPTAINER_MARKER = "APPTAINER-REACHED"


class GpuCeilingTests(unittest.TestCase):
    def registry(self, root: Path, nvidia_smi: str | None) -> dict[str, str]:
        """A one-entry registry, a readable image, and fake tools on PATH."""
        entry = root / "tools/faketool"
        entry.mkdir(parents=True)
        (entry / "tool.conf").write_text(CONF)
        containers = root / "containers"
        containers.mkdir()
        (containers / "fake_1.sif").write_text("not really a squashfs")

        bin_dir = root / "bin"
        bin_dir.mkdir()
        # Stand in for apptainer, and report having been reached. The bug made
        # chpc-tool exit before this could run, so its output is the assertion.
        apptainer = bin_dir / "apptainer"
        apptainer.write_text(f'#!/bin/sh\necho "{APPTAINER_MARKER} $*"\n')
        apptainer.chmod(0o755)
        if nvidia_smi is not None:
            smi = bin_dir / "nvidia-smi"
            smi.write_text(nvidia_smi)
            smi.chmod(0o755)

        # Ambient CHPC_* stripped, not merged, and a PATH that leads with our
        # fakes so a developer machine's real apptainer cannot be picked up.
        base = {k: v for k, v in os.environ.items() if not k.startswith("CHPC_")}
        return {
            **base,
            "PATH": f"{bin_dir}:{base.get('PATH', '/usr/bin:/bin')}",
            "CHPC_TOOLS": str(root / "tools"),
            "CHPC_CONTAINERS": str(containers),
            "CHPC_LAB": str(root / "lab"),
            "CHPC_ON_CLUSTER": "1",
        }

    def run_exec(self, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["/bin/bash", str(TOOL), "exec", "faketool", "--", "true"],
            env=env,
            capture_output=True,
            text=True,
        )

    def test_nvidia_smi_exiting_nine_does_not_kill_exec(self) -> None:
        """The regression: a driverless node must still reach apptainer."""
        with tempfile.TemporaryDirectory() as td:
            env = self.registry(Path(td), NVIDIA_SMI_NO_DRIVER)
            got = self.run_exec(env)
        self.assertEqual(
            got.returncode,
            0,
            f"exec died on a node with no driver (exit {got.returncode}). "
            f"stdout={got.stdout!r} stderr={got.stderr!r}",
        )
        self.assertIn(APPTAINER_MARKER, got.stdout)

    def test_the_failure_text_is_not_treated_as_a_capability(self) -> None:
        """nvidia-smi's complaint arrives on stdout; it must be discarded."""
        with tempfile.TemporaryDirectory() as td:
            env = self.registry(Path(td), NVIDIA_SMI_NO_DRIVER)
            got = self.run_exec(env)
        combined = got.stdout + got.stderr
        self.assertNotIn("NVIDIA-SMI has failed", combined)
        self.assertNotIn("NVIDIA-SMIhasfailed", combined)
        self.assertNotIn("cannot run on this GPU", combined)

    def test_a_device_over_the_ceiling_is_still_refused(self) -> None:
        """The fix must not disarm the check it is protecting."""
        with tempfile.TemporaryDirectory() as td:
            env = self.registry(
                Path(td), '#!/bin/sh\necho "12.0"\n'
            )  # a Blackwell card against GPU_MAX_CC=9.0
            got = self.run_exec(env)
        self.assertNotEqual(got.returncode, 0, "an sm_120 device was let through")
        self.assertIn("cannot run on this GPU", got.stdout + got.stderr)
        self.assertNotIn(APPTAINER_MARKER, got.stdout)

    def test_a_device_within_the_ceiling_runs(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            env = self.registry(Path(td), '#!/bin/sh\necho "8.9"\n')  # L40S
            got = self.run_exec(env)
        self.assertEqual(got.returncode, 0, got.stdout + got.stderr)
        self.assertIn(APPTAINER_MARKER, got.stdout)

    def test_no_nvidia_smi_at_all_is_silent(self) -> None:
        """The login node's case, and the one that always worked."""
        with tempfile.TemporaryDirectory() as td:
            env = self.registry(Path(td), None)
            got = self.run_exec(env)
        self.assertEqual(got.returncode, 0, got.stdout + got.stderr)
        self.assertIn(APPTAINER_MARKER, got.stdout)


if __name__ == "__main__":
    unittest.main()
