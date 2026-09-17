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
source /mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env 2>/dev/null || true
module purge
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

srun -u ./my_program --threads "$SLURM_CPUS_PER_TASK"
