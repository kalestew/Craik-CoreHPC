#!/bin/bash
# One job, one process per allocated core, for work with SERIAL BOOKENDS.
#
# Use this instead of an array when a shared step must run BEFORE every unit
# and another must run AFTER all of them. An array would need a barrier between
# those two -- a second job and a second dependency edge, plus a merge step
# that can see every task's output. Here the bookends are just the top and
# bottom of the script.
#
# Use templates/slurm/array.sbatch instead when each unit is independent end to
# end. Failure isolation and per-task restart are worth more than this saves,
# and the scheduler backfills many small jobs more easily than one fat one.
#
# Per-job scheduler overhead is NOT the reason to pick one: measured on
# CoreHPC, a task reaches its first real work about 2 s after Slurm starts it.
#
# Check the program is actually single-threaded before forking N of it. A CPU
# efficiency near 1/N in `chpc-jobstats` cannot tell "single-threaded" from
# "had nothing to do this run".
# Create logs/ BEFORE submitting: Slurm opens --output before this script runs.
#   mkdir -p logs
#   sbatch fork.sbatch
#SBATCH --job-name=fork_job
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16           # = how many units run at once
#SBATCH --mem=16G                    # N x per-process high-water, with headroom
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail

WORKDIR="${WORKDIR:-$PWD/work}"
N="${SLURM_CPUS_PER_TASK:-1}"

# --- prologue: once, before anything is forked -----------------------------
./prepare.sh --shards "$N" --out "$WORKDIR"

# --- fan out ---------------------------------------------------------------
# Each unit gets its OWN directory. Tools that append to a shared output file
# -- FoldX BuildModel is the example that bit us -- interleave rows under
# duplicate names when two of them run in one directory, and the result parses
# cleanly.
PIDS=(); DIRS=()
for D in "$WORKDIR"/shard_*; do
  [ -d "$D" ] || continue
  ( cd "$D" && ./run_one.sh ) > "$D/run.log" 2>&1 &
  PIDS+=("$!"); DIRS+=("$D")
done
[ "${#PIDS[@]}" -gt 0 ] || { echo "no shards to run" >&2; exit 1; }

# Collect EVERY child's status before reacting to any of them, so one failing
# early does not hide the rest. bash 3.2 (macOS) has no `wait -n`; `wait <pid>`
# returns that child's exit status, and `if !` keeps `set -e` from aborting.
FAILED=()
i=0
while [ "$i" -lt "${#PIDS[@]}" ]; do
  if ! wait "${PIDS[$i]}"; then FAILED+=("$(basename "${DIRS[$i]}")"); fi
  i=$((i + 1))
done
if [ "${#FAILED[@]}" -gt 0 ]; then
  for f in "${FAILED[@]}"; do
    echo "--- $f failed; tail of its log ---" >&2
    tail -20 "$WORKDIR/$f/run.log" >&2 || true
  done
  echo "${#FAILED[@]} of ${#PIDS[@]} shard(s) failed" >&2
  exit 1
fi

# --- epilogue: once, after all of them --------------------------------------
# Merge in a step that CHECKS coverage rather than with `cat`. A shard whose
# output is missing is otherwise indistinguishable from a shard that had
# nothing to say, and the short result flows downstream unremarked.
./merge.sh --shard-root "$WORKDIR" --expect "$(cat "$WORKDIR/n_units")"
