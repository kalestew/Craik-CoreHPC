# UCSF CoreHPC — Craik Lab Field Guide

How the Craik Lab uses the UCSF CoreHPC cluster. Three things live here:

- A tool registry, `tools/`: one entry per piece of software the lab runs
  (Boltz-2, ColabFold, RFdiffusion, Rosetta and 29 more) and the `chpc-tool`
  command that runs any of them from the lab's shared FAC storage, with the
  weights, bind mounts and GPU constraints already sorted out.
- Slurm job templates, `templates/slurm/`, and the lab environment file they
  source, `lab/chpc.env`.
- A field guide to the cluster itself, `docs/`: access, storage, jobs,
  partitions, containers.

Other lab projects embed this repo as a git submodule at `corehpc/` and read
the registry from it; see "Using it from a project" below.

## First hour on CoreHPC

1. Get an account: your PI submits <https://tiny.ucsf.edu/Gethpc>. You need a
   UCSF campus account, Duo, and membership of the lab FAC share
   (`sec_fac_cx500146_ds1`).
2. Connect to the UCSF VPN, even on campus Wi-Fi (`docs/01-access-and-ssh.md`
   has the GlobalProtect caveats).
3. Install `ssh/config.example` as `~/.ssh/config`, create a key, follow
   `docs/01-access-and-ssh.md`. After that `ssh chpc` reaches the login node
   with one Duo push per session.
4. On the login node, once, add this line to `~/.bashrc` and run it:

   ```bash
   [ -f /mnt/fac/CX500146_DS1/chpc.env ] && source /mnt/fac/CX500146_DS1/chpc.env
   ```

   It puts `chpc-tool` on `PATH` with Tab completion, moves the Apptainer,
   pip and conda caches off your 20 GiB home, and makes scratch and FAC
   visible inside containers.
5. Work in `/mnt/scratch/user/$USER` (purged after 30 days). Final results
   go to `/mnt/fac/CX500146_DS1/results/<project>/`. Never compute on the
   login node, and never run heavy I/O against `/mnt/fac`.
6. Get a compute node. Every partition defaults to a one-hour limit, so
   always pass `-t`:

   ```bash
   salloc -p cpu -c 4 --mem 8G -t 2:00:00                                        # CPU
   srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l  # GPU, safe for every tool
   ```

7. On that node, `chpc-tool doctor`: one row per tool, OK or FAIL, and where
   it lives. That is the check that steps 4 to 6 worked.

## Run a tool

On a compute node, after step 4 above:

```bash
chpc-tool list                              # every tool; STATUS verified = it has run on a compute node here
chpc-tool doctor boltz                      # image and weights really present?
chpc-tool show boltz                        # image path, GPU yes/no, the variables it exports, and its note
chpc-tool exec boltz -- boltz --help        # run a program inside it. Always `-- <program> <args>`
chpc-tool exec boltz -- bash                # a shell inside it
```

Put inputs on `/mnt/scratch/user/$USER`; the same path is valid inside the
container, so a command that works at the shell works unchanged through
`chpc-tool exec`. Weights are already on the share and `exec` hands the tool
their location.

