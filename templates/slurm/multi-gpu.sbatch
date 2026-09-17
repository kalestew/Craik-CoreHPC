#!/bin/bash
# Multi-GPU on ONE node in the shared gpu partition (max 2 GPUs per node there).
#SBATCH --job-name=multi_gpu
#SBATCH --partition=gpu
#SBATCH --gres=gpu:2                 # both GPUs of an L40S or RTX PRO 6000 node
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1          # one torchrun launcher
#SBATCH --cpus-per-task=16
#SBATCH --mem=128G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
mkdir -p logs
source "${CHPC_ENV:-/mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env}"   # CHPC_ENV: pinned copy, via sbatch --export=ALL
IMAGE="$CHPC_CONTAINERS/pytorch_24.01.sif"
export OMP_NUM_THREADS=8

srun -u apptainer exec --nv "$IMAGE"   # chpc.env exports APPTAINER_BIND=/mnt/scratch,/mnt/fac \
  torchrun --standalone --nproc_per_node=2 train.py
# Plain conda instead of a container:
#   module load CBI miniforge3; source "$_CONDA_ROOT/etc/profile.d/conda.sh"; conda activate myenv
#   srun -u torchrun --standalone --nproc_per_node=2 train.py
