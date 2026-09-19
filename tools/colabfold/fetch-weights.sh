#!/usr/bin/env bash
# Fetch ColabFold's AlphaFold2 parameters onto the FAC share.
# Login node only -- compute nodes reach a proxy that denies
# storage.googleapis.com (doc 02).
#
#   corehpc/tools/colabfold/fetch-weights.sh [model_type ...]
#
# Default set is `alphafold2_ptm alphafold2_multimer_v3`: monomer and the
# current multimer. Roughly 5 GB together. Other valid values, from
# colabfold.download: alphafold2_multimer_v1, alphafold2_multimer_v2.
#
# Weights are CC-BY-4.0 (AlphaFold2), which is why this is a plain download
# and not a chpc-assets payload -- unlike AlphaFold3, they are usable
# commercially and redistributable within the lab.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

eval "$("$CHPC_TOOL" export colabfold)"
dest="$COLABFOLD_DATA"
models=${*:-alphafold2_ptm alphafold2_multimer_v3}

echo "destination: $dest"
echo "models:      $models"
mkdir -p "$dest"

# colabfold's own downloader, not curl: it knows each model_type's URL and
# writes a `download_..._finished.txt` marker that colabfold_batch itself
# checks at run time. Fetching the tarballs by hand would leave the marker
# absent, and colabfold would re-download into a read-only default at the
# start of the first real job.
#
# That default matters: colabfold.download.default_data_dir is
# /cache/colabfold, INSIDE the image. Every invocation must pass
# `--data "$COLABFOLD_DATA"` or it writes to a read-only path.
for m in $models; do
  echo "--- $m"
  "$CHPC_TOOL" exec colabfold -- python - "$m" "$dest" <<'PY'
import sys
from pathlib import Path
from colabfold.download import download_alphafold_params
model_type, data_dir = sys.argv[1], Path(sys.argv[2])
download_alphafold_params(model_type, data_dir)
print("done", model_type)
PY
done

# Assert on the artefacts and on colabfold's own completion markers, not on
# the exit code.
params="$dest/params"
[ -d "$params" ] || { echo "no params directory at $params" >&2; exit 1; }
n=$(find "$params" -name '*.npz' | wc -l)
[ "$n" -ge 5 ] || { echo "expected at least 5 .npz parameter files, found $n" >&2; exit 1; }
m=$(find "$params" -name 'download_*_finished.txt' | wc -l)
[ "$m" -ge 1 ] || { echo "no completion marker; colabfold will re-download" >&2; exit 1; }

echo
du -sh "$dest"
find "$params" -maxdepth 1 -type f -printf '%13s  %f\n' | sort -k2 | head -20
