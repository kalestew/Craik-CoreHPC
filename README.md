# UCSF CoreHPC — Craik Lab Field Guide

How the Craik Lab uses the UCSF CoreHPC cluster. Four things live here:

- A tool registry, `tools/`: one entry per piece of software the lab runs
  (Boltz-2, ColabFold, RFdiffusion, Rosetta and 29 more) and the `chpc-tool`
  command that runs any of them from the lab's shared FAC storage, with the
  weights, bind mounts and GPU constraints already sorted out.
- A complete worked example, `examples/p1b7/`: the inputs, checks and batch
  script for one structure prediction, used by every walkthrough.
- Slurm job templates, `templates/slurm/`, the lab environment file they
  source, `lab/chpc.env`, and the laptop-side scripts, `scripts/`, that move
  data over Globus and submit jobs.
- A field guide to the cluster itself, `docs/`: access, storage, jobs,
  partitions, containers.

Other lab projects embed this repo as a git submodule at `corehpc/` and read
the registry from it; see "Using it from a project" below.

## First hour on CoreHPC

Start here even if you have never used a terminal. The worked scientific
example is **P1B7 bound to sotorasib-modified KRAS peptide–MHC I, PDB 8UDR**.
Its inputs are included in this repo: you do not need another lab project's
files. The first session covers access and preparation; a prediction may
queue longer than an hour.

### 1. Know which computer you are typing on

Open **Terminal** on your Mac. This gives you a *shell*: a program that runs
the commands you type. There are three places commands run in this guide:

- **Laptop:** your Mac, before `ssh chpc`. Files here are on your Mac.
- **Login node:** the cluster's entrance, after `ssh chpc`. Use it to prepare
  small input files, download files, submit jobs, and read logs.
- **Compute node:** a machine assigned by Slurm, the cluster's job scheduler.
  Run structure prediction and other substantial calculations here.

Each walkthrough labels the location before its command blocks. Paste the
commands inside a block, without the surrounding backticks or a shell prompt
such as `$`. Press Return. A line beginning with `#` is a comment. If a line
ends in `\`, paste the next line too: they form one command. If a block
contains `<<'EOF'`, paste through the final `EOF`; this writes the intervening
text into a file. If you see an error, stop and read it before pasting the next
block.

These commands are useful anywhere and do not change files:

```bash
hostname
whoami
pwd
ls
```

`hostname` names the computer, `whoami` prints your account, `pwd` prints
the current directory, and `ls` lists its contents. On macOS zsh, lines with
comments need `setopt interactivecomments`; the SSH setup guide enables this
before using commented examples.

`cd folder` changes directory; `mkdir -p folder` creates it if needed.
`~` means your home directory on the computer you are using. `$USER` expands
to your username there. Quoted paths such as `"$WORK"` keep spaces together.
Variables last for the current shell; the reconnect instructions below reset
them. **Ctrl-C** stops the foreground command. `exit` leaves the current shell;
from a compute shell it returns to the login node, and from the login node it
disconnects SSH.

### 2. Get access and connect

You need a UCSF campus account, Duo, a CoreHPC account, and membership of the
lab FAC share (`sec_fac_cx500146_ds1`). Your PI requests access through
<https://tiny.ucsf.edu/Gethpc>. Connect to the UCSF VPN, including on campus
Wi-Fi.

**On your laptop, once:** follow [Access and SSH, first-time setup](docs/01-access-and-ssh.md)
to create an SSH key and add the cluster connection settings. That page
explains exactly where your campus username goes and how to preserve an
existing SSH configuration. Then, **on your laptop each time**:

```bash
ssh chpc
```

Approve Duo when prompted. You should now be on the login node. Check:

```bash
hostname
whoami
```

The hostname should be `chpc-ucsf-login-vm1` (or the current CoreHPC login
host), and the username should be your campus username, not your Mac account.
If `ssh chpc` says it cannot resolve `chpc`, finish the SSH configuration
before continuing.

### 3. Load the lab tools

**On the login node, each new session:**

```bash
source /mnt/fac/CX500146_DS1/chpc.env &&
command -v chpc-tool &&
chpc-tool list
```

`source` loads settings into your current shell. The first command configures
the lab's shared tools and moves their temporary caches to scratch storage.
`command -v` should print a path ending in `/bin/chpc-tool`. `list` shows what
is installed; a `planned` tool is not available yet. You do **not** need to
install Boltz, Chai, Protenix, CUDA, or their model weights yourself.

Optional, **once on the login node**, save that setup line for future
interactive Bash sessions. This appends it only if absent:

```bash
touch "$HOME/.bashrc"
if ! grep -Fq '/mnt/fac/CX500146_DS1/chpc.env' "$HOME/.bashrc"; then
    printf '%s\n' '[ -f /mnt/fac/CX500146_DS1/chpc.env ] && source /mnt/fac/CX500146_DS1/chpc.env' >> "$HOME/.bashrc"
