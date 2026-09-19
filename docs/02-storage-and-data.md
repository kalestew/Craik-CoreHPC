# 2. Storage and data movement

## The four storage tiers

| Path | What | Size / quota | Speed | Persistence | Use for |
|------|------|--------------|-------|-------------|---------|
| `/home/remote/<user>` (`$HOME`) | VAST home | 20 GiB hard, 19 GiB soft | fast | kept | dotfiles, scripts, small configs. NOT conda envs, caches, data |
| `/mnt/scratch/user/<user>` | VAST user scratch | 50 TiB hard per user | fastest shared (InfiniBand) | volatile: purge >30 days, wiped at quarterly maintenance | active job I/O, conda envs, container cache, checkpoints |
| `/mnt/scratch/group/CX500146_DS1` | VAST group scratch | shared | fastest shared | volatile, same purge | shared inputs/outputs of running projects, staged lab containers |
| `/mnt/fac/CX500146_DS1` | our FAC share (NFS 4.2, autofs) | 5.0 TB (55 GB used 2026-09-19); ~$52/TB/yr | slow (capacity tier) | persistent, lab-owned, snapshots under `.qsnaps/` | long-term data, final results, canonical copies of containers/envs/scripts |
| `/tmp` on a compute node | local NVMe | cpu ~2 TB, gpu ~6 TB, large_gpu 6–12 TB, pod ~12 TB, community ~1 TB SAS SSD | fastest | gone when the job ends | scratch inside a job, tight-loop I/O |

Notes:

- `/scratch` is a compatibility symlink to `/mnt/scratch` (from Wynton). It
  may be removed, so write `/mnt/scratch` in scripts.
- Group scratch `/mnt/scratch/group/CX500146_DS1` exists and is writable by
  the `sec_fac_cx500146_ds1` group (all lab members with the share). Our
  FAC share is writable the same way (POSIX ACLs; new files are group rw).
- `/mnt/fac` lists every share on campus, but only ours mounts on access.
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

### Laptop to cluster

- `scp` / `rsync` through the `chpc` SSH alias (see doc 01). Fine for GBs.
  `scripts/chpc-stage.sh <local-path> <remote-path>` wraps rsync with the
  right flags.
- Globus web app for files under ~1 GB: log in at <https://www.globus.org/>
  with the "University of California San Francisco" org login, File Manager,
  search collections for `corehpc`: "UCSF CoreHPC - User Home" and
  "UCSF CoreHPC - User Scratch", browse to your username.
- Globus Connect Personal for large data sets: install per
  <https://docs.globus.org/globus-connect-personal/install/>, log in with your
  UCSF CILogon identity (it ends in `@ucsf.edu` with six leading digits of
  your UCID), create a personal collection, then transfer collection-to-
  collection. Choose "High Assurance" if the data is PHI / P3 / P4.
- FAC shares are also mounted elsewhere (lab workstations, per the FAC team),
  so the FAC share itself can be the transfer medium for lab data.

Approved data-transfer paths per the AUP are Globus, the FAC share, and Open
OnDemand. Do not set up other tunnels for data egress.

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
