#!/bin/bash
#SBATCH --job-name=cpu_job
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
mkdir -p logs
CHPC_ENV=${CHPC_ENV:-/mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env}   # pinned copy (sbatch --export=ALL) or the FAC copy
[ -f "$CHPC_ENV" ] && source "$CHPC_ENV"                               # optional for this job type
module purge
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

srun -u ./my_program --threads "$SLURM_CPUS_PER_TASK"
