#!/usr/bin/env bash
# Fetch Protenix v1's checkpoint and chemical component dictionary onto FAC.
# LOGIN NODE ONLY -- compute nodes have no route to the internet (doc 02).
#
#   corehpc/tools/protenix/fetch-weights.sh [input.json] [model_name]
#
# NOT YET RUN. tools/protenix is STATUS=planned: there is no image, so this
# script cannot have been executed, and it will fail at the first chpc-tool
# exec until `chpc-tool build protenix` has succeeded. Two things in it are
# UNCONFIRMED against a built image and are marked inline where they appear --
# the environment variable names Protenix uses for its cache root, and the
# minimal input JSON. Fix them here the first time this is run, and say in
# README.md which one was wrong.
#
# Destination is whatever `chpc-tool export protenix` resolves
# PROTENIX_ROOT_DIR to. It is deliberately not an argument: chpc-tool exec
# exports the registry's value unconditionally (and as APPTAINERENV_*, which
# is the only form that beats a name the image's own %environment sets), so a
# value passed here would be overridden inside the container anyway.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

eval "$("$CHPC_TOOL" export protenix)"
dest="$PROTENIX_ROOT_DIR"

# Absolute, for boltz's reason: a relative cache is resolved against the
# working directory, and several stages cd before running, so a job silently
# uses a different, empty cache and then tries to download from a node with no
# internet.
case "$dest" in
  /*) ;;
  *)  echo "PROTENIX_ROOT_DIR must be an absolute path, got: $dest" >&2; exit 1 ;;
esac
echo "destination: $dest"
mkdir -p "$dest"

# The FAC share has an inheritable DENY ACL that makes new files unreadable by
# their own owner. Anything created here needs repairing or the next job gets
# `Permission denied` on a directory it just made (doc 02).
if command -v chpc-fac-fixacl >/dev/null 2>&1; then
  chpc-fac-fixacl "$dest" || true
elif [ -x "${CHPC_LAB:-}/bin/chpc-fac-fixacl" ]; then
  "${CHPC_LAB}/bin/chpc-fac-fixacl" "$dest" || true
else
  echo "note: chpc-fac-fixacl not found -- if anything under $dest is unreadable later, that is why" >&2
fi

# --- the model, and the licence ---------------------------------------------
# v1 by default and by policy. The v2 weights are proprietary and confidential,
# carry no open-source licence, and -- like AlphaFold 3's -- the restriction
# attaches to what you DO with the structures, not just to the file. This is a
# therapeutic programme; do not stage them on a shared lab filesystem.
#
# Names taken from upstream's model table (README, checked 2026-09-24):
#   protenix_base_default_v1.0.0   368 M   Apache-2.0
#   protenix_base_20250630_v1.0.0  368 M   Apache-2.0
#   protenix-v2                    464 M   PROPRIETARY -- not here
model="${2:-protenix_base_default_v1.0.0}"
case "$model" in
  *v2*|*V2*)
    echo "refusing to fetch '$model': the Protenix v2 weights are proprietary," >&2
    echo "carry no open-source licence, and restrict the use of the structures" >&2
    echo "they produce. This entry is v1 only -- see tools/protenix/README.md." >&2
    exit 1 ;;
esac
echo "model: $model"

# --- drive the tool's own download path -------------------------------------
# Not curl. Using the CLI that a real job uses means the layout, the filenames
# and the CCD artefacts are whatever THIS version expects, and a rename
# upstream fails here rather than in a job on a node with no internet. It is
# the same argument boltz's fetch script makes for calling download_boltz2
# instead of fetching URLs.
#
# The run itself is EXPECTED TO FAIL: the login node has no GPU. That is fine.
# Protenix resolves and downloads its checkpoint and CCD before it touches a
# device, so the artefacts land and only the fold dies. Nothing below trusts
# the exit status; the assertions are on the files.
#
# UNCONFIRMED: the input JSON below has not been validated against a built
# image. Upstream's schema is docs/infer_json_format.md. If protenix rejects
# it, that is what the log will say -- fix it here and record it in README.md.
inp="${1:-}"
if [ -z "$inp" ]; then
  inp="$PWD/protenix-fetch-input.json"
  cat > "$inp" <<'JSON'
[
  {
    "name": "fetch_probe",
    "sequences": [
      {
        "proteinChain": {
          "sequence": "MKTAYIAKQRQISFVKSHFSRQLEERLGLIE",
          "count": 1
        }
      }
    ]
  }
]
JSON
  echo "using built-in probe input: $inp  (schema UNCONFIRMED -- see comment)"
fi

echo "running protenix once; a failure for want of a GPU is expected and ignored"
set +e
"$CHPC_TOOL" exec protenix -- protenix pred \
    -i "$inp" -o "$PWD/protenix-fetch-out" -n "$model" > protenix-fetch.log 2>&1
rc=$?
set -e
echo "protenix exited $rc (not load-bearing)"

# --- assert on the artefacts ------------------------------------------------
# A warm cache and a completely failed run look identical from an exit status,
# which is exactly why boltz's fetch script asserts on files. Do the same.
ck="$dest/checkpoint"
n=$(find "$ck" -type f -name '*.pt' 2>/dev/null | wc -l)
if [ "$n" -lt 1 ]; then
  echo "no checkpoint under $ck" >&2
  echo "the two likely causes, in order:" >&2
  echo "  1. protenix rejected the input JSON before downloading anything --" >&2
  echo "     the schema in this script is UNCONFIRMED. Read the log." >&2
  echo "  2. PROTENIX_ROOT_DIR is not the variable this version reads, so the" >&2
  echo "     download landed somewhere else (HOME, most likely). Find it," >&2
  echo "     then fix tool_exports in tools/protenix/tool.conf." >&2
  echo >&2
  tail -40 protenix-fetch.log >&2
  exit 1
fi
for f in $(find "$ck" -type f -name '*.pt'); do
  [ -s "$f" ] || { echo "empty checkpoint $f" >&2; exit 1; }
done

# Licence guard, again, on what actually landed. A default that changed
# upstream is exactly how a proprietary checkpoint ends up on a shared share.
v2=$(find "$ck" -type f -name '*v2*' 2>/dev/null | head -1 || true)
[ -z "$v2" ] || {
  echo "a v2 checkpoint was downloaded: $v2" >&2
  echo "those weights are proprietary. Delete it and pin -n explicitly." >&2
  exit 1; }

# The CCD is what lets Protenix resolve ligand chemistry. A weights-only cache
# looks complete until the first fold with a hapten in it -- the same shape as
# boltz's mols.tar trap, where the cache passed every count and every job still
# tried to re-download.
nccd=$(find "$dest/common" -type f 2>/dev/null | wc -l)
[ "$nccd" -ge 1 ] || {
  echo "no chemical component dictionary under $dest/common" >&2
  echo "every ligand fold needs it, and a compute node cannot fetch it." >&2
  exit 1; }
echo "CCD: $nccd file(s) under $dest/common"

# NOTE on `find ... | head` under `set -o pipefail`: head exits after N lines,
# find takes SIGPIPE, and the pipeline's status becomes 141, which set -e then
# treats as a failure of the whole script. Anywhere a pipeline is only for
# display, terminate it with `|| true`.
echo
du -sh "$dest" || true
find "$dest" -maxdepth 2 -type f -printf '%13s  %P\n' | sort -k2 || true
echo
echo "checkpoints: $n, model: $model"
