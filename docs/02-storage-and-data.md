# 2. Storage and data movement

## The four storage tiers

| Path | What | Size / quota | Speed | Persistence | Use for |
|------|------|--------------|-------|-------------|---------|
| `/home/remote/<user>` (`$HOME`) | VAST home | 20 GiB hard, 19 GiB soft | fast | kept | dotfiles, scripts, small configs. NOT conda envs, caches, data |
| `/mnt/scratch/user/<user>` | VAST user scratch | 50 TiB hard per user | fastest shared (InfiniBand) | volatile: purge >30 days, wiped at quarterly maintenance | active job I/O, conda envs, container cache, checkpoints |
| `/mnt/scratch/group/CX500146_DS1` | VAST group scratch | shared | fastest shared | volatile, same purge | shared inputs/outputs of running projects, staged lab containers |
| `/mnt/fac/CX500146_DS1` | our FAC share (NFS 4.2, autofs) | 5.0 TB (55 GB used 2026-09-19); ~$52/TB/yr | capacity tier: slower than scratch in bandwidth, **faster** in small-file fsync rate (see note below) | persistent, lab-owned, snapshots under `.qsnaps/` | long-term data, final results, canonical copies of containers/envs/scripts |
| `/tmp` on a compute node | local NVMe | cpu ~2 TB, gpu ~6 TB, large_gpu 6–12 TB, pod ~12 TB, community ~1 TB SAS SSD | fastest | gone when the job ends | scratch inside a job, tight-loop I/O |

Notes:

- `/scratch` is a compatibility symlink to `/mnt/scratch` (from Wynton). It
  may be removed, so write `/mnt/scratch` in scripts.
- Group scratch `/mnt/scratch/group/CX500146_DS1` exists and is writable by
  the `sec_fac_cx500146_ds1` group (all lab members with the share). Our
  FAC share is writable the same way (POSIX ACLs; new files are group rw).
- `/mnt/fac` lists every share on campus and autofs mounts them on access —
  387 `CX*` shares were mounted at capture, not just ours. Only ours is
  *readable*; the rest deny at the ACL. Do not read a directory listing there
  as a permission check.
- FAC keeps snapshots: `/mnt/fac/CX500146_DS1/.qsnaps/` (managed by the FAC
  team; look there before asking for a restore).
- **FAC ACL quirk (verified 2026-09-17):** the share root's inheritable NFSv4
  ACL contains a DENY for `OWNER@`. Anything you create directly at the top
  level from the cluster comes out as `d---rwx---` / `----rw----`: the lab
  group can use it, but you, the owner, cannot, not even `cat` your own
  file. Directories that came in through SMB (`software/`, `moejobs/`) and
  the layout directories we bootstrapped (`bin/`, `containers/`, `envs/`,
  `data/`, `slurm/`, `results/`) carry a correct ACL, and everything created
  inside them is fine. So work inside those, never at the root. If you did
  create something at the root, `chpc-fac-fixacl <path>` (in `$CHPC_LAB/bin`)
  repairs it recursively. The permanent fix is for the FAC team to remove
  `D:fdi:OWNER@:rwaDx` from the share root; ask via
  <https://tiny.ucsf.edu/getfac>.
- FAC costs ~$52/TB/yr plus setup. A recharge for scratch data kept >30 days
  (~$428/TiB/yr) is planned. Home cannot be expanded for free.
- Quotas are soft/hard with a 7-day grace period. Check with `userquota`
  (`/usr/local/bin/userquota`) on the login node; units are TiB/GiB. Note it
  reports `/scratch` and `/home` only — **not** the FAC share.

- **`df` on `/mnt/fac` does not describe our share, and reading it as though
  it does is alarming and wrong.** It reports

  ```
  fac-ha.fac.corehpc.ucsf.edu:/export   49G   23G   24G  50%
  ```

  while `du -sh /mnt/fac/CX500146_DS1` says **55 GB** — more than the whole
  filesystem is supposed to hold. The export carries roughly 400 lab shares
  (`ls /mnt/fac` lists them all), and those `df` figures belong to something
  other than our data; the share itself is provisioned at 5 TB. Someone
  checking "have we room for another container image" will find `df` first,
  conclude the share is half full with 24 GB left, and either panic or, worse,
  believe the 24 GB. Use `du -sh /mnt/fac/$FAC_SHARE` for what we are using,
  and the 5 TB figure in the table above for what we have.
- Do not touch file timestamps to dodge the purge; the AUP says accounts can
  be suspended for it.
