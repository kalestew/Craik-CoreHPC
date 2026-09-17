#!/bin/bash
#SBATCH --job-name=array_job
#SBATCH --partition=cpu
#SBATCH --array=1-100%20             # 100 tasks, 20 at a time
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --output=logs/%x_%A_%a.out
set -euo pipefail
mkdir -p logs
INPUT=$(sed -n "${SLURM_ARRAY_TASK_ID}p" inputs.txt)   # one path per line
[ -n "$INPUT" ] || { echo "no input for task $SLURM_ARRAY_TASK_ID"; exit 1; }

srun -u python process.py "$INPUT" --out "results/$(basename "$INPUT").out"