fi
```

The walkthroughs still source their environment explicitly, so they work
without this optional setup. If the shared file is missing or unreadable,
ask the lab maintainer about FAC access; do not proceed with empty variables.

### 4. Put this repo on your Mac and set up Globus

Open a **laptop terminal**, separate from your SSH session. Lab members keep
their projects in one folder on the Mac and let Globus see that folder; this
repo goes in it too. Clone it once, into the folder where you keep projects
(here `~/projects`; use your own):

```bash
mkdir -p ~/projects && cd ~/projects
git clone https://git.kalestew.io/ucsf/craik-lab/Craik-CoreHPC.git
cd Craik-CoreHPC
```

If Git asks for credentials, use your GitLab login; if access is denied, ask
the lab maintainer. Then follow
[Globus setup](docs/02-storage-and-data.md#laptop-to-cluster) once: install
Globus Connect Personal and its command-line tool, sign in, add your projects
folder to its **Accessible Folders**, and write your campus username into
`chpc.env.local`. Enable **Writable** on the folder if results should come
back there. From this checkout, check the setup:

```bash
source ./env.sh &&
chpc-globus.sh doctor "$CHPC_REPO/examples/p1b7"
```

`doctor` lists the real folder through Globus. If it reports
`Path not allowed`, add the displayed folder in Globus Connect Personal's
Access settings and retry. Keep the app running and the Mac awake while a
transfer is active.

**Globus moves files; SSH runs commands.** Put scripts and inputs through
Globus, then execute the staged script with a short SSH command. Do not send
file contents through SSH using `scp`, `rsync`, tar, base64, or large inline
Python/heredoc programs. `git clone`/`git pull` remains appropriate for a
committed code checkout on the cluster; it does not transfer your current
local edits or untracked inputs.

### 5. Prepare and run the P1B7 example

Open the **[P1B7 / 8UDR walkthrough](docs/11-p1b7-walkthrough.md)** next.
It explains the five protein chains, covalent ligand, and templates, then
walks through sending the supplied inputs from your laptop and running:

- [Boltz-2](tools/boltz/README.md#run-it), the first suggested walkthrough.
- [Chai-1](tools/chai1/README.md#run-it), with its separate bond-restraint file.
- [Protenix](tools/protenix/README.md#run-it), with its own JSON input format.

The quick path, **on your laptop** after Globus setup, is:

```bash
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch --dry-run -- boltz
```

This previews the transfer and submission. To actually send the files and
submit one GPU job, run:

```bash
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch -- boltz
```

The helper transfers that self-contained example folder and a small submit
script, waits for both Globus transfers to succeed, then submits the batch
job. It creates a fresh scratch directory and saves a receipt with the job
ID and remote path. It uses the lab's shared installation on the cluster by
default. A failed or timed-out transfer stops before job submission.

The walkthrough also gives the manual cluster-shell route, monitoring,
reconnection, and result retrieval. Scratch is temporary; keep final results
on FAC and retrieve them with Globus. For your own work, supply a
self-contained job folder containing its batch script, scripts, and inputs.
Use [the transfer guide](docs/02-storage-and-data.md#laptop-to-cluster) when you
only need to move files without submitting a job.

## Run a tool

Once you have completed a walkthrough, these are the reusable commands.
**On a GPU compute node**, with the lab environment loaded:

```bash
chpc-tool list                              # every tool; STATUS verified = it has run on a compute node here
chpc-tool doctor boltz                      # image and weights really present?
chpc-tool show boltz                        # image path, GPU yes/no, the variables it exports, and its note
chpc-tool exec boltz -- boltz --help        # run a program inside it. Always `-- <program> <args>`
chpc-tool exec boltz -- bash                # a shell inside it
```

Put inputs on `/mnt/scratch/user/$USER` (from a laptop, use the Globus guide
above); the same path is valid inside the container, so a command that
works at the shell works unchanged through `chpc-tool exec`. Weights are
already on the share and `exec` hands the tool their location.

For a full example on your own input, the one idiom you need before writing a
tool's variables on a command line (`eval "$(chpc-tool export boltz)"`), which
GPU model to ask for (seven tools cannot use the Blackwell nodes), and the
batch template: [`tools/README.md`, "Run a tool on your
inputs"](tools/README.md#run-a-tool-on-your-inputs).

## Where to go next

- First complete scientific example, including inputs, jobs and results:
  [P1B7 / 8UDR walkthrough](docs/11-p1b7-walkthrough.md).
- Run the lab's software on your inputs, interactively or as a job:
  [`tools/README.md`](tools/README.md).
- One tool's run block, inputs, traps and build record: `tools/<tool>/README.md`.
- Batch jobs: `docs/04-batch-jobs.md`; ready-to-copy scripts in
  `templates/slurm/` (`tool-gpu.sbatch` is the one for registry tools).
- Storage, quotas, moving data in and out with `chpc-globus.sh`:
  `docs/02-storage-and-data.md`.
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

On your laptop, source the submodule and use the included P1B7 job folder
for your first dispatch. Complete the [Globus setup](docs/02-storage-and-data.md)
once, including access to your projects folder:

```bash
source corehpc/env.sh
chpc-globus.sh doctor "$CHPC_REPO/examples/p1b7"
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch --dry-run -- boltz
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch -- boltz
```

The last line transfers the selected folder through Globus, waits for it,
then submits the job over SSH. See the [walkthrough](docs/11-p1b7-walkthrough.md)
for monitoring and downloading the results. By default, the job uses the
shared cluster tool installation; `--corehpc /absolute/path/on/cluster/corehpc`
selects an existing pinned checkout on the cluster.

For your own jobs, collect the batch script and its input files in one
self-contained folder, then pass that folder and its relative `.sbatch`
filename to `chpc-submit.sh`. Keep inputs unchanged until the transfer ends.
The standard tool template receives `WORKDIR` pointing at the transferred
folder. Project-specific wrappers should call these helpers for transfer and
submission, so their users get the same access checks and transfer receipts.
Add `.chpc/` and `chpc.env.local` to the parent project's `.gitignore`;
they hold local receipts and machine settings.

When already working in a cluster shell, source the **cluster's** checkout
and run `sbatch` there as shown in [batch jobs](docs/04-batch-jobs.md).
Only a cluster path to `CHPC_ENV` can be carried into a job; a Mac path
cannot be used by the compute node.

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
| `CHPC_GLOBUS_*` | CoreHPC collections and scratch paths from `lab/chpc.env`; your machine's collection and path mapping from `chpc.env.local`. A local staging directory is optional. |

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
| `docs/02-storage-and-data.md` | Home, scratch (user/group), FAC, local NVMe, quotas, purge policy, approved transfer paths (Globus, FAC share, OnDemand) and `chpc-globus.sh`, the scripted one; internet access |
| `docs/03-interactive-jobs.md` | `salloc` / `srun --pty`, GPU shells, tmux/screen, attaching to a running job |
| `docs/04-batch-jobs.md` | `sbatch` anatomy, resource requests, arrays, dependencies, GPUs, MPI, monitoring, cancelling, `sacct` |
| `docs/05-partitions-and-hardware.md` | Every partition, node type, GPU, time limit and per-user limit |
| `docs/06-software-modules-conda.md` | Environment modules, the CBI collection, Miniforge/conda on scratch, Jupyter kernels |
| `docs/07-containers-apptainer.md` | Building `.sif` images (login node, or Docker on a Mac), GPU containers, bind mounts, sharing across the lab |
| `docs/08-multi-gpu-and-pod.md` | Two-GPU jobs on the `gpu` partition, GPU arrays; POD kept as reference only (not available to us) |
| `docs/09-sge-to-slurm.md` | Wynton (SGE) to SLURM translation table |
| `docs/10-policies-support-troubleshooting.md` | Acceptable-use essentials, downtimes, support channels, common errors |
| `docs/11-p1b7-walkthrough.md` | First complete P1B7/8UDR example: supplied inputs, chains and ligand, laptop dispatch, interactive/batch runs, templates, checks, reconnecting and saving |
| `docs/cluster-facts.md` | Live facts captured from the cluster by `scripts/chpc-discover.sh` (last: 2026-09-18) |
| `docs/wiki-sources.md` | Index of the wiki pages this guide is built from |
| `docs/training-2026-09.md` | The Sept 2026 CoreHPC training: what it confirmed, where it is wrong for UCSF, what it changed here |

## Repo layout

```
env.sh                      Source me: CHPC_* variables, scripts on PATH, tab completion; standalone or submodule
chpc.env.local.example      Copy to <your project>/chpc.env.local: username, share, SSH alias, local Globus collection
ssh/config.example          SSH config: bastion, ProxyJump, ControlMaster
scripts/chpc-prime.sh       Open the Duo-authenticated master SSH session
scripts/chpc-discover.sh    Dump live cluster facts to docs/cluster-facts.md (or --out FILE)
scripts/chpc-globus.sh      Transfer directly from/to project folders (doctor PATH, push/pull, exclusions, checksum sync)
scripts/chpc-submit.sh      Globus-stage a self-contained job folder, wait for success, then submit with a short SSH command
scripts/chpc-submit-remote.sh  The cluster-side half of chpc-submit.sh; travels with the job folder, never run by hand
scripts/lib/                Python helper that builds a Globus transfer request with directory exclusions
scripts/chpc-stage.sh       Retired SSH transfer entry point; exits with Globus migration instructions
examples/p1b7/              Self-contained P1B7/8UDR tutorial inputs, references, runners and checks
docs/                       The field guide (see Contents above)
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
lab/bin/chpc-fac-fixacl     Repair the owner-DENY ACL on anything created at the FAC share root
lab/bin/chpc-stage-containers  Refresh the group-scratch mirror of the share's containers
lab/bin/run-in-container    The wrapper `chpc-tool publish` instantiates as $CHPC_LAB/bin/<tool>
lab/bin/chpc-completion.bash  Tab completion for chpc-tool, chpc-globus.sh and chpc-submit.sh
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
- Data moves over Globus: `chpc-globus.sh push` / `pull` from a checkout on
  your laptop. `scp`/`rsync` through the bastion is not an approved path, and
  there is no FAC collection, so a share destination is two legs, which the
  script takes for you.
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
