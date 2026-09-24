#!/usr/bin/env bash
# Fetch OpenFold3's parameters from Hugging Face onto the FAC share.
# LOGIN NODE ONLY -- compute nodes have no route to the internet (doc 02).
#
#   corehpc/tools/openfold3/fetch-weights.sh [query.json]
#
# NOT YET RUN. tools/openfold3 is STATUS=planned: there is no image, so this
# cannot have been executed. The UNCONFIRMED parts are marked where they
# appear -- which flag `run_openfold` takes for a weights directory, and the
# query JSON schema.
#
# Apache-2.0 on code and weights both, so nothing here needs chpc-assets --
# unlike alphafold3, whose parameters arrive by request under terms that
# restrict the outputs for years after the run.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

eval "$("$CHPC_TOOL" export openfold3)"
dest="$OPENFOLD3_WEIGHTS"

case "$dest" in
  /*) ;;
  *)  echo "OPENFOLD3_WEIGHTS must be an absolute path, got: $dest" >&2; exit 1 ;;
esac
echo "destination: $dest"
mkdir -p "$dest" "$HF_HOME"

# The FAC share carries an inheritable DENY ACL that makes new files unreadable
# by their own owner (doc 02).
if command -v chpc-fac-fixacl >/dev/null 2>&1; then
  chpc-fac-fixacl "$dest" || true
elif [ -x "${CHPC_LAB:-}/bin/chpc-fac-fixacl" ]; then
  "${CHPC_LAB}/bin/chpc-fac-fixacl" "$dest" || true
else
  echo "note: chpc-fac-fixacl not found -- if anything under $dest is unreadable later, that is why" >&2
fi

# --- weights ----------------------------------------------------------------
# Upstream's parameters live on Hugging Face at OpenFold/OpenFold3, and the
# default set shipped from 0.5.0 is OpenBind-0. HF_HOME is exported by the
# registry and points INSIDE $dest, so whatever the download mechanism turns
# out to be -- setup_openfold, a huggingface_hub call from run_openfold, or an
# explicit flag -- the bytes land on FAC and not in a scratch cache that is
# purged at 30 days.
#
# Two mechanisms are tried, in the order that costs least if it works. Neither
# is confirmed against a built image; whichever one works, delete the other and
# say so in README.md.

echo "1/2: setup_openfold inside the image"
set +e
"$CHPC_TOOL" exec openfold3 -- setup_openfold > of3-setup.log 2>&1
rc1=$?
set -e
echo "setup_openfold exited $rc1"

n=$(find "$dest" -type f \( -name '*.pt' -o -name '*.ckpt' -o -name '*.safetensors' \) 2>/dev/null | wc -l)
if [ "$n" -lt 1 ]; then
  echo "2/2: no parameters yet -- running one prediction so the tool fetches its own"
  # The run is EXPECTED TO FAIL: the login node has no GPU. OpenFold3 resolves
  # and downloads before it touches a device, so the artefacts land and only
  # the fold dies. Nothing below trusts the exit status; the assertions are on
  # the files. Same argument boltz's fetch script makes for using the tool's
  # own code path rather than curl: a rename upstream fails HERE, not in a job
  # on a node with no route out.
  q="${1:-}"
  if [ -z "$q" ]; then
    # Prefer upstream's OWN example over a schema guessed from a README. The
    # query format is UNCONFIRMED and this is the cheapest way not to guess.
    q_in=$("$CHPC_TOOL" exec openfold3 -- sh -c \
      'find / -xdev -path "*example*" -name "query_*.json" 2>/dev/null | head -1' || true)
    if [ -n "$q_in" ]; then
      echo "using upstream's own example: $q_in"
      "$CHPC_TOOL" exec openfold3 -- cat "$q_in" > of3-query.json
      q="$PWD/of3-query.json"
    else
      echo "no upstream example found inside the image; cannot guess a query" >&2
      echo "schema. Pass one: $0 <query.json>" >&2
      tail -30 of3-setup.log >&2
      exit 1
    fi
  fi
  set +e
  "$CHPC_TOOL" exec openfold3 -- run_openfold predict \
      --query_json="$q" > of3-fetch.log 2>&1
  rc2=$?
  set -e
  echo "run_openfold exited $rc2 (not load-bearing)"
fi

# --- assert on the artefacts ------------------------------------------------
# A warm cache and a completely failed run look identical from an exit status,
# which is exactly why boltz's fetch script asserts on files.
n=$(find "$dest" -type f \( -name '*.pt' -o -name '*.ckpt' -o -name '*.safetensors' \) 2>/dev/null | wc -l)
if [ "$n" -lt 1 ]; then
  echo "no model parameters under $dest" >&2
  echo "the likely causes, in order:" >&2
  echo "  1. setup_openfold takes a destination argument this script does not" >&2
  echo "     pass, so the download went to a default inside \$HOME." >&2
  echo "  2. HF_HOME is not what this version reads; find where the download" >&2
  echo "     landed, then fix tool_exports in tools/openfold3/tool.conf." >&2
  echo "  3. the query schema was rejected before anything was fetched." >&2
  echo >&2
  tail -30 of3-setup.log >&2
  [ -f of3-fetch.log ] && tail -30 of3-fetch.log >&2
  exit 1
fi
for f in $(find "$dest" -type f \( -name '*.pt' -o -name '*.ckpt' -o -name '*.safetensors' \)); do
  [ -s "$f" ] || { echo "empty parameter file $f" >&2; exit 1; }
done

# NOTE on `find ... | head` under `set -o pipefail`: head exits after N lines,
# find takes SIGPIPE, the pipeline's status becomes 141, and set -e treats that
# as a failure of the whole script. A display-only pipeline gets `|| true`.
echo
du -sh "$dest" || true
find "$dest" -maxdepth 3 -type f -printf '%13s  %P\n' | sort -k2 || true
echo
echo "parameter files: $n"
echo
echo "Reminder: this fetches WEIGHTS. It says nothing about whether OpenFold3"
echo "accepts a covalent bond -- that is still unqualified, and"
echo "chpc-tool test openfold3 is the only thing that answers it."