- **Which timestamp starts the 30 days is not documented and was not settled.**
  Asked directly at the 2026-09-10 training, the presenter had not seen it
  written down and Gladstone IT confirmed only the 30-day figure. That the AUP
  bothers to forbid touching timestamps implies the trigger is `atime`/`mtime`
  rather than creation, but that is an inference and not a statement from the
  storage team. Plan for the pessimistic reading -- 30 days from arrival -- and
  copy results to FAC in the job that produced them.
- CoreHPC does not back anything up. Backup is the lab's problem (FAC).

## What goes where (lab convention)

```
/mnt/fac/CX500146_DS1/                 canonical, persistent, shared   (see lab/README.md)
   chpc.env     lab environment file (everyone sources it)
   software/    native installs (moe2024.0601 lives here already)
   moejobs/     existing MOE job dir
   containers/  *.sif + defs/*.def
   envs/        environment.yml exports
   bin/         wrapper scripts
   data/        reference data, inputs
   results/     final outputs, one dir per project
/mnt/scratch/group/CX500146_DS1/       hot copies for running jobs
   containers/  rsync'd from FAC (lab/bin/chpc-stage-containers)
   <project>/   working dirs
/mnt/scratch/user/$USER/
   envs/ pkgs/  conda (see doc 06)
   apptainer/   APPTAINER_CACHEDIR, APPTAINER_TMPDIR
   globus-staging/  chpc-globus.sh's buffer for the FAC leg; purged like the rest
   <project>/   personal working dirs
$HOME
   .ssh, .bashrc, .condarc, small scripts only
```

Rule of thumb from the technical overview: FAC is fine for loading an input
data set into memory at job start and for writing final results at the end.
Anything read or written repeatedly during a job belongs on scratch or `/tmp`.

## Moving data

### Between FAC and scratch (on the cluster)

Run on the login node for small/moderate copies; for large copies submit a
job so it runs on a compute node instead (the login node kills heavy work):

```bash
cp -R /mnt/fac/CX500146_DS1/MyFolder /mnt/scratch/group/CX500146_DS1/
rsync -av /mnt/fac/CX500146_DS1/MyFolder/ /mnt/scratch/group/CX500146_DS1/MyFolder/
# big copy as a job:
sbatch -p cpu -c 2 --mem 4G -t 12:00:00 --wrap 'rsync -a /mnt/fac/CX500146_DS1/big/ /mnt/scratch/group/CX500146_DS1/big/'
```

<a id="laptop-to-cluster"></a>

### Laptop to cluster: Globus is the normal transfer route

Use **Globus for files, Git for published code, and SSH for commands**. Run the
Globus commands below in a terminal **on your laptop**, before `ssh chpc`.
Globus Connect Personal must be running on that laptop, and an external drive
must stay mounted while its files are being transferred.

- `git clone` and `git pull` on the cluster obtain committed code from its Git
  server. They do not include your laptop's uncommitted edits or local inputs.
- Globus sends the current files you select: inputs, scripts under development,
  a project working directory, and results coming back. A transfer is a copy,
  not a live link; send changes again before the next run.
- SSH opens a terminal, submits a job, or runs a script that is already on the
  cluster. For a longer check, save a local script, transfer it with Globus,
  then execute it with a short SSH command. Do not transport files or programs
  through SSH using `scp`, `rsync`, a tar stream, base64, or a remote heredoc.

