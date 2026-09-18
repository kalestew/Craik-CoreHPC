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
4. Our FAC share is `/mnt/fac/CX500146_DS1` (5 TB). `source /mnt/fac/CX500146_DS1/chpc.env`
   on the cluster (copy of `lab/chpc.env`).
5. Never compute on the login node or against `/mnt/fac`. Work in
   `/mnt/scratch/user/$USER` or `/mnt/scratch/group/CX500146_DS1` (both exist).
6. Get a shell on a compute node: `salloc -p cpu -c 4 --mem 8G -t 2:00:00`
   (see `docs/03-interactive-jobs.md`).
7. Submit batch work from `templates/slurm/` (see `docs/04-batch-jobs.md`).
8. Run lab software through the tool registry: `chpc-tool list` to see what
   exists, `chpc-tool doctor` to see what actually works, `chpc-tool exec
   <tool> -- <cmd>` to run it (see `tools/README.md`, and
   `docs/07-containers-apptainer.md` for what it is doing underneath).

From any checkout, `source env.sh` (bash or zsh, any path) puts the
`chpc-*.sh` scripts and `lab/bin` on `PATH` and exports the `CHPC_*`
variables. It is also how other repos use this one, see below.

## Using it from another repo (git submodule)

This repo is built to be embedded. Nothing in it depends on where it is
checked out, and per-project settings live in the project, not here.

```bash
# in your project
git submodule add https://git.kalestew.io/ucsf/craik-lab/Craik-CoreHPC.git corehpc
git commit -m "Add CoreHPC guide as submodule"

# in fresh clones of your project (or: git clone --recurse-submodules ...)
git submodule update --init

# take a newer guide
git submodule update --remote corehpc && git commit -am "Bump corehpc"
```

Use the https URL in `.gitmodules` so anyone with read access can clone the
project without a GitLab SSH key, the login node included. That is the
only option there: the login node reaches git.kalestew.io over HTTPS
through the campus proxy, but outbound SSH (port 22) is blocked (verified
2026-09-17). For a private project, create a Deploy Token (project
Settings, Repository, Deploy tokens, scope `read_repository`) and store it
on the login node once:

```bash
git config --global credential.helper 'store --file ~/.git-credentials'   # home is 700; fine for a read-only token
git clone --recurse-submodules https://git.kalestew.io/ucsf/craik-lab/myproject.git   # prompts once, then cached
```

Run git and anything else that needs the internet from a login shell
(`ssh chpc`, or `ssh chpc 'bash -lc "..."'`): the proxy variables live in
the login profile, and a plain `ssh chpc cmd` has none. Projects hosted
in the same `ucsf/craik-lab` group can use the relative URL
`../Craik-CoreHPC.git` instead. To push changes to the guide from inside a
project, point the submodule's origin at the SSH URL:
`git -C corehpc remote set-url origin git@git.kalestew.io:ucsf/craik-lab/Craik-CoreHPC.git`.

Then, on a laptop or on the cluster:

```bash
source corehpc/env.sh                      # any path, bash or zsh
chpc-prime.sh                              # Duo once; scripts/ and lab/bin/ are now on PATH
chpc-stage.sh ./inputs/ "$CHPC_GROUP_SCRATCH/myproj/inputs/"
cp corehpc/templates/slurm/gpu.sbatch jobs/train.sbatch   # copy templates out; edit the copy
sbatch jobs/train.sbatch                   # the job sources the pinned chpc.env through $CHPC_ENV
chpc-discover.sh --out docs/cluster-facts.md              # facts dump into your project, not the submodule
```

`env.sh` exports:

| Variable | Meaning |
|----------|---------|
| `CHPC_REPO` | this checkout, symlinks resolved |
| `CHPC_PROJECT` | the repo that embeds it (git superproject), else `CHPC_REPO` |
| `CHPC_HOST`, `CHPC_BASTION` | SSH aliases, default `chpc` and `chpc-bastion` |
| `CHPC_USER` | campus username: from `ssh -G $CHPC_HOST` off-cluster, `$USER` on it |
| `CHPC_ENV` | path of `lab/chpc.env` in this checkout; `sbatch --export=ALL` carries it into jobs |
| `CHPC_TOOLS` | path of `tools/` in this checkout: the registry `chpc-tool` reads |
| `CHPC_ON_CLUSTER` | `1` on a CoreHPC node, `0` elsewhere |
| `CHPC_*` paths | FAC, group scratch, user scratch, containers (from `lab/chpc.env`) |

Off-cluster only the paths are set. The cache and conda redirections in
`lab/chpc.env` apply on cluster nodes, so sourcing it on a laptop leaves
pip, conda and Hugging Face alone.

Per-project overrides go in `chpc.env.local` at the root of *your* repo
(or a file named by `CHPC_ENV_LOCAL`). It is sourced before `lab/chpc.env`,
so set inputs there, not derived paths. Start from
[`chpc.env.local.example`](chpc.env.local.example):

```bash
cp corehpc/chpc.env.local.example chpc.env.local && $EDITOR chpc.env.local
```

```bash
FAC_SHARE="${FAC_SHARE:-CX500146_DS1}"   # a different FAC share
CHPC_HOST="${CHPC_HOST:-chpc}"           # your SSH alias for the login node
CHPC_USER="${CHPC_USER:-jdoe}"           # campus username, if ssh -G cannot tell
```

