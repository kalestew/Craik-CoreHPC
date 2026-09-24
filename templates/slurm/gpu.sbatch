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
CHPC_ENV=${CHPC_ENV:-/mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env}   # pinned copy (sbatch --export=ALL) or the FAC copy
[ -f "$CHPC_ENV" ] && source "$CHPC_ENV"                               # optional for this job type
module purge
module load CBI miniforge3
source "$_CONDA_ROOT/etc/profile.d/conda.sh"
conda activate myenv

nvidia-smi --query-gpu=name,memory.total --format=csv

# Utilisation trace. Compute nodes have no internet, so there is no Weights &
# Biases or any other live dashboard -- poll locally and read it afterwards.
# Tag with the job id, and background it so it does not block the payload.
nvidia-smi --query-gpu=timestamp,utilization.gpu,memory.used,memory.total \
  --format=csv -l 10 > "logs/gpustat_${SLURM_JOB_ID}.csv" &
_gpustat=$!
trap 'kill $_gpustat 2>/dev/null' EXIT

srun -u python train.py
