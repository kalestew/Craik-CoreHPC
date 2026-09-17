#!/bin/bash
#SBATCH --job-name=container_gpu
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
mkdir -p logs
source "${CHPC_ENV:-/mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env}"   # CHPC_ENV: pinned copy, via sbatch --export=ALL
IMAGE="$CHPC_CONTAINERS/pytorch_24.01.sif"

# chpc.env exports APPTAINER_BIND=/mnt/scratch,/mnt/fac, so no --bind needed here.
srun -u apptainer exec --nv "$IMAGE" python train.py
# or, with a lab wrapper on PATH:  srun -u pytorch python train.py
