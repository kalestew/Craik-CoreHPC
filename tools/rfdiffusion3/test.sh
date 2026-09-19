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

# Assert on the resolver INFERENCE uses, not on `foundry list-installed`.
# list-installed reports "No checkpoint files found in any checkpoint
# directory" even when FOUNDRY_CHECKPOINT_DIRS is set correctly and the
# files are visible from inside the container -- observed 2026-09-18. It
# resolves by some other route, probably the .env that WRITABLE_TMPFS
# discards. Whatever the reason, it is a reporting command, and a test that
# asserted on it would fail on a perfectly usable installation.
#
# checkpoint_registry.get_default_checkpoint_dirs() is what the engines call:
# it reads FOUNDRY_CHECKPOINT_DIRS, splits on colons, and appends
# ~/.foundry/checkpoints. That is the contract worth testing.
if ! "$CHPC_TOOL" exec rfdiffusion3 -- python - "$d" > res.log 2>&1 <<'PY'
import sys
from pathlib import Path
from foundry.inference_engines.checkpoint_registry import get_default_checkpoint_dirs
want = Path(sys.argv[1]).absolute()
dirs = get_default_checkpoint_dirs()
print("search path:", [str(p) for p in dirs])
assert want in dirs, f"{want} not in the resolver's search path"
print("ok: registry resolves", want)
PY
then
    echo "checkpoint resolution failed:"; tail -20 res.log; exit 1
fi
cat res.log

# Deserialise both checkpoints. A truncated download is still a file and
# still passes `test -s`; torch.load is what distinguishes them, and it is
# the same structural argument as the zip CRC check in the rfdiffusion fetch.
if ! "$CHPC_TOOL" exec rfdiffusion3 -- python - "$d" > load.log 2>&1 <<'PY'
import sys, torch
from pathlib import Path
d = Path(sys.argv[1])
for name in ("rfd3_latest.ckpt", "rf3_foundry_01_24_latest_remapped.ckpt"):
    obj = torch.load(d / name, map_location="cpu", weights_only=False)
    assert isinstance(obj, dict), (name, type(obj))
    # foundry's checkpoints put the weights under 'model', not 'state_dict'
    # or 'model_state_dict'. Measured: the top level is
    #   model (OrderedDict, 1616 keys) / optimizer / scheduler_cfg /
    #   global_step / current_epoch / train_cfg
    # so a chain that only tried the two conventional names fell through to
    # the top-level dict, whose values are an OrderedDict and some ints --
    # none with .numel(), giving a parameter count of exactly 0. Try the
    # names, then verify the one chosen actually holds tensors.
    sd = None
    for key in ("model", "state_dict", "model_state_dict"):
        if isinstance(obj.get(key), dict):
            sd = obj[key]
            break
    assert sd is not None, (name, "no weights dict among", list(obj)[:8])
    # Not every entry is a tensor: 'model.use_rmsnorm' is a bool.
    n = sum(v.numel() for v in sd.values() if hasattr(v, "numel"))
    assert n > 1e7, (name, "parameter count", n)
    print(f"ok {name}: {len(sd)} entries, {n:,} parameters")
PY
then
    echo "checkpoint load failed:"; tail -20 load.log; exit 1
fi
cat load.log

echo "ok: both checkpoints deserialise and foundry sees them"
