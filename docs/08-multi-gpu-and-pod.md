# 8. Multi-GPU, multi-node, and the POD

## Which partition

| Need | Partition | Request |
|------|-----------|---------|
| 1–2 GPUs, one node | `gpu` | `-p gpu --gres=gpu:2` (L40S / RTX PRO 6000 nodes have 2, H100 NVL nodes have 1) |
| 4–8 GPUs with NVLink, one node | `large_gpu` | `-p large_gpu --gres=gpu:8`; 24 h max; condo owners only until fall 2026 |
| 8+ GPUs, multi-node, NVLink + InfiniBand | `pod` | `-p pod --account=ucsf_pod --qos=pod --nodes=N --gpus-per-node=8`; max 2 nodes / 2 jobs per user |

POD access is by request: open a ticket at <https://tiny.ucsf.edu/Gethpc>;
an HPC engineer will do a short consultation to confirm the code actually
scales across GPUs before enabling the `ucsf_pod` account.

## Canonical multi-node PyTorch job (torchrun)

`templates/slurm/pod-torchrun.sbatch` is the full file. The core:

```bash
#SBATCH --partition=pod
#SBATCH --account=ucsf_pod
#SBATCH --qos=pod
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1          # one torchrun launcher per node
#SBATCH --gpus-per-node=8
#SBATCH --cpus-per-task=64
#SBATCH --time=12:00:00

export NCCL_IB_DISABLE=0             # use InfiniBand
export NCCL_NET_GDR_LEVEL=2          # GPUDirect RDMA (required for H200 peak perf)
export NCCL_SOCKET_IFNAME=^lo,docker,virbr
export NCCL_DEBUG=INFO               # WARN once it works; look for "NET/IB"

MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n1)
MASTER_PORT=29500

srun torchrun \
  --nnodes=$SLURM_JOB_NUM_NODES --nproc_per_node=8 \
  --rdzv_backend=c10d --rdzv_endpoint=${MASTER_ADDR}:${MASTER_PORT} \
  train.py
```

Why this shape: `srun` wires PMI and places one launcher per node;
`torchrun` assigns ranks and sets `RANK`, `WORLD_SIZE`, `LOCAL_RANK`; NCCL
picks InfiniBand automatically. Do not use `mpirun` unless told to.

Note the wiki's own examples use `--ntasks-per-node=4` with
`--nproc_per_node=$SLURM_GPUS_PER_NODE`, which launches torchrun several
times per node. One task per node with `--nproc_per_node=8` is the standard
torchrun pattern; use whichever your framework documents, but not both.

Alternative without torchrun (one task per GPU, PyTorch reads SLURM vars):

```bash
#SBATCH --ntasks-per-node=8
#SBATCH --gpus-per-task=1
srun python train.py       # uses RANK/WORLD_SIZE/LOCAL_RANK exported by srun
```

DeepSpeed: `srun deepspeed --num_nodes $SLURM_JOB_NUM_NODES --num_gpus 8 train.py --deepspeed --deepspeed_config ds_config.json`.

## Inside a container

```bash
srun apptainer exec --nv pytorch.sif torchrun --nnodes=$SLURM_JOB_NUM_NODES --nproc_per_node=8 \
     --rdzv_backend=c10d --rdzv_endpoint=${MASTER_ADDR}:${MASTER_PORT} train.py
```

`--nv` exposes the GPUs; InfiniBand devices are passed through by the
admins' Apptainer config. NGC images (`nvcr.io/nvidia/pytorch:<tag>-py3`)
already contain matching CUDA + NCCL + PyTorch and are the low-risk choice;
pull them on the login node (doc 07).

## Sanity checks before a big run

```bash
# in an interactive POD/GPU allocation:
nvidia-smi ; nvidia-smi topo -m            # NV links between GPUs, PIX/PHB to NIC
ibstat ; ls /sys/class/infiniband          # ports ACTIVE
srun python ib_debug.py                    # templates/slurm/ib_debug.py: all-reduce across ranks
```

Expected in NCCL logs: `NET/IB` (not `NET/Socket`). Expected all-reduce
bandwidth on NDR is ~40–45 GB/s per node.

## Check a running job really uses its GPUs

```bash
srun --jobid=<JOBID> --nodelist=<node> --pty bash
nvidia-smi --query-compute-apps=pid,process_name,gpu_name,gpu_uuid,used_memory --format=csv | sort -k5
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| NCCL logs `NET/Socket`, low bandwidth | `NCCL_IB_DISABLE=0`; `NCCL_SOCKET_IFNAME=^lo,docker`; verify IB devices visible in the container |
| Hang after `init_process_group` | use `srun` not `mpirun`; check `MASTER_ADDR`; every rank must reach the rendezvous port |
| Multi-node slower than single node | `NCCL_NET_GDR_LEVEL=2`; check GPU↔NIC affinity with `nvidia-smi topo -m` |
| `--account=ucsf_pod` rejected | you are not yet enabled for the POD; open a ticket |
| CUDA OOM on 8 GPUs but fine on 1 | per-GPU memory is the same; reduce batch per GPU, use gradient checkpointing |
