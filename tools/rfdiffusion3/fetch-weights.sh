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
# `base-models` is ALSO valid, and is the one upstream's README recommends,
# even though neither `foundry install --help` nor `list-available` mentions
# it. download_checkpoints.py:175 expands it to
#   rfd3 rfd3na proteinmpnn ligandmpnn rf3
# We do not use it: it includes foundry's ProteinMPNN and LigandMPNN, which
# this registry already carries as separate entries at their own pinned
# commits.
#
# BSD-3-Clause, covering code and weights, so nothing here is licensed and
# nothing needs chpc-assets.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

eval "$("$CHPC_TOOL" export rfdiffusion3)"
dest="$FOUNDRY_CHECKPOINT_DIRS"
mkdir -p "$dest"

# The covalent-modification test fixture travels with the checkpoints rather
# than with the entry, because the share carries tools/ and not examples/.
# One copy lives in git, under examples/p1b7; this places it where test.sh
# looks. `--fixture` does only this and downloads nothing.
install_fixture() {
  src="$SELF_DIR/../../examples/p1b7/reference/8UDR.cif.gz"
  if [ -f "$src" ]; then
    cp -f "$src" "$dest/8UDR.cif.gz"
    echo "fixture:     $dest/8UDR.cif.gz  ($(stat -c%s "$dest/8UDR.cif.gz") bytes)"
  else
    echo "fixture:     NOT FOUND at $src -- run this from a repo checkout" >&2
  fi
}
if [ "${1:-}" = "--fixture" ]; then
  install_fixture
  exit 0
fi

models=${*:-rfd3 rf3}

echo "destination: $dest"
echo "models:      $models"
install_fixture

# The read-only-image problem this tool has is handled by WRITABLE_TMPFS=1 in
# its tool.conf, not here: foundry persists the checkpoint directory with
# dotenv.set_key() into /app/foundry/.env, dotenv rewrites atomically, and so
# it needs the DIRECTORY writable rather than the file -- a bind over the
# file alone does not help, which cost a round trip to discover. The overlay
# is in memory and discarded at exit, which is correct here: the write is
# 2.5 KB of config nobody needs to keep, and the 14 GB payload goes to
# --checkpoint-dir on the share.

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
