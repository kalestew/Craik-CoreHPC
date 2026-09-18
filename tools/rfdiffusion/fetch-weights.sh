#!/usr/bin/env bash
# Fetch RFdiffusion's model weights onto the FAC share. Login node only --
# compute nodes reach a proxy that denies files.ipd.uw.edu (doc 02).
#
#   corehpc/tools/rfdiffusion/fetch-weights.sh [destination]
#
# Default destination is $CHPC_REFDATA/rfdiffusion/models, which is what
# `chpc-tool export rfdiffusion` puts in RFDIFFUSION_MODELS.
#
# 3.7 GiB over nine files. Weights are BSD-3-Clause, same as the source, so
# there is nothing licensed here and nothing for chpc-assets to gate -- this
# is a plain download with verification, not a payload install.
set -euo pipefail

dest="${1:-${CHPC_REFDATA:-/mnt/fac/CX500146_DS1/data}/rfdiffusion/models}"
sched="$(dirname "$dest")/schedules"

# THE DIRECTORY COMPONENT IN THE URL IS NOT A CHECKSUM. An earlier version of
# this script assumed it was -- the URLs look exactly like a content-addressed
# store -- and "verified" every download against it. All nine failed, because
# upstream simply picked opaque directory names: f572d396fae9206628714fb2ce00f72e
# is md5("hello\n") and 6f5902ac237024bdd0c176cb93063dc4 is md5("hello world\n").
# They are throwaway strings, not hashes of 483 MB tensors.
#
# So there are two independent columns below, and they do different jobs:
#   dir  -- upstream's opaque path component. Copy it, do not interpret it.
#   md5  -- measured by us on 2026-09-18 from a set independently confirmed
#           intact by the CRC check below. This is a local manifest; upstream
#           publishes no checksums.
#
# The CRC check is the one that does not depend on this table being right,
# which is why it runs too. A .pt is a zip archive with a CRC32 per member,
# so a truncated or corrupted download cannot pass it -- and unlike the md5
# column, it needs no prior knowledge of the correct bytes.
#
#     dir                               name                               md5
files="
6f5902ac237024bdd0c176cb93063dc4 Base_ckpt.pt                       4aa4a27ba280d23541e01860c106c7cc
e29311f6f1bf1af907f9ef9f44b8328b Complex_base_ckpt.pt               7a5d99f3c8bede52d9240f79a99bc30b
60f09a193fb5e5ccdc4980417708dbab Complex_Fold_base_ckpt.pt          9c000b475b293b54bcf5fbd8109f5794
74f51cfb8b440f50d70878e05361d8f0 InpaintSeq_ckpt.pt                 a6f8652938bb45c332ffa683d8ad3509
76d00716416567174cdb7ca96e208296 InpaintSeq_Fold_ckpt.pt            1e9245a486262dff3cb3286f22a3014d
5532d2e1f3a4738decd58b19d633b3c3 ActiveSite_ckpt.pt                 0d9f82af03c73011c6fec060bac5b731
12fc204edeae5b57713c5ad7dcb97d39 Base_epoch8_ckpt.pt                5c58d7d5c329c1297fab0aa6cebad81b
f572d396fae9206628714fb2ce00f72e Complex_beta_ckpt.pt               5bb77fc129777d742045a444f43bf587
1befcb9b28e2f778f53d47f18b7597fa RF_structure_prediction_weights.pt 6f4d00394d34f6a9072d70976f6c8777
"

mkdir -p "$dest" "$sched"
echo "destination: $dest"
echo "schedules:   $sched  (must stay writable -- RFdiffusion caches IGSO3 here)"
echo

_md5() { md5sum "$1" | cut -d' ' -f1; }

# `done <<EOF`, never `printf ... | while`. A pipe puts the loop in a subshell,
# so every count and flag it sets is discarded when the loop ends -- which is
# exactly how the previous version managed to report nine verification
# failures and still exit 0 with "done".
while read -r dir name md5; do
  [ -n "${dir:-}" ] || continue
  out="$dest/$name"
  if [ -s "$out" ] && [ "$(_md5 "$out")" = "$md5" ]; then
    echo "have $name"
    continue
  fi
  [ -s "$out" ] && echo "re-fetching $name (present but wrong md5)" || echo "fetching $name"
  # -f so a 404 is an error rather than an HTML page saved under a .pt name.
  curl -fSL --retry 3 -o "$out.part" "http://files.ipd.uw.edu/pub/RFdiffusion/$dir/$name"
  mv "$out.part" "$out"
done <<EOF
$files
EOF

echo
echo "verifying (md5 against the manifest, then zip CRC32 per member)"
fail=0
while read -r dir name md5; do
  [ -n "${dir:-}" ] || continue
  out="$dest/$name"
  got=$(_md5 "$out")
  if [ "$got" != "$md5" ]; then
    echo "BAD  $name: md5 expected $md5, got $got" >&2
    fail=$((fail + 1))
    continue
  fi
  if ! python3 - "$out" <<'PY'
import sys, zipfile
try:
    with zipfile.ZipFile(sys.argv[1]) as z:
        bad = z.testzip()
except zipfile.BadZipFile as e:
    print(f"not a zip archive: {e}", file=sys.stderr); sys.exit(1)
if bad:
    print(f"CRC failure in member {bad}", file=sys.stderr); sys.exit(1)
PY
  then
    echo "BAD  $name: md5 matched but the archive is corrupt" >&2
    fail=$((fail + 1))
    continue
  fi
  echo "ok   $name"
done <<EOF
$files
EOF

n=$(ls -1 "$dest"/*.pt 2>/dev/null | wc -l)
echo
if [ "$fail" -ne 0 ]; then
  echo "FAILED: $fail of 9 files did not verify -- do not run RFdiffusion against this set" >&2
  exit 1
fi
[ "$n" -eq 9 ] || { echo "expected 9 weight files, found $n" >&2; exit 1; }
echo "done: $n files verified in $dest"
