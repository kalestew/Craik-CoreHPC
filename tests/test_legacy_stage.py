"""An old project cannot accidentally fall back to SSH file transfers."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class RetiredTransferTests(unittest.TestCase):
    def test_legacy_command_refuses_without_running_a_transport(self):
        script = Path(__file__).resolve().parents[1] / "scripts/chpc-stage.sh"
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            called = directory / "transport-called"
            for name in ("ssh", "scp", "rsync", "globus"):
                stub = directory / name
                stub.write_text('#!/bin/sh\nprintf called > "$CALLED"\n')
                stub.chmod(0o755)
            result = subprocess.run(
                ["/bin/bash", str(script), "./inputs", "/mnt/scratch/user/me/inputs"],
                env={**os.environ, "PATH": str(directory) + ":" + os.environ.get("PATH", ""), "CALLED": str(called)},
                capture_output=True, text=True,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("chpc-globus.sh push", result.stderr)
            self.assertFalse(called.exists())


if __name__ == "__main__":
    unittest.main()
