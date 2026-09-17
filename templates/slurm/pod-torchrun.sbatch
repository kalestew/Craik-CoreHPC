#!/bin/bash
#SBATCH --job-name=pod_torchrun
#SBATCH --partition=pod
#SBATCH --account=ucsf_pod
#SBATCH --qos=pod
#SBATCH --nodes=2                    # max 2 per user
#SBATCH --ntasks-per-node=1          # one torchrun launcher per node
#SBATCH --gpus-per-node=8
#SBATCH --cpus-per-task=64
#SBATCH --mem=0
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
mkdir -p logs
source /mnt/fac/${FAC_SHARE:-CX000000_DS0}/chpc/chpc.env
IMAGE="$CHPC_CONTAINERS/pytorch_24.01.sif"

export NCCL_IB_DISABLE=0
export NCCL_NET_GDR_LEVEL=2
export NCCL_SOCKET_IFNAME=^lo,docker,virbr
export NCCL_DEBUG=INFO               # WARN once verified (look for NET/IB)
export OMP_NUM_THREADS=8

MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n1)
MASTER_PORT=29500

srun -u apptainer exec --nv --bind /mnt/scratch,/mnt/fac "$IMAGE" \
  torchrun --nnodes="$SLURM_JOB_NUM_NODES" --nproc_per_node=8 \
           --rdzv_backend=c10d --rdzv_endpoint="${MASTER_ADDR}:${MASTER_PORT}" \
           train.py
