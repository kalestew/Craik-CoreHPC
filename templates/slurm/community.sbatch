#!/bin/bash
# Serial / high-throughput CPU work on the community partition: 96 CPUs and
# 256 GB per node, no InfiniBand (no MPI), 14-day limit, usually no queue.
#SBATCH --job-name=community_job
#SBATCH --partition=community
##SBATCH --qos=cmnt_short           # uncomment AND change partition to community_short for <=1 h tests
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=2-00:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
mkdir -p logs
CHPC_ENV=${CHPC_ENV:-/mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env}
[ -f "$CHPC_ENV" ] && source "$CHPC_ENV"
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

srun -u ./my_program --threads "$SLURM_CPUS_PER_TASK"
