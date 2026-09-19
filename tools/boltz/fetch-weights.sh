#!/usr/bin/env bash
# Fetch Boltz-2's weights and CCD onto the FAC share.
# Login node only -- compute nodes reach a proxy that denies the CDN (doc 02).
#
#   corehpc/tools/boltz/fetch-weights.sh
#
# Destination is whatever `chpc-tool export boltz` resolves BOLTZ_CACHE to.
# It is not an argument: chpc-tool exec exports the registry's value
# unconditionally, so a value passed here would be overridden inside the
# container.
#
# MIT, weights included, so nothing here needs chpc-assets.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

eval "$("$CHPC_TOOL" export boltz)"
dest="$BOLTZ_CACHE"
echo "destination: $dest"
mkdir -p "$dest"

# boltz.main.download_boltz2(cache) is the function `boltz predict` itself
# calls on a cold cache. Using it rather than curl means the layout, the
# filenames and the CCD/mol artefacts are whatever this version expects --
# and a rename upstream is an ImportError here instead of a job that
# re-downloads 6 GB from a node with no route to the internet.
#
# BOLTZ_CACHE must be ABSOLUTE. boltz resolves --cache relative to the
# working directory otherwise, and a job that cd's elsewhere then silently
# uses a different, empty cache.
case "$dest" in
  /*) ;;
  *)  echo "BOLTZ_CACHE must be an absolute path, got: $dest" >&2; exit 1 ;;
esac

"$CHPC_TOOL" exec boltz -- python - "$dest" <<'PY'
import sys
from pathlib import Path
from boltz.main import download_boltz2
cache = Path(sys.argv[1])
cache.mkdir(parents=True, exist_ok=True)
download_boltz2(cache)
print("download_boltz2 returned")
PY

# Assert on the artefacts. download_boltz2 is quiet on a warm cache, so a
# no-op run and a successful one look identical from the exit code alone.
n=$(find "$dest" -type f \( -name '*.ckpt' -o -name '*.pt' \) | wc -l)
[ "$n" -ge 1 ] || { echo "no model checkpoint under $dest" >&2; exit 1; }
for f in $(find "$dest" -type f \( -name '*.ckpt' -o -name '*.pt' \)); do
  [ -s "$f" ] || { echo "empty checkpoint $f" >&2; exit 1; }
done

# The CCD is what lets boltz resolve ligand chemistry; a weights-only cache
# looks fine until the first run with a small molecule in it.
#
# DO NOT DELETE mols.tar after extraction, however tempting 1.86 GB of
# apparent duplication is. download_boltz2 tests the two independently:
#
#   if not tar_mols.exists():   urlretrieve(MOL_URL, tar_mols)
#   if not mols.exists():       tarfile.open(tar_mols).extractall(cache)
#
# and `boltz predict` calls download_boltz2 on every run. Remove the tar and
# every job re-downloads it -- from a compute node with no route out, which
# means every job fails. Assert it is still there.
[ -s "$dest/mols.tar" ] || {
  echo "mols.tar is missing from $dest." >&2
  echo "boltz re-downloads it on every run if absent, even when mols/ exists," >&2
  echo "and a compute node cannot reach the CDN. Re-run this script." >&2
  exit 1; }
[ -d "$dest/mols" ] || { echo "no CCD (mols/) under $dest" >&2; exit 1; }
nmols=$(find "$dest/mols" -maxdepth 1 -type f | wc -l)
[ "$nmols" -gt 1000 ] || { echo "CCD looks truncated: $nmols entries in $dest/mols" >&2; exit 1; }
echo "CCD: $nmols entries"

# NOTE `find ... | head` under `set -o pipefail`. head exits after N lines,
# find takes SIGPIPE, and the pipeline's status becomes 141 -- which set -e
# then treats as a failure of the whole script. This function reported
# FETCH-EXIT=141 after a completely successful 5 GB download because of a
# listing line. Anywhere a pipeline is only for display, terminate it with
# `|| true` or do not pipe at all.
echo
du -sh "$dest"
find "$dest" -maxdepth 1 -type f -printf '%13s  %P\n' | sort -k2 || true
