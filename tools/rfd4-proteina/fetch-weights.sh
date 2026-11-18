#!/usr/bin/env bash
# Stage RFD4-Proteina's model bundle onto the FAC share, and optionally the
# image itself. Login node only -- compute nodes reach a proxy that denies
# huggingface.co (doc 02).
#
#   corehpc/tools/rfd4-proteina/fetch-weights.sh              bundle + digest + fixture
#   corehpc/tools/rfd4-proteina/fetch-weights.sh --image      the cu13 .sif, digest-verified
#   corehpc/tools/rfd4-proteina/fetch-weights.sh --digests     re-record the weights sha256
#   corehpc/tools/rfd4-proteina/fetch-weights.sh --fixture     8UDR only, downloads nothing
#
# TWO FILES, NOT THE REPOSITORY. `hf download --include config.json
# model.safetensors` is not a size optimisation: it is the same allow_patterns
# that utils/hub.py:load_pretrained_bundle passes, so this stages exactly the
# bundle route and nothing else. Pulling the whole repo would also bring the
# ckpt_path/autoencoder_ckpt_path .ckpt files, which this entry has DECIDED not
# to use -- and two routes to the same weights under different provenance is
# how one result stops being comparable with another.
#
# TWO REVISIONS, because one pin cannot express this entry. The weights sit at
# the revision the tool's own configs/inference.yaml declares; the runtime/
# directory holding the images did not exist at that commit and 404s there. Both
# are in tool.conf's UPSTREAM_REF and both are read from it here rather than
# retyped -- a pin restated in a second file is the failure the registry README
# warns about.
#
# BSD-3-Clause, code and weights both, confirmed from the model card 2026-11-16
# (`gated: False`). So nothing here goes through chpc-assets. The AlphaFold2 and
# OpenFold3 refolding images bundled in the SAME repository do carry restrictive
# terms, and this script stages none of them -- which is a property of the
# --include list above, so do not widen it casually.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

HF_REPO=nvidia/RFD4-Proteina

eval "$("$CHPC_TOOL" show --env rfd4-proteina)"
dest="$EXPORT_DATA_PATH"
bundle="$EXPORT_RFD4_BUNDLE"

# The two pins, parsed out of the single UPSTREAM_REF string rather than
# duplicated. If the format of that string changes these go empty and every
# mode below refuses, which is the right direction: a fetch at an unknown
# revision is worse than no fetch.
WEIGHTS_REV=$(printf '%s' "$UPSTREAM_REF" | sed -n 's/.*hf weights @\([0-9a-f]\{40\}\).*/\1/p')
IMAGE_REV=$(printf '%s' "$UPSTREAM_REF"   | sed -n 's/.*hf image @\([0-9a-f]\{40\}\).*/\1/p')

# ------------------------------------------------------------------- fixture
# 8UDR travels with the weights rather than with the entry, because the share
# carries tools/ and not examples/. Same arrangement as rfdiffusion3. One copy
# lives in git under examples/p1b7/reference; this puts it where test.sh looks.
# TWO files, and the manifest is not an extra. test.sh's composition stage
# checksums the CDR3 spans it resolves against the Fab sequences, and
# manifest.json is where this registry already keeps them -- so without it on
# the share that stage either inlines a second copy of two sequences or drops
# the one assertion that catches an off-by-one in a designed loop.
install_fixture() {
  src="$SELF_DIR/../../examples/p1b7"
  mkdir -p "$dest"
  for f in reference/8UDR.cif.gz manifest.json; do
    if [ -f "$src/$f" ]; then
      cp -f "$src/$f" "$dest/$(basename "$f")"
      echo "fixture:  $dest/$(basename "$f")  ($(stat -c%s "$dest/$(basename "$f")") bytes)"
    else
      echo "fixture:  NOT FOUND at $src/$f -- run this from a repo checkout, not the share" >&2
      return 1
    fi
  done
}

# ------------------------------------------------------------------- digests
# Record sha256 for both bundle files, as sidecars beside them.
#
# This is what a GeneratorIdentity's weights_digest is sourced from, and the
# reason it is RECORDED rather than recomputed on demand: the consuming project
# needs a weights digest at plan time on a coordinator that may not have the
# share mounted, and hashing 1.7 GB over NFS on every plan is not a thing
# anybody would leave switched on. Written once, here, where the bytes just
# arrived and are known good.
record_digests() {
  [ -d "$bundle" ] || { echo "no bundle at $bundle -- fetch it first" >&2; return 1; }
  for f in config.json model.safetensors; do
    [ -s "$bundle/$f" ] || { echo "$bundle/$f missing or empty" >&2; return 1; }
    ( cd "$bundle" && sha256sum "$f" > "$f.sha256" )
    echo "digest:   $f  $(cut -d' ' -f1 "$bundle/$f.sha256")"
  done
}

