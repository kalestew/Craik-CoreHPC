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
source /mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env
IMAGE="$CHPC_CONTAINERS/pytorch_24.01.sif"

srun -u apptainer exec --nv --bind /mnt/scratch,/mnt/fac "$IMAGE" python train.py
# or, with a lab wrapper on PATH:  srun -u pytorch python train.py
