#!/usr/bin/env bash
# Build a .sif from a .def on the CoreHPC login node, into your scratch.
# Usage: build.sh <file.def> [name_version]      (from anywhere; copy it out of the repo if you like)
set -euo pipefail
def=${1:?usage: build.sh <file.def> [name_version]}
name=${2:-$(basename "${def%.def}")}
: "${CHPC_USER_SCRATCH:=/mnt/scratch/user/${CHPC_USER:-$USER}}"   # set by chpc.env / env.sh if sourced
: "${APPTAINER_CACHEDIR:=$CHPC_USER_SCRATCH/apptainer/cache}"
: "${APPTAINER_TMPDIR:=$CHPC_USER_SCRATCH/apptainer/tmp}"
export APPTAINER_CACHEDIR APPTAINER_TMPDIR
out="$CHPC_USER_SCRATCH/apptainer/${name}.sif"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR" "$(dirname "$out")"
if ! apptainer build --force "$out" "$def"; then
  echo "plain build failed; retrying with --ignore-fakeroot-command (needed for Alpine/musl bases)" >&2
  apptainer build --force --ignore-fakeroot-command "$out" "$def"
fi
echo "built $out"
echo "test:    apptainer exec $out <cmd>"
echo "publish: cp $out \$CHPC_LAB/containers/ && chmod 644 \$CHPC_LAB/containers/$(basename "$out") && chpc-stage-containers"
