#!/bin/bash
#SBATCH --job-name=nvme_job
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=06:00:00
#SBATCH --output=logs/%x_%j.out
# Pattern for I/O-heavy work: stage to node-local NVMe, compute, copy results back.
set -euo pipefail
mkdir -p logs
source "${CHPC_ENV:-/mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env}"   # CHPC_ENV: pinned copy, via sbatch --export=ALL
IN="$CHPC_GROUP_SCRATCH/project/inputs"
OUT="$CHPC_GROUP_SCRATCH/project/results/$SLURM_JOB_ID"
JOBTMP="/tmp/$USER/job_$SLURM_JOB_ID"
mkdir -p "$JOBTMP" "$OUT"
trap 'rm -rf "$JOBTMP"' EXIT

rsync -a "$IN/" "$JOBTMP/in/"
cd "$JOBTMP"
srun -u ./my_program in/ out/
rsync -a out/ "$OUT/"
