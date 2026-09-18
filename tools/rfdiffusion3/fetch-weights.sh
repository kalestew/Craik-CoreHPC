#!/usr/bin/env bash
# Fetch RFdiffusion3 (rc-foundry) checkpoints onto the FAC share.
# Login node only -- compute nodes reach a proxy that denies the CDN (doc 02).
#
#   corehpc/tools/rfdiffusion3/fetch-weights.sh [model ...]
#
# Default set is `rfd3 rf3`: the diffusion model and the structure-prediction
# model, which is what backbone design here needs. NOT `all` -- that also
# pulls foundry's own copies of ProteinMPNN, LigandMPNN and SolubleMPNN, which
# the registry already carries as separate entries with their own pinned
# commits, and two copies of the same weights under different provenance is
# how a result becomes unreproducible. Ask for them explicitly if you want
# foundry's versions:
#
#   fetch-weights.sh rfd3 rf3 rfd3na proteinmpnn
#
# Valid names, from `foundry list-available`:
#   rfd3  rfd3na  rf3  proteinmpnn  ligandmpnn  solublempnn
#   rf3_preprint_921  rf3_preprint_124  all
#
# There is NO "base-models" target, despite it being an obvious guess.
#
# BSD-3-Clause, covering code and weights, so nothing here is licensed and
# nothing needs chpc-assets.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

eval "$("$CHPC_TOOL" export rfdiffusion3)"
dest="$FOUNDRY_CHECKPOINT_DIRS"
models=${*:-rfd3 rf3}

echo "destination: $dest"
echo "models:      $models"
mkdir -p "$dest"

# --checkpoint-dir explicitly rather than relying on FOUNDRY_CHECKPOINT_DIRS.
# That variable is a SEARCH path for reading; install still defaults to
# ~/.foundry/checkpoints, and home is 20 GiB here (doc 02) against ~14 GB of
# checkpoints, so getting this wrong fills the quota rather than the share.
# shellcheck disable=SC2086
"$CHPC_TOOL" exec rfdiffusion3 -- foundry install $models --checkpoint-dir "$dest"

echo
echo "installed:"
"$CHPC_TOOL" exec rfdiffusion3 -- foundry list-installed --checkpoint-dir "$dest" 2>/dev/null \
  || "$CHPC_TOOL" exec rfdiffusion3 -- foundry list-installed 2>/dev/null \
  || true

# Assert on the artefacts, not on foundry's exit code.
n=$(find "$dest" -type f \( -name '*.pt' -o -name '*.ckpt' -o -name '*.safetensors' \) | wc -l)
[ "$n" -ge 2 ] || { echo "expected at least 2 checkpoint files in $dest, found $n" >&2; exit 1; }
for f in $(find "$dest" -type f \( -name '*.pt' -o -name '*.ckpt' \)); do
  [ -s "$f" ] || { echo "empty checkpoint $f" >&2; exit 1; }
done

echo
du -sh "$dest"
find "$dest" -type f -printf '%13s  %p\n' | sort -k2