The AUP names Globus, the FAC share, and Open OnDemand as approved transfer
paths. The CoreHPC training on 2026-09-10/11 explicitly disallowed file
transfers through the bastion. `scripts/chpc-globus.sh` implements the lab's
Globus route; the retired `scripts/chpc-stage.sh` refuses transfers and points
to this replacement. The Globus web
[File Manager](https://app.globus.org/file-manager) can use the same collections
for a manual transfer. A workstation that already mounts FAC can also copy
files directly to that mount.

### 1. Make your projects folder accessible

The lab convention is one projects folder on your Mac, holding this repo and
every project that uses it, and Globus Connect Personal allowed to see that
folder. Transfers then read and write your working copies directly. You can
allow the whole projects folder, or one project at a time.

On a Mac:

1. Install and start [Globus Connect Personal](https://docs.globus.org/globus-connect-personal/install/mac/).
   Sign in using your UCSF identity and complete the collection setup.
2. Click the Globus icon in the menu bar. Open **Settings/Preferences → Access**
   (the folder list may be labelled **Accessible Folders/Directories**).
3. Click **+** and select your projects folder, for example
   `/Users/yourname/projects`. A folder on an external volume
   (`/Volumes/...`) works the same way and must be allowed here too.
4. Read access lets Globus send files. Enable **Writable** for the folder where
   you want downloaded results to land. You can instead keep the project
   read-only and allow a separate results folder to be writable.

Adding a folder to this access list does **not** publish its contents to other
people. Collaborator/public sharing uses a separate guest collection and
explicit permissions; **Sharable** is unnecessary for your own transfers to
CoreHPC. See the [Globus sharing guide](https://docs.globus.org/guides/tutorials/manage-files/share-files/).

### 2. Install the command-line tool and sign in

Globus Connect Personal is the background app that provides access to files.
The **Globus CLI** supplies the `globus` terminal command. You need both for the
scripted workflow.

On a Mac with Homebrew already installed, paste:

```bash
brew install pipx
pipx ensurepath
```

Close that Terminal window and open a new one, then paste:

```bash
pipx install globus-cli
globus --version
globus login
```

Follow the browser sign-in and consent prompts using your UCSF account. If
`globus --version` already works, skip installation and just sign in. Other
installation options are in the [official CLI guide](https://docs.globus.org/cli/).

### 3. Load this project's settings and check the actual folder

Open a terminal on your laptop and go to your CoreHPC checkout inside the
projects folder you just allowed (the README's first-hour steps clone it
there). Change the first line to your own path; keep the double quotes if a
folder name has spaces:

```bash
cd "$HOME/projects/Craik-CoreHPC"
cp -n chpc.env.local.example chpc.env.local
nano chpc.env.local
```

`cp -n` creates your settings file only if it does not already exist. In the
editor, find the `#CHPC_USER=...` line, remove its leading `#`, and replace
`jdoe` with your **campus username**, for example:

```bash
CHPC_USER="${CHPC_USER:-jdoe}"
```

Save with **Control-O**, press **Return**, and leave with **Control-X**. With a
normal Mac collection, no Globus values need changing. Your local collection
ID is detected automatically and `CHPC_GLOBUS_LOCAL_ROOT` defaults to `/`.
`CHPC_GLOBUS_STAGING_LOCAL` can stay unset.

Now paste:

```bash
source env.sh
chpc-globus.sh env
chpc-globus.sh doctor "$CHPC_PROJECT"
```

For a project that embeds CoreHPC as a submodule, start at that project's root
and use `cp -n corehpc/chpc.env.local.example chpc.env.local`, then
`source corehpc/env.sh` instead. Keep the same `env` and `doctor` commands.
`CHPC_PROJECT` is the parent project when CoreHPC is a submodule, or this
checkout when it stands alone. Settings belong in the parent project's
`chpc.env.local`, which should be ignored by Git.

Check that `CHPC_USER` is your campus username and that the reported local
collection/path is the folder you intended. `doctor` checks login, whether the
local path can be listed through Globus, and access to CoreHPC User Scratch.
Its SSH warning matters for FAC copies and later job submission; a direct
Globus transfer to/from user scratch needs no SSH session. A successful
listing confirms read access, **not** Globus write permission; the destination
must also be marked Writable before pulling results.

If User Scratch requests consent, paste this, follow its browser prompts, and
repeat the check:

```bash
globus login --gcs "$CHPC_GLOBUS_SCRATCH_COLLECTION"
chpc-globus.sh doctor "$CHPC_PROJECT"
```

**Access permissions and path mapping are different.** For normal Mac GCP, a
folder such as `/Users/yourname/projects/Craik-CoreHPC` has that same absolute
path inside its collection. Adding just that project to Accessible Folders
does not change the collection root to that folder. Keep
`CHPC_GLOBUS_LOCAL_ROOT=/`; override it only if you have verified a different
mapping for your collection. On CoreHPC, the User Scratch collection maps `/`
to your own `/mnt/scratch/user/$CHPC_USER`, and the wrapper removes that prefix
for you. Always pass the full cluster filesystem path to the wrapper.

### 4. Send the P1B7 example straight from this checkout

This short example checks data movement without starting a prediction. From
the same **laptop terminal**:

```bash
chpc-globus.sh doctor "$CHPC_REPO/examples/p1b7"
chpc-globus.sh push "$CHPC_REPO/examples/p1b7" \
  "$CHPC_USER_SCRATCH/p1b7-transfer-check" --dry-run
```

Read the printed source and destination. `--dry-run` prints the route without
sending anything; it does not prove access or completion. Remove that option
to transfer:

```bash
chpc-globus.sh push "$CHPC_REPO/examples/p1b7" \
  "$CHPC_USER_SCRATCH/p1b7-transfer-check"
```

The wrapper waits for success (up to an hour by default). The contents of
`examples/p1b7` arrive directly in `p1b7-transfer-check`, so its README is at
`$CHPC_USER_SCRATCH/p1b7-transfer-check/README.md`. Globus does not add another
`p1b7` directory underneath that destination. The
[P1B7 walkthrough](11-p1b7-walkthrough.md) uses these same inputs with Boltz,
Chai, and Protenix.

For a ready-to-run job bundle, `chpc-submit.sh` combines a Globus transfer,
successful-completion check, and Slurm submission. Preview the P1B7 Boltz job
without transferring files or submitting anything:

```bash
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch --dry-run -- boltz
```

The [P1B7 walkthrough](11-p1b7-walkthrough.md) explains that job's requirements
and actual submission. The helper sends the selected folder to its own run
directory on scratch.

For a deliberate copy of a whole working project, use the lower-level `push`
with explicit exclusions:

```bash
chpc-globus.sh push "$CHPC_PROJECT" \
  "$CHPC_USER_SCRATCH/work/$(basename "$CHPC_PROJECT")" \
  --exclude '.git' --exclude 'chpc.env.local' --exclude '.DS_Store' \
  --exclude-dir '.git' --exclude-dir '.venv' --exclude-dir '__pycache__' \
  --sync-level checksum
```

`push` does not read `.gitignore`. `--exclude` matches file names;
`--exclude-dir` matches directory names and omits their entire contents. Quote
patterns so your local shell does not expand them. Both `.git` forms matter:
a normal checkout has a `.git` directory, while submodules/worktrees can have
a `.git` file. Directory exclusions require `python3`, which builds the
request sent through the Globus CLI. Add exclusions for your own large
generated outputs or local environments.

Globus copies uncommitted and untracked files that are not excluded; it does
not create a Git clone. Recursive Globus transfers skip symlinks encountered
inside a directory, so use real input files in a self-contained job folder.
`--sync-level checksum` skips identical files on repeated sends to the same
scratch destination. It never deletes files already present there, so use a
new cluster run directory when an exact, fresh set of inputs matters. Avoid
editing files while a transfer of them is active.

### 5. Wait for large transfers and retrieve results

For a direct transfer to user scratch, `--wait 0` queues it and prints the task
ID. This lets you check it later without keeping the terminal command open:

```bash
TRANSFER_TASK=$(chpc-globus.sh push "$CHPC_REPO/examples/p1b7" \
  "$CHPC_USER_SCRATCH/p1b7-transfer-check" --wait 0)
printf 'Transfer task: %s\n' "$TRANSFER_TASK"
globus task wait "$TRANSFER_TASK" --timeout 3600
globus task show "$TRANSFER_TASK"
```

**Wait for `Status: SUCCEEDED` before submitting a job that uses those files.**
A wait timeout does not cancel the transfer; inspect the task status and wait
again. `globus task list` finds task IDs if you open a new terminal. Keep GCP
running and your Mac awake/connected until the transfer completes.

To bring that example directory back as a transfer check, create a writable
results folder under your allowed project path and paste:

```bash
mkdir -p "$CHPC_PROJECT/downloads"
chpc-globus.sh doctor "$CHPC_PROJECT/downloads"
chpc-globus.sh pull "$CHPC_USER_SCRATCH/p1b7-transfer-check" \
  "$CHPC_PROJECT/downloads/p1b7-transfer-check"
```

For real results, replace the source with the output directory reported by
your job, and choose a new local destination. Pulling into an existing folder
can replace same-named files; use a separate run folder to preserve older
results. You can pull from scratch or from FAC, for example:

```bash
chpc-prime.sh
chpc-globus.sh pull "$CHPC_LAB/results/p1b7" \
  "$CHPC_PROJECT/downloads/p1b7-results"
```

That FAC example assumes your job saved results there. Follow the
[P1B7 result-saving step](11-p1b7-walkthrough.md) for the actual run path.

### Persistent data: why FAC transfers have two legs

There is **no FAC Globus collection**. The two CoreHPC collections are User
Home and User Scratch; use **User Scratch** for inputs and outputs, not the
20 GiB Home collection. These are site settings already in `lab/chpc.env`.

A push to FAC first transfers into `$CHPC_GLOBUS_STAGING` on user scratch,
then uses SSH to request a **cluster-local** copy into FAC and repair its ACLs.
File contents do not pass through SSH. A pull copies FAC data into that scratch
buffer first, then Globus transfers it to your laptop. This remote buffer is
separate from the optional local staging folder.

For example, with actual files in the P1B7 example:

```bash
chpc-prime.sh
chpc-globus.sh push "$CHPC_REPO/examples/p1b7" \
  "$CHPC_LAB/data/p1b7-example" --dry-run
chpc-globus.sh push "$CHPC_REPO/examples/p1b7" \
  "$CHPC_LAB/data/p1b7-example"
```

Use destinations inside the established FAC layout (`data/`, `results/`, and
so on), because of the ACL issue described above. The scratch buffer is
purged like any other scratch data; FAC holds the persistent copy. Each FAC
transfer uses its own scratch buffer, so repeated sends cannot reuse stale
buffer contents. `--sync-level checksum` does not save upload work on that
route: the new buffer starts empty. A push to
FAC must finish the Globus leg before its local copy, so `--wait 0` is refused
for that route. Use the default wait or a longer `--wait` value.

### Optional: expose only a staging folder

If you would rather not give Globus access to your projects folder, allow a
single staging folder instead (Writable, for incoming results) and copy the
files for each run into it. `push` and `pull` take whatever local path you
pass them, so nothing else changes:

```bash
mkdir -p "$HOME/globus-staging/p1b7"
cp -R "$CHPC_REPO/examples/p1b7/." "$HOME/globus-staging/p1b7/"
chpc-globus.sh doctor "$HOME/globus-staging/p1b7"
chpc-globus.sh push "$HOME/globus-staging/p1b7" \
  "$CHPC_USER_SCRATCH/p1b7-transfer-check"
```

`CHPC_GLOBUS_STAGING_LOCAL` in `chpc.env.local` only records that folder for
pipelines that ask for it; setting it copies nothing and grants no access.

### If a check fails

- **`globus: command not found`:** install the CLI and open a new Terminal
  window after `pipx ensurepath`.
- **No local collection detected:** start Globus Connect Personal. If you set
  `CHPC_GLOBUS_LOCAL_COLLECTION` manually, confirm it identifies this machine.
- **Local path cannot be listed:** confirm it exists, its external disk is
  mounted, and it is in Accessible Folders. Check the absolute path shown by
  `chpc-globus.sh env`/`doctor`; do not substitute a different root just to make
  an unrelated folder list successfully.
- **A path contains `..`:** use the absolute path from `pwd -P` after changing
  to the intended directory. The wrapper refuses `..` because simplifying it
  around symlinks could select a different file.
- **Push works, pull fails:** enable Writable for the local destination and
  check your macOS user can write there too. Listing alone cannot prove this.
- **Scratch consent error:** run the `globus login --gcs` command in step 3.
  Do not use `--gcs` with your personal collection; its authentication model
  differs from the cluster's mapped collection.
- **FAC copy needs SSH:** run `chpc-prime.sh` in your laptop terminal. See
  [access and SSH setup](01-access-and-ssh.md) if the alias is not configured.
- **A transfer is still active:** use `globus task show TASK_ID`. A disconnected
  laptop or unmounted drive needs to be available again for transfer to resume.

`globus collection show` can require management consent beyond transfer
permissions. Use `doctor`/`globus ls` to diagnose file access rather than
assuming a management-consent error means transfers are broken.

### "Slow" is about bandwidth, not about every access pattern

The tier table and the CoreHPC training both rank FAC below scratch, and for
streaming large files that is right. For the opposite pattern -- many small
files, each `fsync`'d and renamed -- it is measured backwards. Three runs on a
compute node, 64 KiB writes with `fsync` + rename:

| tier | files/s |
|---|---|
| node-local `/tmp` | 2985–3030 |
| `/mnt/fac` | 1349–1352 |
| `/mnt/scratch/group` | 235–241 |

They are different appliances: scratch is NFSv3 on VAST, FAC is NFSv4.2 on
`fac-ha`. So "stage off FAC before computing" is sound for a job that streams
a large input, and wrong for one that writes a content-addressed store.

Two caveats before anyone generalises this. It measures a *single writer's*
throughput, while the trainers' concern is the aggregate metadata load many
small files put on shared storage -- which this cannot see. And it used *group*
scratch, where the guidance names *user* scratch. Confirm with UCSF CoreHPC
support before putting a sustained small-file workload on FAC.

## Internet access

Only `chpc-ucsf-login-vm1` has internet, through a proxy. It reaches
git.ucsf.edu, GitHub, Hugging Face, Docker Hub, Apptainer/Singularity
registries and Python package indexes. Compute nodes (including the POD)
have no internet. Bastions have no access at all.

**"No internet" on a compute node does not mean "no proxy", and the
difference changes the error you get.** Compute nodes *do* get proxy
variables — pointing at a *different* host, `chpc-computeproxy-vm1:3128`,
not the login node's `chpc-proxy-vm1:3128` — and that proxy is up and
answering. It simply refuses the destinations we want. So a fetch from a
job does not hang and does not time out; it fails immediately with

```
curl: (7) CONNECT tunnel failed, response 403
```

and plain http returns a bare `403` from the proxy rather than from the
site. Measured on ccpu1-01, 2026-09-18: pypi.org, github.com,
registry-1.docker.io, dl.fbaipublicfiles.com and files.ipd.uw.edu are all
403. This reads like an authentication problem and is not one — there is
no token that opens it. Fetch on the login node and stage to scratch or
FAC. Do not set `http_proxy` by hand in a job hoping to reach the login
node's proxy either: `chpc-proxy-vm1` resolves from a compute node but
does not accept connections from one.

**What the login node reaches is broader than the list above**, and the way to
tell a proxy refusal from a real answer is the CONNECT itself: a blocked
destination returns 403 with no `200 Connection established`, whereas any other
status — including 400 and 404 — means the tunnel opened and you are reading
the origin. Measured on `chpc-ucsf-login-vm1`, 2026-09-21:

| destination | result |
|---|---|
| `huggingface.co`, `github.com`, `pypi.org` | 200 |
| `zenodo.org`, `ftp.ebi.ac.uk` | 200 |
| `files.ipd.uw.edu` | 404 from the origin — reachable |
| `storage.googleapis.com` | 400 from the origin — reachable |
| `registry-1.docker.io` | 404 from the origin — reachable; the API is under `/v2/` |
| `dl.fbaipublicfiles.com` | **refused**: CONNECT sent, no tunnel established |

So a 400 or a 404 here is good news and a 403 is not. Check with `curl -sv` and
look for the `Connection established` line rather than trusting the status code
on its own. `files.ipd.uw.edu` is worth singling out because RFdiffusion and
PLACER weights come from there and therefore need no Globus;
`dl.fbaipublicfiles.com`, the ESM/fairseq host, is genuinely refused and does.

Run a long fetch under `tmux` on the login node. Downloads are sanctioned
there, but the machine is far smaller than `nproc` and `free` suggest: your
processes run in a user slice capped at **4 CPUs, 8 GiB soft / 16 GiB hard**
(measured 2026-09-18, doc 07). `ulimit` shows none of this because the limits
are cgroup limits. A dropped SSH session also still kills a fetch, so use
`tmux`. Fetching at any size is fine; *computing* there is not, and the
CoreHPC training was emphatic that heavy work on the login node degrades
logins for everyone.

The proxy is configured through `http_proxy`/`https_proxy` variables set
in the login profile (`chpc-proxy-vm1:3128`). They exist in interactive
logins and `bash -l`, but not in `ssh chpc 'command'` one-liners or
`bash -s` scripts, where downloads then fail silently. Use
`ssh chpc 'bash -lc "..."'` for remote commands that need the network.
Allowed destinations include GitHub, git.ucsf.edu, git.kalestew.io
(HTTPS only; SSH is blocked), Hugging Face, Docker Hub, PyPI.

So: `git clone`, `pip download`, `conda create`, `apptainer pull`,
`huggingface-cli download`, model weights, reference databases: do them on
the login node, into scratch or FAC, before submitting the job. Set
`HF_HOME`, `TRANSFORMERS_CACHE`, `TORCH_HOME` etc. to a scratch path so
downloads land there and do not fill home.

## Local NVMe inside a job

```bash
JOBTMP=/tmp/$USER/job_$SLURM_JOB_ID
mkdir -p "$JOBTMP"
trap 'rm -rf "$JOBTMP"' EXIT
# copy inputs in, compute, copy results out to scratch/FAC
```

The wiki also mentions `/scratch/$USER/job_$SLURM_JOB_ID`; `/tmp` is the
per-node NVMe on all node types. Clean up: the AUP expects jobs to remove
their own temporary files.
