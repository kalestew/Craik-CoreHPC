# 5. Partitions and hardware

Snapshot from the Access Primer and Technical Overview (July 2026:
14,856 cores, 286 GPUs). Run `sinfo -o "%P %n %e %m %a %c %C %G"` or
`scripts/chpc-discover.sh` for the live picture; `docs/cluster-facts.md`
holds the last capture.

## Partitions

**Our access (verified 2026-09-17 with `sacctmgr show assoc`):** account
`hpc_core`, QoS `cpu`, `gpu`, `cmnt` (community) and `cmnt_short`. So we
can submit to `cpu`, `gpu`, `community` and `community_short`. `pod` is
limited to accounts `ucsf_pod`/`ucsf_high_pod` and `large_gpu` to four
named lab accounts; both reject our jobs.

| Partition | Max walltime | Nodes | CPUs/node | RAM/node | CPU | GPUs/node | Notes |
|-----------|--------------|-------|-----------|----------|-----|-----------|-------|
| `cpu` (default) | 96 h | gcpu2-[03-16] (14) | 336 | 1.5 TB | 2× AMD EPYC 9634 | none | all CPU work incl. MPI; InfiniBand; deep queue (≈1000 pending vs 250 running at capture) |
| | | gcpu2-[17-48,55] (33) | 512 | 1.5 TB | 2× AMD EPYC 9745 | none | |
| `gpu` | 96 h | ggpu1-[06-12] (7) | 64 | ~380 GB | AMD EPYC 9354P | 2× L40S (48 GB) | single/dual-GPU jobs |
| | | ggpu1-[13-19] (7) | 128 | ~380 GB | AMD EPYC 9335 | 2× RTX PRO 6000 (96 GB) | |
| | | ggpu4-[01-06] (6) | 64 | ~380 GB | AMD EPYC 9354P | 1× H100 NVL (94 GB) | |
| `pod` | 96 h | gcpu3-[07-16] (8) | 208 | 2.0 TB | 2× Xeon Platinum 8470 | 8× H200 SXM (141 GB) | NVLink + NDR InfiniBand; ≥8-GPU jobs; by request; `--account=ucsf_pod --qos=pod` |
| `large_gpu` | 24 h | ggpu3-[17-29] (13) | 208+ | 2.0 TB | 2× Xeon Platinum 8580 | 8× H200 | not ours; NVLink within chassis only |
| | | ggpu5-[01-03] | 256 | 1.5 TB | 2× AMD EPYC 9555 | 4× H200 NVL | |
| `community` | 336 h (14 d) | ccpu1-[01-80] (80) | 96 | 256 GB | 2× Xeon Gold 6336Y | none | ours; no InfiniBand; HTC / long serial jobs; almost always idle (3 running at capture) |
| `community_short` | 1 h | same nodes | | | | | ours; quick tests; 1 node per user |

GRES names as SLURM reports them: `nvidia_l40s`, `nvidia_rtx_pro_6000`,
`nvidia_h100_nvl`, `nvidia_h200`, `nvidia_h200_nvl`. Request a specific
model with `--gres=gpu:nvidia_h100_nvl:1` (verify names with
`sinfo -o "%P %G"`), or just `--gres=gpu:1` for any.

## The `gpu` partition is three architectures, and `--gres=gpu:1` picks one at random

This matters far more than a performance footnote, because the oldest CUDA a
tool supports decides which of these nodes it can run on at all.

| Nodes | GPU | Compute capability | Oldest CUDA that emits kernels for it |
|---|---|---|---|
| ggpu1-[06-12] | L40S | `sm_89` (Ada) | 11.8 |
| ggpu1-[13-19] | RTX PRO 6000 | `sm_120` (Blackwell) | **12.8** |
| ggpu4-[01-06] | H100 NVL | `sm_90` (Hopper) | 11.8 |
| ggpu3-*, ggpu5-* | H200 | `sm_90` (Hopper) | 11.8 |

A CUDA binary carries kernels only for the architectures it was compiled for.
Newer *drivers* run older CUDA fine — that direction is backward compatible, and
this cluster's 595.71.05 runs cu121 binaries without complaint — but an older
*toolkit* cannot produce code for a GPU that did not exist when it shipped. So a
tool pinned below CUDA 12.8 works on every node here **except** the seven
Blackwell ones, where it dies at the first kernel launch with

