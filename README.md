# UCSF CoreHPC — Craik Lab Field Guide

Everything the lab needs to use the UCSF CoreHPC cluster: getting in, moving
data, running interactive and batch SLURM jobs, using the right storage, and
packaging software as Apptainer containers that the whole lab can share from
our FAC storage.

Sources: the CoreHPC Confluence wiki (see `docs/wiki-sources.md`, captured
2026-09-16) plus our own working notes. Where the wiki is thin or generic
we say so and give the CoreHPC-specific version.

## Quick start (new lab member)

1. Get an account: your PI submits a request at <https://tiny.ucsf.edu/Gethpc>.
   You need a UCSF campus account, Duo enrolled, and the lab FAC share.
2. Connect to the UCSF VPN (recommended even on campus Wi-Fi).
3. Install `ssh/config.example` into `~/.ssh/config`, create a key, and follow
   `docs/01-access-and-ssh.md`. After that, `ssh chpc` gets you to the login
   node with one Duo push per session.
4. Fill in `lab/chpc.env` (FAC share name) and `source` it on the cluster.
5. Never compute on the login node or on `/mnt/fac`. Work in
   `/mnt/scratch/user/$USER` or `/mnt/scratch/group/<FAC_SHARE>`.
6. Get a shell on a compute node: `salloc -p cpu -c 4 --mem 8G -t 2:00:00`
   (see `docs/03-interactive-jobs.md`).
7. Submit batch work from `templates/slurm/` (see `docs/04-batch-jobs.md`).
8. Run lab software from shared containers in `$CHPC_LAB/containers`
   (see `docs/07-containers-apptainer.md` and `lab/README.md`).

## Contents

| Doc | What it covers |
|-----|----------------|
| `docs/01-access-and-ssh.md` | Accounts, VPN, Duo, bastion + ProxyJump, passwordless SSH, ControlMaster, Open OnDemand, VS Code |
| `docs/02-storage-and-data.md` | Home, scratch (user/group), FAC, local NVMe, quotas, purge policy, transfers (rsync, Globus), internet access |
| `docs/03-interactive-jobs.md` | `salloc` / `srun --pty`, GPU shells, tmux/screen, attaching to a running job |
| `docs/04-batch-jobs.md` | `sbatch` anatomy, resource requests, arrays, dependencies, GPUs, MPI, monitoring, cancelling, `sacct` |
| `docs/05-partitions-and-hardware.md` | Every partition, node type, GPU, time limit and per-user limit |
| `docs/06-software-modules-conda.md` | Environment modules, the CBI collection, Miniforge/conda on scratch, Jupyter kernels |
| `docs/07-containers-apptainer.md` | Building `.sif` images (login node, or Docker on a Mac), GPU containers, bind mounts, sharing across the lab |
| `docs/08-multi-gpu-and-pod.md` | Multi-GPU / multi-node jobs, the POD partition, NCCL + InfiniBand, torchrun |
| `docs/09-sge-to-slurm.md` | Wynton (SGE) to SLURM translation table |
| `docs/10-policies-support-troubleshooting.md` | Acceptable-use essentials, downtimes, support channels, common errors |
| `docs/cluster-facts.md` | Live facts captured from the cluster by `scripts/chpc-discover.sh` |
| `docs/wiki-sources.md` | Index of the wiki pages this guide is built from |

## Repo layout

```
ssh/config.example          SSH config: bastion, ProxyJump, ControlMaster
scripts/chpc-prime.sh       Open the Duo-authenticated master SSH session
scripts/chpc-discover.sh    Dump live cluster facts to docs/cluster-facts.md
scripts/chpc-stage.sh       rsync files to group scratch through the master session
templates/slurm/*.sbatch    Ready-to-edit job scripts (cpu, gpu, array, mpi, container, pod)
templates/apptainer/*.def   Example definition files + build helper
lab/chpc.env                Lab-specific variables (FAC share name, paths)
lab/README.md               Layout of our shared FAC directory
lab/bin/*                   Wrapper scripts lab members call from job scripts
```

## Key facts to remember

- Login node `chpc-ucsf-login-vm1` is the only node with internet (via proxy).
  Pull containers, clone repos, download models there, never in a job.
- Home is 20 GiB. Put conda envs, Apptainer cache, pip cache on scratch.
- Scratch is purged: files older than 30 days can be deleted, and everything
  is wiped at quarterly maintenance. Persistent data lives on FAC.
- FAC (`/mnt/fac/<share>`) is capacity storage: read inputs and write final
  results there, but do not run I/O-heavy jobs against it.
- Default partition is `cpu`. GPUs need `-p gpu --gres=gpu:1`. The POD needs
  `--account=ucsf_pod --qos=pod` and prior approval.
- Support: <https://tiny.ucsf.edu/Gethpc> (ticket), CoreHPC user Slack,
  ARS office hours Tuesdays 10:10–11:00.
