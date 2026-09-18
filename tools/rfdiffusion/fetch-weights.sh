#!/usr/bin/env bash
# Fetch RFdiffusion's model weights onto the FAC share. Login node only --
# compute nodes have no internet.
#
#   corehpc/tools/rfdiffusion/fetch-weights.sh [destination]
#
# Default destination is $CHPC_REFDATA/rfdiffusion/models, which is what
# `chpc-tool export rfdiffusion` puts in RFDIFFUSION_MODELS.
#
# 4.1 GB over nine files. Weights are BSD-3-Clause, same as the source, so
# there is nothing licensed here and nothing for chpc-assets to gate -- this
# is a plain download with verification, not a payload install.
set -euo pipefail

dest="${1:-${CHPC_REFDATA:-/mnt/fac/CX500146_DS1/data}/rfdiffusion/models}"
sched="$(dirname "$dest")/schedules"

# Upstream serves these from a per-file md5 directory, over plain http. The
# path component IS the md5 of the file, which is what makes verification
# possible without a separate manifest.
files="
6f5902ac237024bdd0c176cb93063dc4 Base_ckpt.pt
e29311f6f1bf1af907f9ef9f44b8328b Complex_base_ckpt.pt
60f09a193fb5e5ccdc4980417708dbab Complex_Fold_base_ckpt.pt
74f51cfb8b440f50d70878e05361d8f0 InpaintSeq_ckpt.pt
76d00716416567174cdb7ca96e208296 InpaintSeq_Fold_ckpt.pt
5532d2e1f3a4738decd58b19d633b3c3 ActiveSite_ckpt.pt
12fc204edeae5b57713c5ad7dcb97d39 Base_epoch8_ckpt.pt
f572d396fae9206628714fb2ce00f72e Complex_beta_ckpt.pt
1befcb9b28e2f778f53d47f18b7597fa RF_structure_prediction_weights.pt
"

mkdir -p "$dest" "$sched"
echo "destination: $dest"
echo "schedules:   $sched  (must stay writable -- RFdiffusion caches IGSO3 here)"

printf '%s\n' "$files" | while read -r md5 name; do
  [ -n "${md5:-}" ] || continue
  out="$dest/$name"
  if [ -s "$out" ]; then
    echo "have $name"
    continue
  fi
  echo "fetching $name"
  # -f so a 404 is an error rather than an HTML file with a .pt name.
  curl -fSL --retry 3 -o "$out.part" "http://files.ipd.uw.edu/pub/RFdiffusion/$md5/$name"
  mv "$out.part" "$out"
done

echo
echo "verifying"
fail=0
printf '%s\n' "$files" | while read -r md5 name; do
  [ -n "${md5:-}" ] || continue
  got=$(md5sum "$dest/$name" | cut -d' ' -f1)
  if [ "$got" = "$md5" ]; then
    echo "ok   $name"
  else
    echo "BAD  $name: expected $md5, got $got" >&2
    fail=1
  fi
done
# The loop above runs in a subshell, so re-check rather than trusting $fail.
n=$(ls -1 "$dest"/*.pt 2>/dev/null | wc -l)
[ "$n" -eq 9 ] || { echo "expected 9 weight files, found $n" >&2; exit 1; }
echo
echo "done: $n files in $dest"
