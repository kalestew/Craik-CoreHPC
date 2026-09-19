#!/bin/sh
# RFdiffusion3 self-test: the image runs and its checkpoints deserialise.
# Run:  chpc-tool test rfdiffusion3      (CPU is fine)
#
# WHAT THIS DOES NOT DO: it does not run a design. `rfd3` is a typer wrapper
# over a hydra app whose `--help` documents no config keys at all, and
# upstream ships its examples as notebooks rather than commands, so a
# minimal end-to-end invocation is not something to guess at. Until one is
# written from upstream's own example, this entry stays STATUS=built rather
# than verified -- the image and weights are proven, the science path is not.
set -eu

: "${FOUNDRY_CHECKPOINT_DIRS:?not set -- run through chpc-tool, which exports it}"

d="$FOUNDRY_CHECKPOINT_DIRS"
for f in rfd3_latest.ckpt rf3_foundry_01_24_latest_remapped.ckpt; do
    test -s "$d/$f" || {
        echo "missing $d/$f"
        echo "fetch with: tools/rfdiffusion3/fetch-weights.sh"; exit 1; }
done

# The console scripts exist and start. `foundry list-installed` is the one
# command that reads the checkpoint registry, so it exercises the path that
# needs WRITABLE_TMPFS -- without it this fails with a read-only error on
# /app/foundry/.env that names neither .env nor dotenv.
"$CHPC_TOOL" exec rfdiffusion3 -- foundry list-installed > fi.log 2>&1 || {
    echo "foundry list-installed failed:"; tail -20 fi.log; exit 1; }
grep -q "rfd3" fi.log || { echo "list-installed does not report rfd3:"; cat fi.log; exit 1; }

# Deserialise both checkpoints. A truncated download is still a file and
# still passes `test -s`; torch.load is what distinguishes them, and it is
# the same structural argument as the zip CRC check in the rfdiffusion fetch.
if ! "$CHPC_TOOL" exec rfdiffusion3 -- python - "$d" > load.log 2>&1 <<'PY'
import sys, torch
from pathlib import Path
d = Path(sys.argv[1])
for name in ("rfd3_latest.ckpt", "rf3_foundry_01_24_latest_remapped.ckpt"):
    obj = torch.load(d / name, map_location="cpu", weights_only=False)
    # A checkpoint is a dict with tensors somewhere in it; assert we got
    # something with real parameters rather than an HTML error page that
    # happened to unpickle.
    assert isinstance(obj, dict), (name, type(obj))
    sd = obj.get("state_dict", obj.get("model_state_dict", obj))
    n = sum(v.numel() for v in sd.values() if hasattr(v, "numel"))
    assert n > 1e7, (name, n)
    print(f"ok {name}: {len(sd)} entries, {n:,} parameters")
PY
then
    echo "checkpoint load failed:"; tail -20 load.log; exit 1
fi
cat load.log

echo "ok: both checkpoints deserialise and foundry sees them"
