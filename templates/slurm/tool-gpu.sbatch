#!/bin/bash
# One registry tool, as a batch job. Copy it out and edit the four EDIT lines.
#
#   cp corehpc/templates/slurm/tool-gpu.sbatch jobs/boltz_p1.sbatch   # or $CHPC_LAB/slurm/tool-gpu.sbatch
#   mkdir -p logs        # BEFORE sbatch: Slurm opens --output before this script runs
#   sbatch jobs/boltz_p1.sbatch
#
# `chpc-tool exec` does what a raw `apptainer exec` would not: picks the image
# (scratch mirror, else FAC), adds --nv, exports the tool's weight and cache
# paths into the container, and refuses a GPU the image has no kernels for.
# The method, the `eval` idiom and the GPU table: tools/README.md.
#
# CPU-only tool (foldseek, mmseqs2, hhsuite, dockq, pymol; rosetta and foldx
# are native): --partition=cpu, delete the --gres line and the nvidia-smi line.
#SBATCH --job-name=tool_gpu
#SBATCH --partition=gpu
#SBATCH --gres=gpu:nvidia_l40s:1     # EDIT 1. Safe for every tool. gpu:1 (any node) only for the tools tools/README.md "Which GPU" lists as any
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
CHPC_ENV="${CHPC_ENV:-/mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env}"    # the checkout's copy via sbatch --export=ALL, else the share's
source "$CHPC_ENV"                                                  # APPTAINER_BIND, CHPC_* paths, $CHPC_LAB/bin on PATH
# chpc-tool lives beside whichever chpc.env was sourced: <checkout>/lab/bin or
# <share>/bin. Resolved by path rather than trusted to PATH, because a job
# inherits the submitting shell's PATH and a shell that never sourced env.sh
# has no chpc-tool on it. Verified 2026-09-25 (job 1997378, "command not found").
CHPC_TOOL="$(dirname "$CHPC_ENV")/bin/chpc-tool"
[ -x "$CHPC_TOOL" ] || CHPC_TOOL=$(command -v chpc-tool) || { echo "no chpc-tool beside $CHPC_ENV and none on PATH" >&2; exit 1; }

TOOL=boltz                                                          # EDIT 2. A name from `chpc-tool list`
WORKDIR="${WORKDIR:-$CHPC_USER_SCRATCH/$TOOL/$SLURM_JOB_NAME}"      # EDIT 3. Stage inputs here before submitting; same path inside the container
OUT="out_$SLURM_JOB_ID"                                             # one output dir per run, so a resubmit never overwrites

_exports=$("$CHPC_TOOL" export "$TOOL") || exit 1                   # $BOLTZ_CACHE and friends in THIS shell, for the command line below;
eval "$_exports"                                                    # a failed export stops the job here, not at an empty --cache
nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader       # which GPU this job got, at the top of the log
cd "$WORKDIR"

# EDIT 4. After `--`: the tool's own program and arguments, as the entry's
# README "Run it" gives them. Never omit the program.
srun -u "$CHPC_TOOL" exec "$TOOL" -- boltz predict in.yaml \
    --cache "$BOLTZ_CACHE" --out_dir "$OUT" --no_kernels --seed 1

echo "done: $WORKDIR/$OUT"