# --------------------------------------------------------------------- image
# curl, not `hf download`, and not chpc-tool exec. Two reasons, both structural.
# (1) The image cannot be fetched from inside itself -- that is what every other
# mode here does, and it is circular for exactly this one file. (2) `hf` is in
# the image and nowhere else, so this is the one artefact the HOST has to get.
# curl with --retry-all-errors and -C - is the registry's established answer for
# a multi-gigabyte pull over the site proxy; see chai1's 5.6 GB ESM trace, which
# discarded 4.4 GB once before it was written this way.
fetch_image() {
  [ -n "$IMAGE_REV" ] || { echo "no image revision in UPSTREAM_REF" >&2; return 1; }
  [ -n "${DIGEST:-}" ] || { echo "this entry records no DIGEST -- refusing to fetch an unverifiable image" >&2; return 1; }
  command -v curl >/dev/null 2>&1 || { echo "no curl on this host" >&2; return 1; }

  want=${DIGEST#sha256:}
  case "$DIGEST" in
    sha256:*) ;;
    *) echo "DIGEST declares an algorithm this script cannot verify: $DIGEST" >&2; return 1 ;;
  esac

  # IMAGE_CANONICAL is the durable FAC copy, which is where an image belongs:
  # the scratch mirror is purged at 30 days. chpc-stage-containers mirrors it
  # afterwards; this does not, because a 4 GB write to scratch that a purge
  # reclaims is not this script's business.
  out="$IMAGE_CANONICAL"
  [ -n "$out" ] || { echo "no IMAGE_CANONICAL -- is this entry KIND=container?" >&2; return 1; }
  mkdir -p "$(dirname "$out")"

  if [ -s "$out" ]; then
    echo "image:    already at $out -- verifying rather than refetching"
  else
    url="https://huggingface.co/$HF_REPO/resolve/$IMAGE_REV/runtime/$IMAGE"
    echo "image:    fetching $IMAGE (4.04 GB, resumable)"
    echo "          $url"
    curl -fL --retry 10 --retry-delay 5 --retry-all-errors -C - -o "$out.part" "$url"
    mv "$out.part" "$out"
  fi

  got=$(sha256sum "$out" | cut -d' ' -f1)
  if [ "$got" != "$want" ]; then
    echo >&2
    echo "REFUSING this image: it is not the bytes tool.conf records." >&2
    echo "  at:       $out" >&2
    echo "  recorded: sha256:$want" >&2
    echo "  measured: sha256:$got" >&2
    echo >&2
    echo "Left in place as .rejected so it can be looked at rather than refetched blind." >&2
    mv "$out" "$out.rejected"
    return 1
  fi
  echo "image:    sha256 matches tool.conf's DIGEST"
  echo "image:    $out  ($(stat -c%s "$out") bytes)"
  # The share's inheritable DENY ACL makes a new file unreadable by its own
  # owner (doc 02). Every published artefact needs this and forgetting it looks
  # like a missing file.
  command -v chpc-fac-fixacl >/dev/null 2>&1 && chpc-fac-fixacl "$out" || true
}

case "${1:-}" in
  --fixture) install_fixture; exit 0 ;;
  --digests) record_digests; exit 0 ;;
  --image)   fetch_image; exit 0 ;;
  --ccd)
    # --ccd existed in this entry's first draft and is REFUSED rather than
    # removed, because tool_doctor told operators to run it and that message
    # may outlive this file in somebody's notes. atomworks treats a configured
    # CCD_MIRROR_PATH as the ONLY source of components: measured in this image,
    # a MOV-only mirror leaves 1 standard CCD code and makes ALA raise, against
    # 49195 codes with no mirror at all. A partial mirror is worse than none,
    # so the entry no longer exports the variable. See tool.conf's tool_exports.
    echo "--ccd is refused: a PARTIAL CCD mirror is worse than no mirror." >&2
    echo "  atomworks disables its biotite fallback the moment CCD_MIRROR_PATH is" >&2
    echo "  set, so a mirror holding one ligand makes every amino acid unknown." >&2
    echo "  This entry exports no CCD_MIRROR_PATH and needs no mirror; biotite's" >&2
    echo "  bundled CCD resolved MOV's 41 heavy atoms in the composition check." >&2
    echo "  To mirror the CCD properly it has to be COMPLETE (~49k components)," >&2
    echo "  and re-exporting the variable is then a deliberate edit." >&2
    exit 2 ;;
  "") ;;
  *) echo "usage: fetch-weights.sh [--image|--digests|--fixture]" >&2; exit 2 ;;
