#!/bin/bash
# For an image of your own that is NOT in the registry. For a registry tool
# use tool-gpu.sbatch, which goes through chpc-tool exec (exports, GPU guard).
#SBATCH --job-name=container_gpu
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1                 # any GPU; name a model (gpu:nvidia_l40s:1) if the image predates CUDA 12.8 -- doc 05
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
