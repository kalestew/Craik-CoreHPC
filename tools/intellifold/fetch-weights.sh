#!/usr/bin/env bash
# Fetch IntelliFold v2's weights from Hugging Face onto the FAC share.
# LOGIN NODE ONLY -- compute nodes have no route to the internet (doc 02).
#
#   corehpc/tools/intellifold/fetch-weights.sh [input.json]
#
# NOT YET RUN. tools/intellifold is STATUS=planned: there is no image, so this
# cannot have been executed, and it will fail at the first chpc-tool exec until
# `chpc-tool build intellifold` has succeeded. The one thing in it that is
# UNCONFIRMED is marked where it appears -- the minimal AlphaFold-3-dialect
# input used to trigger the download.
#
# Apache-2.0, weights included, commercial use permitted, so nothing here needs
# chpc-assets -- unlike alphafold3, whose parameters arrive by request under
# terms that restrict the outputs.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

eval "$("$CHPC_TOOL" export intellifold)"
dest="$INTELLIFOLD_MODEL_DIR"

# Absolute, and this one is not paranoia: upstream's default --model-dir is the
# RELATIVE `./model_v2`, so a job that cd's anywhere at all gets a different,
# empty directory and then tries to download from a node with no internet.
case "$dest" in
  /*) ;;
  *)  echo "INTELLIFOLD_MODEL_DIR must be an absolute path, got: $dest" >&2; exit 1 ;;
esac
echo "destination: $dest"
mkdir -p "$dest"

# The FAC share carries an inheritable DENY ACL that makes new files unreadable
# by their own owner (doc 02). Repair anything created here or the next job
# gets Permission denied on a directory it just made.
if command -v chpc-fac-fixacl >/dev/null 2>&1; then
  chpc-fac-fixacl "$dest" || true
elif [ -x "${CHPC_LAB:-}/bin/chpc-fac-fixacl" ]; then
  "${CHPC_LAB}/bin/chpc-fac-fixacl" "$dest" || true
else
  echo "note: chpc-fac-fixacl not found -- if anything under $dest is unreadable later, that is why" >&2
fi

# --- drive the tool's own download path -------------------------------------
# Not `huggingface-cli download`, and not curl. Running the CLI a real job runs
# means the repo id, the filenames and the layout are whatever THIS version
# expects, and a rename upstream fails here rather than in a job on a node with
# no internet. Same argument boltz's fetch script makes for calling
# download_boltz2 rather than fetching URLs.
#
# The run itself is EXPECTED TO FAIL: the login node has no GPU. IntelliFold
# resolves and downloads its checkpoint before it touches a device, so the
# artefacts land and only the fold dies. Nothing below trusts the exit status.
#
# UNCONFIRMED: the JSON below follows AlphaFold 3's documented input dialect,
# which upstream says it uses ("The input is an AlphaFold 3-style JSON"), but it
# has never been fed to a running IntelliFold. If it is rejected, the log says
# so and that is the first thing to fix.
inp="${1:-}"
if [ -z "$inp" ]; then
  inp="$PWD/intellifold-fetch-input.json"
  cat > "$inp" <<'JSON'
{
  "name": "fetch_probe",
  "modelSeeds": [1],
  "sequences": [
    {
      "protein": {
        "id": "A",
        "sequence": "MKTAYIAKQRQISFVKSHFSRQLEERLGLIE",
        "unpairedMsa": "",
        "pairedMsa": "",
        "templates": []
      }
    }
  ],
  "dialect": "alphafold3",
  "version": 1
}
JSON
  echo "using built-in probe input: $inp  (dialect UNCONFIRMED -- see comment)"
fi

echo "running intellifold once; a failure for want of a GPU is expected and ignored"
set +e
"$CHPC_TOOL" exec intellifold -- intellifold predict "$inp" \
    --model-dir="$dest" --output-dir="$PWD/intellifold-fetch-out" \
    -- --norun_data_pipeline > intellifold-fetch.log 2>&1
rc=$?
set -e
echo "intellifold exited $rc (not load-bearing)"

# --- assert on the artefacts ------------------------------------------------
# A warm cache and a completely failed run look identical from an exit status.
# Upstream ships TWO files and they are not interchangeable: the checkpoint and
# the Fourier embedding table. Half a download is a directory that looks
# populated and a model that fails at load, which is the expensive version.
ck=$(find "$dest" -maxdepth 2 -type f \( -name '*.bin.zst' -o -name '*.bin' \) 2>/dev/null | head -1 || true)
if [ -z "$ck" ]; then
  echo "no checkpoint (*.bin.zst) under $dest" >&2
  echo "the two likely causes, in order:" >&2
  echo "  1. intellifold rejected the input JSON before downloading anything" >&2
  echo "     -- the dialect in this script is UNCONFIRMED. Read the log." >&2
  echo "  2. --model-dir is not where this version puts its download, so it" >&2
  echo "     landed relative to \$PWD or in a HF cache. Find it, then fix" >&2
  echo "     tool_exports in tools/intellifold/tool.conf." >&2
  echo >&2
  tail -40 intellifold-fetch.log >&2
  exit 1
fi
[ -s "$ck" ] || { echo "checkpoint $ck is empty" >&2; exit 1; }

fo=$(find "$dest" -maxdepth 2 -type f -name '*.npz' 2>/dev/null | head -1 || true)
[ -n "$fo" ] || {
  echo "checkpoint present but no *.npz under $dest." >&2
  echo "upstream ships intellifold_v2.bin.zst AND intellifold_v2_fourier.npz;" >&2
  echo "one without the other loads nothing. Re-run this script." >&2
  exit 1; }
[ -s "$fo" ] || { echo "$fo is empty" >&2; exit 1; }

# NOTE on `find ... | head` under `set -o pipefail`: head exits after N lines,
# find takes SIGPIPE, and the pipeline's status becomes 141, which set -e then
# treats as a failure of the whole script. A display-only pipeline gets `|| true`.
echo
du -sh "$dest" || true
find "$dest" -maxdepth 2 -type f -printf '%13s  %P\n' | sort -k2 || true
echo
echo "checkpoint: $(basename "$ck"), fourier: $(basename "$fo")"
