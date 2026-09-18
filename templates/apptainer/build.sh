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

# Bind mounts are a RUNTIME concern and must not leak into a build. chpc.env
# exports APPTAINER_BIND=/mnt/scratch,/mnt/fac on every cluster node, and
# `apptainer build` honours it while running %post -- against a base image
# that has no /mnt/fac to mount onto. The build then dies with
#   FATAL: mount /mnt/fac->/mnt/fac error: destination doesn't exist in container
#   While performing build: while running %post section: exit status 255
# which reads like a broken recipe and is really an environment variable that
# should never have been in scope. Verified on the login node 2026-09-17.
unset APPTAINER_BIND SINGULARITY_BIND APPTAINER_BINDPATH SINGULARITY_BINDPATH
out="$CHPC_USER_SCRATCH/apptainer/${name}.sif"
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR" "$(dirname "$out")"
# Retry ONLY on the failure --ignore-fakeroot-command actually fixes.
#
# Apptainer prints "If error was from fakeroot, try --ignore-fakeroot-command"
# after *any* failed %post, so a blind retry doubles the wall time of every
# genuine recipe error -- ten minutes each, on a login node capped at 4 CPUs,
# to reproduce a failure we already have. The flag only helps when the injected
# fakeroot shim cannot start, which is a musl/Alpine base missing glibc and
# says so: "exec /.singularity.d/libs/fakeroot failed: a shared library is
# likely missing". Match that, and let everything else fail once.
_log=$(mktemp "${APPTAINER_TMPDIR}/build-XXXXXX.log")
# Branch on the exit status, not on whether $out exists: --force means a stale
# image from a previous successful build is still sitting there, so a file test
# would call a failed rebuild a success. `set -o pipefail` is on, so the
# pipeline carries apptainer's status through tee.
_rc=0
apptainer build --force "$out" "$def" 2>&1 | tee "$_log" || _rc=$?
if [ "$_rc" -ne 0 ]; then
  if grep -q 'libs/fakeroot failed' "$_log"; then
    echo "fakeroot shim could not start (musl/Alpine base); retrying with --ignore-fakeroot-command" >&2
    apptainer build --force --ignore-fakeroot-command "$out" "$def"
  else
    echo >&2
    echo "build failed, and not in a way --ignore-fakeroot-command fixes." >&2
    echo "Apptainer suggests that flag after any failed %post; ignore the suggestion" >&2
    echo "unless the log says 'libs/fakeroot failed'. The real error is above." >&2
    rm -f "$_log"
    exit 1
  fi
fi
rm -f "$_log"
echo "built $out"
echo "test:    apptainer exec $out <cmd>"
echo "publish: cp $out \$CHPC_LAB/containers/ && chmod 644 \$CHPC_LAB/containers/$(basename "$out") && chpc-stage-containers"
