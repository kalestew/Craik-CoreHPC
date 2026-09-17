# 8. Multi-GPU jobs (and why we do not use the POD)

Our lab has regular access: `cpu`, `community`/`community_short`, and the
shared `gpu` partition. The `pod` partition (8× H200 nodes, InfiniBand) is by request
only after a consultation, and `large_gpu` is condo-only until fall 2026.
Neither is enabled for us; a job with `--partition=pod` or
`--account=ucsf_pod` will be rejected. The POD notes at the bottom are
kept for reference in case that changes.

## What we can use

| Node | GPUs per node | GPU memory | Per-user limit |
|------|---------------|------------|----------------|
| ggpu1-[06-12] | 2× L40S | 48 GB each | 21 running jobs and 8 GPUs total in `gpu` |
| ggpu1-[13-19] | 2× RTX PRO 6000 | 96 GB each | |
| ggpu4-[01-06] | 1× H100 NVL | 94 GB | |

So the realistic shapes are: one GPU, or two GPUs on one node. Multi-node
GPU jobs are possible in principle (`--nodes=2 --gres=gpu:2`) but the gpu
nodes have no NVLink between chassis and the workload must scale over
InfiniBand; for a two-node, four-GPU job that is rarely worth it. Prefer
one node.

Pick the card that fits the model: `--gres=gpu:nvidia_rtx_pro_6000:1` for
the most memory per GPU, `--gres=gpu:nvidia_h100_nvl:1` for fastest
compute, `--gres=gpu:nvidia_l40s:2` when two cards matter more than one
big one. Verify names with `sinfo -o "%P %G"` (also in `docs/cluster-facts.md`).

## Two GPUs, one node (data parallel)

`templates/slurm/multi-gpu.sbatch` is the full file. The core:

```bash
#SBATCH --partition=gpu
#SBATCH --gres=gpu:2
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
srun torchrun --standalone --nproc_per_node=2 train.py
```

`--standalone` runs the rendezvous locally, so no `MASTER_ADDR` plumbing.
Inside `train.py` use `torch.distributed.init_process_group("nccl")`,
`DistributedDataParallel`, and `LOCAL_RANK` for `cuda.set_device`. NCCL
uses NVLink/PCIe on a single node; no InfiniBand variables are needed.

Alternative without torchrun (one task per GPU; PyTorch reads the SLURM
variables that `srun` exports):

```bash
#SBATCH --ntasks-per-node=2
#SBATCH --gpus-per-task=1
srun python train.py
```

Frameworks with their own launcher (Lightning, Accelerate, DeepSpeed,
JAX) usually detect two visible GPUs automatically when run under a single
task with `--gres=gpu:2`.

## Many independent GPU jobs instead

For hyperparameter sweeps or per-sample inference, one GPU per array task
is simpler and schedules faster than one big job:

```bash
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --array=0-31%8          # %8 keeps us inside the 8-GPU limit
srun python run.py --config configs/${SLURM_ARRAY_TASK_ID}.yml
```

## Check that a job uses its GPUs

```bash
srun --jobid=<JOBID> --nodelist=<node> --pty bash
nvidia-smi
nvidia-smi --query-compute-apps=pid,process_name,gpu_name,gpu_uuid,used_memory --format=csv | sort -k5
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Invalid account or account/partition combination` | you used `pod`/`ucsf_pod`; we do not have it |
| Only one GPU visible with `--gres=gpu:2` | `echo $CUDA_VISIBLE_DEVICES`; make sure the script does not pin device 0; with `--ntasks-per-node=2 --gpus-per-task=1` each task sees one GPU by design |
| CUDA OOM on 2 GPUs but not 1 | per-GPU memory is unchanged; reduce batch per GPU or use a 96 GB RTX PRO 6000 |
| Hang in `init_process_group` | with torchrun use `--standalone`; without it every rank needs `MASTER_ADDR`/`MASTER_PORT` |
| Pending `(QOSMaxGRESPerUser)` or similar | 8 GPUs / 21 jobs per user across all your `gpu` jobs |

## Reference: the POD (not available to us)

For completeness, the wiki's canonical multi-node pattern, should the lab
ever be granted POD access (ticket at <https://tiny.ucsf.edu/Gethpc>, then
an engineer consultation, then `--account=ucsf_pod --qos=pod`, max 2 nodes
and 2 jobs per user):

```bash
#SBATCH --partition=pod --account=ucsf_pod --qos=pod
#SBATCH --nodes=2 --ntasks-per-node=1 --gpus-per-node=8
export NCCL_IB_DISABLE=0 NCCL_NET_GDR_LEVEL=2 NCCL_SOCKET_IFNAME=^lo,docker,virbr NCCL_DEBUG=INFO
MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n1)
srun torchrun --nnodes=$SLURM_JOB_NUM_NODES --nproc_per_node=8 \
     --rdzv_backend=c10d --rdzv_endpoint=${MASTER_ADDR}:29500 train.py
```

Expect `NET/IB` in NCCL logs (not `NET/Socket`); `templates/slurm/ib_debug.py`
is the wiki's all-reduce sanity check.