Use the `${NAME:-value}` form. The file is sourced as-is, so a plain
`CHPC_USER=jdoe` beats a value you exported in the shell and beats
`sbatch --export` — which is exactly the failure that once had a job quietly
run at a sixth of the sample count it was asked for.

Suggested layout:

```
myproject/
├── corehpc/            this repo, pinned to a commit
├── chpc.env.local      optional overrides (above)
├── jobs/*.sbatch       copied from corehpc/templates/slurm and edited
└── ...
```

Do not edit files inside the submodule from a project; change them here and
bump the pin.

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
| `docs/08-multi-gpu-and-pod.md` | Two-GPU jobs on the `gpu` partition, GPU arrays; POD kept as reference only (not available to us) |
| `docs/09-sge-to-slurm.md` | Wynton (SGE) to SLURM translation table |
| `docs/10-policies-support-troubleshooting.md` | Acceptable-use essentials, downtimes, support channels, common errors |
| `docs/cluster-facts.md` | Live facts captured from the cluster by `scripts/chpc-discover.sh` (last: 2026-09-17) |
| `docs/wiki-sources.md` | Index of the wiki pages this guide is built from |

## Repo layout

```
env.sh                      Source me: CHPC_* variables, scripts on PATH; standalone or submodule
chpc.env.local.example      Copy to <your project>/chpc.env.local: username, share, SSH alias
ssh/config.example          SSH config: bastion, ProxyJump, ControlMaster
scripts/chpc-prime.sh       Open the Duo-authenticated master SSH session
scripts/chpc-discover.sh    Dump live cluster facts to docs/cluster-facts.md (or --out FILE)
scripts/chpc-stage.sh       rsync files to group scratch through the master session
tools/<tool>/tool.conf      THE TOOL REGISTRY: one entry per piece of software
tools/README.md             What an entry must declare, and how to add one
templates/slurm/*.sbatch    Ready-to-edit job scripts (cpu, community, gpu, multi-gpu, array, mpi, container, local-nvme)
templates/apptainer/*.def   Example definition files + build helper
lab/chpc.env                Lab-specific variables (FAC share name, paths); copied to the FAC share
lab/README.md               Layout of our shared FAC directory
lab/bin/chpc-tool           Resolve, run, build and publish anything in the registry
lab/bin/chpc-assets         Install and verify licensed binaries and model weights
lab/bin/*                   Wrapper scripts lab members call from job scripts
```

## The tool registry

Containers, native builds, conda environments and licensed binaries are each
declared once, in [`tools/`](tools/README.md), so that a project gets the whole
catalogue by adding this submodule rather than restating tool paths of its own.

```bash
chpc-tool list                     # every tool, and whether it is actually built
chpc-tool show proteinmpnn         # where one resolves to, and what it exports
chpc-tool doctor                   # what is really on the share, and really working
chpc-tool build proteinmpnn        # login node
chpc-tool publish proteinmpnn      # image, recipe, wrapper, README row, staging
chpc-assets install foldx --from ~/Downloads/foldx   # licensed payloads, by sha256
```

A project consumes it in one line. `IgGase_eng` does this in its `site.conf`:

```bash
eval "$("$REPO/corehpc/lab/bin/chpc-tool" export rosetta proteinmpnn boltz placer)"
```

which sets `ROSETTA_BIN`, `SIF_PROTEINMPNN` and the rest. Most entries are
`STATUS=planned` — described, not yet built. That is deliberate and `list`
shows it; nothing here ever implies an image exists when it does not.

## Key facts to remember

- Login node `chpc-ucsf-login-vm1` is the only node with internet (via proxy).
  Pull containers, clone repos, download models there, never in a job.
- Home is 20 GiB. Put conda envs, Apptainer cache, pip cache on scratch.
- Scratch is purged: files older than 30 days can be deleted, and everything
  is wiped at quarterly maintenance. Persistent data lives on FAC.
- FAC (`/mnt/fac/<share>`) is capacity storage: read inputs and write final
  results there, but do not run I/O-heavy jobs against it.
- Our account is `hpc_core` with QoS for `cpu`, `gpu`, `community` and
  `community_short` (verified with `sacctmgr`). `pod` and `large_gpu` are
  restricted to named accounts; jobs naming them are rejected.
- Our default QoS `hpc_core` is accepted by `cpu`, `gpu` and `community`, but
  `community_short` accepts only `cmnt_short`: add `--qos=cmnt_short` or the
  job pends forever with "QOS not permitted to use this partition" (verified).
- `gpu` allows 8 GPUs and 21 jobs per user. `cpu` allows 2048 CPUs / 8 nodes.
  `community` allows 768 CPUs / 8 nodes with a 14-day walltime and is usually
  nearly empty while `cpu` has a deep queue: put serial and HTC work there.
- Every partition defaults to 1 hour; always pass `--time`. Default memory is
  4 GB per CPU (`cpu`, `community`) and 6 GB per CPU (`gpu`, which also gives
  32 CPUs per GPU by default).
- Support: <https://tiny.ucsf.edu/Gethpc> (ticket), CoreHPC user Slack,
  ARS office hours Tuesdays 10:10–11:00.