For a full example on your own input, the one idiom you need before writing a
tool's variables on a command line (`eval "$(chpc-tool export boltz)"`), which
GPU model to ask for (seven tools cannot use the Blackwell nodes), and the
batch template: [`tools/README.md`, "Run a tool on your
inputs"](tools/README.md#run-a-tool-on-your-inputs).

## Where to go next

- Run the lab's software on your inputs, interactively or as a job:
  [`tools/README.md`](tools/README.md).
- One tool's run block, inputs, traps and build record: `tools/<tool>/README.md`.
- Batch jobs: `docs/04-batch-jobs.md`; ready-to-copy scripts in
  `templates/slurm/` (`tool-gpu.sbatch` is the one for registry tools).
- Storage, quotas, moving data in and out: `docs/02-storage-and-data.md`.
- Partitions, GPU models, why `--gres=gpu:1` is a gamble:
  `docs/05-partitions-and-hardware.md`.
- What `chpc-tool exec` does underneath, and building images:
  `docs/07-containers-apptainer.md`.
- The shared FAC directory and publishing to it (maintainers):
  [`lab/README.md`](lab/README.md).

## Using it from a project (git submodule)

This repo is built to be embedded. Nothing in it depends on where it is
checked out, and per-project settings live in the project, not here. From
any checkout, `source env.sh` (bash or zsh, any path) puts the `chpc-*.sh`
scripts and `lab/bin` on `PATH` and exports the `CHPC_*` variables.

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
chpc-globus.sh push ./inputs "$CHPC_LAB/myproj/inputs"   # Globus; two legs to FAC, one to scratch
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

A project reads the registry in one line. `IgGase_eng` does this in its
`site.conf`:

```bash
eval "$("$REPO/corehpc/lab/bin/chpc-tool" export rosetta proteinmpnn boltz placer)"
```

which sets `ROSETTA_BIN`, `SIF_PROTEINMPNN`, `BOLTZ_CACHE` and the rest, by
explicit path out of the pinned submodule, so the definitions are the ones the
project's commit says.

## Contents

Sources: the CoreHPC Confluence wiki (see `docs/wiki-sources.md`, captured
2026-09-16) plus our own working notes. Where the wiki is thin or generic we
say so and give the CoreHPC-specific version.

| Doc | What it covers |
|-----|----------------|
| `tools/README.md` | Run any registry tool on your inputs, the `chpc-tool` CLI, which GPU to ask for, adding a tool |
| `lab/README.md` | The shared FAC directory: layout, bootstrap, keeping the share's copy current, publishing |
| `templates/slurm/` | Ready-to-copy job scripts; `tool-gpu.sbatch` for a registry tool |
| `docs/01-access-and-ssh.md` | Accounts, VPN, Duo, bastion + ProxyJump, passwordless SSH, ControlMaster, Open OnDemand, VS Code |
| `docs/02-storage-and-data.md` | Home, scratch (user/group), FAC, local NVMe, quotas, purge policy, approved transfer paths (Globus, FAC share, OnDemand), internet access |
| `docs/03-interactive-jobs.md` | `salloc` / `srun --pty`, GPU shells, tmux/screen, attaching to a running job |
| `docs/04-batch-jobs.md` | `sbatch` anatomy, resource requests, arrays, dependencies, GPUs, MPI, monitoring, cancelling, `sacct` |
| `docs/05-partitions-and-hardware.md` | Every partition, node type, GPU, time limit and per-user limit |
| `docs/06-software-modules-conda.md` | Environment modules, the CBI collection, Miniforge/conda on scratch, Jupyter kernels |
| `docs/07-containers-apptainer.md` | Building `.sif` images (login node, or Docker on a Mac), GPU containers, bind mounts, sharing across the lab |
| `docs/08-multi-gpu-and-pod.md` | Two-GPU jobs on the `gpu` partition, GPU arrays; POD kept as reference only (not available to us) |
| `docs/09-sge-to-slurm.md` | Wynton (SGE) to SLURM translation table |
| `docs/10-policies-support-troubleshooting.md` | Acceptable-use essentials, downtimes, support channels, common errors |
| `docs/cluster-facts.md` | Live facts captured from the cluster by `scripts/chpc-discover.sh` (last: 2026-09-18) |
| `docs/wiki-sources.md` | Index of the wiki pages this guide is built from |
| `docs/training-2026-09.md` | The Sept 2026 CoreHPC training: what it confirmed, where it is wrong for UCSF, what it changed here |

## Repo layout

```
env.sh                      Source me: CHPC_* variables, scripts on PATH, tab completion; standalone or submodule
chpc.env.local.example      Copy to <your project>/chpc.env.local: username, share, SSH alias
ssh/config.example          SSH config: bastion, ProxyJump, ControlMaster
scripts/chpc-prime.sh       Open the Duo-authenticated master SSH session
scripts/chpc-discover.sh    Dump live cluster facts to docs/cluster-facts.md (or --out FILE)
scripts/chpc-globus.sh      Move data over Globus, the approved path (push/pull/doctor/env)
scripts/chpc-stage.sh       rsync to group scratch -- NOT an approved path; see its header
tools/<tool>/tool.conf      THE TOOL REGISTRY: one entry per piece of software
tools/README.md             Run a tool, the CLI, which GPU, add a tool; then the tool.conf reference
tools/covalent-bonds.md     How each co-folding tool addresses a covalent bond, and why only geometry checks one
templates/slurm/*.sbatch    Ready-to-edit job scripts (tool-gpu for a registry tool; cpu, community, gpu, multi-gpu, array, fork, mpi, container-gpu, local-nvme)
templates/apptainer/*.def   Example definition files + build helper
lab/chpc.env                Lab-specific variables (FAC share name, paths); copied to the FAC share
lab/README.md               Layout of our shared FAC directory, and keeping its copy of this repo current
lab/bin/chpc-tool           Resolve, run, build and publish anything in the registry
lab/bin/chpc-assets         Install and verify licensed binaries and model weights
lab/bin/chpc-jobstats       What a finished job should have asked for (sacct; login node)
lab/bin/chpc-completion.bash  Tab completion; sourced by env.sh and chpc.env in interactive shells
lab/lib/jobstats.awk        The accounting maths behind chpc-jobstats
tests/                      python3 -m unittest discover -s tests   (runs on a laptop; no cluster needed)
```

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