```
CUDA error: no kernel image is available for execution on the device
```

which reads like a broken installation and is a scheduling accident. It is also
intermittent in the worst way: `--gres=gpu:1` matches all of `gpu`, so the same
script passes on Monday and fails on Tuesday depending on what was free.

Several widely used tools are pinned below 12.8 and cannot be bumped, because
the pin comes from a dependency rather than preference — DGL publishes no wheels
past torch 2.4, and `chai_lab` requires `torch<2.7`. Those entries in
`tools/` carry a `GPUArch` label and say so in their README. When a tool is one
of them, name the GPU:

```bash
#SBATCH --gres=gpu:nvidia_l40s:1        # or nvidia_h100_nvl
```

Only `nvidia_l40s` and `nvidia_h100_nvl` are real options for us — the H200
nodes are in `large_gpu` and `pod`, which our QoS refuses with `Job's QOS not
permitted` (verified 2026-09-17). That still leaves 14 L40S plus 6 H100 NVL
against 14 Blackwell, so avoiding sm_120 costs roughly half the queue rather
than all of it. `--gres=gpu:1 --exclude=ggpu1-[13-19]` is the other way to say
it and keeps both models in play, at the cost of hardcoding node names.

Naming a model costs queue breadth, so do it only where it is needed. Anything
built on a CUDA 12.8+ base — which is everything in `tools/` on a
`pytorch/pytorch:*-cuda13.2-*` base — should keep the unrestricted
`--gres=gpu:1`. Verified on CoreHPC 2026-09-17: a cu13.2 image reports `sm_89`
on an L40S and runs there.

## Per-user limits (live QoS, which differ from the wiki table)

| Partition (QoS) | Max nodes | Max running jobs | Max resources |
|-----------------|-----------|------------------|---------------|
| `cpu` (`cpu`) | 8 | – | 2048 CPUs total |
| `gpu` (`gpu`) | – | 21 | 8 GPUs total (any mix of models) |
| `community` (`cmnt`) | 8 | – | 768 CPUs total |
| `community_short` (`cmnt_short`) | 1 | – | – |
| `pod` (`pod`) | 2 | 2 | not ours |

QoS: our default is `hpc_core`, which `cpu`, `gpu` and `community` accept.
`community_short` accepts only `cmnt_short`, so pass `--qos=cmnt_short`
there. Passing `--qos=cpu`, `--qos=gpu` or `--qos=cmnt` is optional on the
other partitions (they are also allowed for us).

Scheduler defaults that matter: `DefaultTime=01:00:00` on every partition,
`DefMemPerCPU` 4096 MB on `cpu`/`community` and 6144 MB on `gpu`,
`DefCpuPerGPU=32` on `gpu`. Max array size 5000. Backfill scheduler with
multifactor priority.

There is no compute recharge today and no hard allocation; priority is
fair-share (`sprio -j <jobid>` shows the breakdown). Extra priority or
walltime for time-critical work can be requested through the governance
committee via a ticket.

## Local NVMe (`/tmp`) per node type

| Node type | Local scratch |
|-----------|---------------|
| cpu | ~2 TB NVMe |
| gpu | ~6 TB NVMe |
| large_gpu | 6 TB (4-GPU) / 12 TB (8-GPU) NVMe |
| pod | ~12 TB NVMe |
| community | ~1 TB SAS SSD |

## Networks

- 100/200 Gb Ethernet: user traffic, FAC storage, Globus, OnDemand.
- NDR InfiniBand: MPI and VAST scratch/home, on every partition except
  `community`.
- 1 Gb management network: not user-visible.

## OS and scheduler

Rocky Linux 9.8 (CIQ), kernel 5.14, OpenHPC layout under `/opt/ohpc`,
SLURM 24.11.5 with fair-share, Lmod modules. Apptainer 1.5.2 on all nodes
(`singularity` is a symlink to it).

## Condo model

Labs can buy nodes from the CoreHPC menu (one-time cost, 5-year life). The
node joins its normal partition; the owner gets a priority allocation equal
to the purchased capacity per year (e.g. one H100 node = 8,640 GPU-hours) at
higher priority and longer walltime, and idle cycles are scavenged by
everyone. Pricing: CoreHPC@ucsf.edu; calculator at
<https://fac-calc.ucsf.edu/> (VPN).