esac

# ------------------------------------------------------------------- default
[ -n "$WEIGHTS_REV" ] || { echo "no weights revision in UPSTREAM_REF -- refusing to fetch at an unknown pin" >&2; exit 1; }

echo "destination: $bundle"
echo "repo:        $HF_REPO @ $WEIGHTS_REV"
mkdir -p "$bundle"

# --local-dir so the two files land as themselves rather than inside a hub
# cache tree. load_pretrained_bundle reads "$RFD4_BUNDLE/config.json" and
# "$RFD4_BUNDLE/model.safetensors" by name, so the layout is the contract.
#
# The two files are POSITIONAL, not `--include`. `include` is a list of GLOB
# patterns and is repeatable, so `--include config.json model.safetensors`
# would pass one pattern and leave the second word to be parsed as a
# positional filename -- which happens to work and means something else.
# Naming the two files exactly is both what load_pretrained_bundle's
# allow_patterns amounts to and unambiguous about it.
#
# `env HF_HUB_OFFLINE=0` matters and is not belt-and-braces: the entry exports
# HF_HUB_OFFLINE=1 so that a misresolved bundle path on a compute node fails in
# seconds instead of hanging, and chpc-tool exec puts the registry's value into
# the container unconditionally. Without this override the one command that is
# SUPPOSED to reach the network refuses, from the variable that exists to make
# every other command refuse. Set on the command rather than around it, so the
# exception is visible at the point it applies and nowhere wider.
"$CHPC_TOOL" exec rfd4-proteina -- env HF_HUB_OFFLINE=0 \
  hf download "$HF_REPO" config.json model.safetensors \
  --revision "$WEIGHTS_REV" \
  --local-dir "$bundle"

# --- assert on the artefacts, not on hf's exit code -------------------------
for f in config.json model.safetensors; do
  [ -s "$bundle/$f" ] || { echo "hf exited 0 but $bundle/$f is missing or empty" >&2; exit 1; }
done

# model.safetensors is 1,742,660,596 bytes at this pin and upstream's
# release-checkpoints.json records its sha256 as the bundle digest. Check the
# SIZE here and the digest below: a truncated download is still a file, and a
# resumed one that stopped mid-stream passes `test -s`.
sz=$(stat -c%s "$bundle/model.safetensors")
[ "$sz" -gt 1700000000 ] || {
  echo "model.safetensors is $sz bytes, which is short of the ~1.74 GB this pin publishes." >&2
  echo "That is a truncated download, not a different release -- rerun this script." >&2
  exit 1; }

record_digests
install_fixture

# --- and it deserialises ----------------------------------------------------
# The real check, and the same argument as chai1's torch.jit.load pass: a
# safetensors file either opens and has the tensors its header claims, or it
# does not, and no size check can tell the difference. Done here rather than
# left to test.sh so that a bad download is caught where it happened.
"$CHPC_TOOL" exec rfd4-proteina -- python - "$bundle" <<'PY'
import json, pathlib, sys
from safetensors import safe_open

b = pathlib.Path(sys.argv[1])
cfg = json.loads((b / "config.json").read_text())
print("config.json keys:", ", ".join(sorted(cfg)[:8]))

with safe_open(b / "model.safetensors", framework="pt", device="cpu") as fh:
    keys = list(fh.keys())
    n = 0
    for k in keys:
        sl = fh.get_slice(k)
        shape = sl.get_shape()
        c = 1
        for d in shape:
            c *= d
        n += c
print(f"ok: {len(keys)} tensors, {n:,} parameters")
# A bundle that opened but holds a handful of tensors is not this model.
assert n > 1e7, f"parameter count {n} is too small to be the flow model"
PY

echo
du -sh "$dest"
find "$dest" -type f -printf '%13s  %p\n' | sort -k2
echo
echo "next: chpc-tool doctor rfd4-proteina   then   chpc-tool test rfd4-proteina"
echo "      the image itself:  tools/rfd4-proteina/fetch-weights.sh --image"
