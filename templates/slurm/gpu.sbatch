#!/bin/bash
#SBATCH --job-name=gpu_job
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1                 # or gpu:nvidia_h100_nvl:1 / gpu:nvidia_l40s:2
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=08:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
mkdir -p logs
source /mnt/fac/${FAC_SHARE:-CX000000_DS0}/chpc/chpc.env 2>/dev/null || true
module purge
module load CBI miniforge3
source "$_CONDA_ROOT/etc/profile.d/conda.sh"
conda activate myenv

nvidia-smi --query-gpu=name,memory.total --format=csv
srun -u python train.py
