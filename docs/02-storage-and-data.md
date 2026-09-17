# 2. Storage and data movement

## The four storage tiers

| Path | What | Size / quota | Speed | Persistence | Use for |
|------|------|--------------|-------|-------------|---------|
| `/home/remote/<user>` (`$HOME`) | VAST home | 20 GiB hard, 19 GiB soft | fast | kept | dotfiles, scripts, small configs. NOT conda envs, caches, data |
| `/mnt/scratch/user/<user>` | VAST user scratch | 50 TiB hard per user | fastest shared (InfiniBand) | volatile: purge >30 days, wiped at quarterly maintenance | active job I/O, conda envs, container cache, checkpoints |
| `/mnt/scratch/group/<FAC_SHARE>` | VAST group scratch | shared | fastest shared | volatile, same purge | shared inputs/outputs of running projects, staged lab containers |
| `/mnt/fac/<FAC_SHARE>` | FAC capacity storage | what the lab bought (~$52/TB/yr) | slow (capacity tier) | persistent, lab-owned | long-term data, final results, canonical copies of containers/envs/scripts |
| `/tmp` on a compute node | local NVMe | cpu ~2 TB, gpu ~6 TB, large_gpu 6–12 TB, pod ~12 TB, community ~1 TB SAS SSD | fastest | gone when the job ends | scratch inside a job, tight-loop I/O |

Notes:

- `/scratch` is a compatibility symlink to `/mnt/scratch` (from Wynton). It
  may be removed, so write `/mnt/scratch` in scripts.
- Group scratch is named after the FAC share, e.g. `CX000123_DS1`. Ask
  CoreHPC to create it if it does not exist.
- FAC costs ~$52/TB/yr plus setup. A recharge for scratch data kept >30 days
  (~$428/TiB/yr) is planned. Home cannot be expanded for free.
- Quotas are soft/hard with a 7-day grace period. Check with `userquota`
  (`/usr/local/bin/userquota`) on the login node; units are TiB/GiB.
- Do not touch file timestamps to dodge the purge; the AUP says accounts can
  be suspended for it.
- CoreHPC does not back anything up. Backup is the lab's problem (FAC).

## What goes where (lab convention)

```
/mnt/fac/<FAC_SHARE>/chpc/            canonical, persistent, shared   (see lab/README.md)
   containers/  *.sif + *.def
   envs/        environment.yml exports
   bin/         wrapper scripts
   data/        reference data, inputs
   results/     final outputs, one dir per project
/mnt/scratch/group/<FAC_SHARE>/       hot copies for running jobs
   containers/  rsync'd from FAC (scripts/stage)
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
cp -R /mnt/fac/<FAC_SHARE>/MyFolder /mnt/scratch/group/<FAC_SHARE>/
rsync -av /mnt/fac/<FAC_SHARE>/MyFolder/ /mnt/scratch/group/<FAC_SHARE>/MyFolder/
# big copy as a job:
sbatch -p cpu -c 2 --mem 4G -t 12:00:00 --wrap 'rsync -a /mnt/fac/<FAC_SHARE>/big/ /mnt/scratch/group/<FAC_SHARE>/big/'
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
