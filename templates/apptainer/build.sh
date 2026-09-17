#!/usr/bin/env bash
# Build a .sif from a .def on the CoreHPC login node, into your scratch.
# Usage: templates/apptainer/build.sh <file.def> [name_version]
set -euo pipefail
def=${1:?usage: build.sh <file.def> [name_version]}
name=${2:-$(basename "${def%.def}")}
: "${APPTAINER_CACHEDIR:=/mnt/scratch/user/$USER/apptainer/cache}"
: "${APPTAINER_TMPDIR:=/mnt/scratch/user/$USER/apptainer/tmp}"
export APPTAINER_CACHEDIR APPTAINER_TMPDIR
out="/mnt/scratch/user/$USER/apptainer/${name}.sif"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR" "$(dirname "$out")"
if ! apptainer build "$out" "$def"; then
  echo "plain build failed; retrying with --fakeroot" >&2
  apptainer build --fakeroot "$out" "$def"
fi
echo "built $out"
echo "test:    apptainer exec $out <cmd>"
echo "publish: cp $out \$CHPC_LAB/containers/ && chmod 644 \$CHPC_LAB/containers/$(basename "$out") && chpc-stage-containers"
