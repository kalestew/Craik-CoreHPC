"""NCCL/InfiniBand sanity check. Launch with one task per GPU:
   srun --ntasks-per-node=8 --gpus-per-task=1 python ib_debug.py
Expect: NCCL logs mention NET/IB, and rank 0 prints Result == Expected."""
import os, socket
import torch, torch.distributed as dist

rank = int(os.environ.get("RANK", os.environ.get("SLURM_PROCID", 0)))
world = int(os.environ.get("WORLD_SIZE", os.environ.get("SLURM_NTASKS", 1)))
local = int(os.environ.get("LOCAL_RANK", os.environ.get("SLURM_LOCALID", 0)))
os.environ.setdefault("RANK", str(rank)); os.environ.setdefault("WORLD_SIZE", str(world))
os.environ.setdefault("MASTER_ADDR", os.environ.get("SLURM_LAUNCH_NODE_IPADDR", "127.0.0.1"))
os.environ.setdefault("MASTER_PORT", "29500")
torch.cuda.set_device(local)
print(f"[{rank}/{world}] {socket.gethostname()} local={local} gpu={torch.cuda.get_device_name(local)}", flush=True)
dist.init_process_group(backend="nccl")
t = torch.tensor([rank], device="cuda")
dist.all_reduce(t)
if rank == 0:
    print(f"All-reduce Result={t.item()} Expected={world*(world-1)//2}", flush=True)
dist.barrier(); dist.destroy_process_group()
