# 5. Partitions and hardware

Snapshot from the Access Primer and Technical Overview (July 2026:
14,856 cores, 286 GPUs). Run `sinfo -o "%P %n %e %m %a %c %C %G"` or
`scripts/chpc-discover.sh` for the live picture; `docs/cluster-facts.md`
holds the last capture.

## Partitions

**Our access:** `cpu` and `gpu` only. `pod` needs a per-lab request and
consultation, `large_gpu` is condo-only until fall 2026, and `community`
is planned for academic users from fall 2026. The rest of the table is for
reference.

| Partition | Max walltime | Nodes | CPUs/node | RAM/node | CPU | GPUs/node | Notes |
|-----------|--------------|-------|-----------|----------|-----|-----------|-------|
| `cpu` (default) | 96 h | gcpu2-[03-16] (14) | 336 | 1.5 TB | 2× AMD EPYC 9634 | none | all CPU work incl. MPI; InfiniBand |
| | | gcpu2-[17-48,55] (33) | 512 | 1.5 TB | 2× AMD EPYC 9745 | none | |
| `gpu` | 96 h | ggpu1-[06-12] (7) | 64 | ~380 GB | AMD EPYC 9354P | 2× L40S (48 GB) | single/dual-GPU jobs |
| | | ggpu1-[13-19] (7) | 64 | ~380 GB | AMD EPYC 9335 | 2× RTX PRO 6000 (96 GB) | |
| | | ggpu4-[01-06] (6) | 64 | ~380 GB | AMD EPYC 9354P | 1× H100 NVL (94 GB) | |
| `pod` | 96 h | gcpu3-[07-16] (8) | 208 | 2.0 TB | 2× Xeon Platinum 8470 | 8× H200 SXM (141 GB) | NVLink + NDR InfiniBand; ≥8-GPU jobs; by request; `--account=ucsf_pod --qos=pod` |
| `large_gpu` | 24 h | ggpu3-[17-28] | 240 | 2.0 TB | 2× Xeon Platinum 8580 | 8× H200 | NVLink within chassis only; condo owners now, general backfill from fall 2026 |
| | | ggpu5-[01-03] | 256 | 1.5 TB | 2× AMD EPYC 9555 | 4× H200 NVL | |
| `community` | 336 h (2 weeks) | ccpu1-[01-80] (80) | 64 | ~250 GB | 2× Xeon Gold 6336Y | none | no InfiniBand; HTC / long serial jobs (Wynton-style); academic access planned fall 2026 |
| `community_short` | 1 h | same nodes | | | | | quick tests |

GRES names as SLURM reports them: `nvidia_l40s`, `nvidia_rtx_pro_6000`,
`nvidia_h100_nvl`, `nvidia_h200`, `nvidia_h200_nvl`. Request a specific
model with `--gres=gpu:nvidia_h100_nvl:1` (verify names with
`sinfo -o "%P %G"`), or just `--gres=gpu:1` for any.

## Per-user limits

| Partition | Max nodes | Max jobs | Max resources |
|-----------|-----------|----------|---------------|
| `cpu` | 8 | – | 2048 CPUs total |
| `pod` | 2 | 2 | – |
| `gpu` | – | 4 | 8 GPUs total |
| `community` / `community_short` | 8 | – | 768 CPUs total |

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

Rocky Linux 9 (OpenHPC layout under `/opt/ohpc`), SLURM with fair-share,
environment modules (Lmod-style `module avail`). Apptainer installed on
all nodes.

## Condo model

Labs can buy nodes from the CoreHPC menu (one-time cost, 5-year life). The
node joins its normal partition; the owner gets a priority allocation equal
to the purchased capacity per year (e.g. one H100 node = 8,640 GPU-hours) at
higher priority and longer walltime, and idle cycles are scavenged by
everyone. Pricing: CoreHPC@ucsf.edu; calculator at
<https://fac-calc.ucsf.edu/> (VPN).
