# 7. Containers with Apptainer (and sharing them across the lab)

Apptainer (formerly Singularity) is installed on every CoreHPC node, no
module needed. It runs as your own user, mounts `$HOME`, `/tmp` and the
current directory by default, and needs no root to run. It is the right
way to package software for the lab: one `.sif` file on FAC, one wrapper
script, everybody gets the identical environment in their job scripts.

## Vocabulary

| Thing | Meaning |
|-------|---------|
| `.sif` | immutable single-file image; what you run and share |
| `.def` | definition file; recipe to build a `.sif` (keep it in git, next to the image) |
| sandbox | writable directory image for development (`--sandbox`) |
| `apptainer pull` | fetch an existing image (Docker Hub, NGC, GHCR, quay, library) into a `.sif` |
| `apptainer build` | build a `.sif` from a `.def`, a Docker image, a tar, or a sandbox |
| `--nv` | expose NVIDIA GPUs + driver libs inside the container |
| `--bind` | mount host paths inside the container |

## One-time environment setup (per user)

Apptainer caches layers and builds under `~/.apptainer` by default, which
kills the 20 GiB home quota. Put this in `~/.bashrc` (or source `lab/chpc.env`):

```bash
export APPTAINER_CACHEDIR=/mnt/scratch/user/$USER/apptainer/cache
export APPTAINER_TMPDIR=/mnt/scratch/user/$USER/apptainer/tmp
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"
```

Both are volatile scratch; that is fine, they are caches.

## Getting images: the easy path (pull)

Only the login node has internet, so pull there:

```bash
cd /mnt/scratch/user/$USER/apptainer
apptainer pull pytorch_24.01.sif docker://nvcr.io/nvidia/pytorch:24.01-py3
apptainer pull samtools.sif docker://quay.io/biocontainers/samtools:1.20--h50ea8bc_0
apptainer pull colabfold.sif docker://ghcr.io/sokrypton/colabfold:1.5.5-cuda12.2.2
apptainer pull rocky.sif library://library/default/rockylinux:9   # if the library endpoint is reachable
```

Test on a compute node, then promote to the lab share (below).

## Building your own image

### Option A: build on the login node (usual case)

CoreHPC's Apptainer supports unprivileged builds (user namespaces). Try
the plain command first; if it fails with a permissions error inside
`%post`, add `--fakeroot`. Keep builds modest; the login node kills heavy
processes, so avoid compiling large code in `%post` there (compile in a
sandbox in an interactive job instead, see Option C).

```bash
cd $CHPC_LAB/containers/defs      # keep .def files with the images
apptainer build ../mytool_1.0.sif mytool_1.0.def
# or, if the above complains about permissions:
apptainer build --fakeroot ../mytool_1.0.sif mytool_1.0.def
```

Minimal definition file (`templates/apptainer/minimal.def`):

```
Bootstrap: docker
From: ubuntu:22.04

%post
    apt-get update && apt-get install -y --no-install-recommends python3 python3-pip && rm -rf /var/lib/apt/lists/*
    pip3 install --no-cache-dir numpy

%environment
    export LC_ALL=C.UTF-8

%runscript
    exec "$@"

%labels
    Author Craik Lab
    Version 1.0

%help
    Run: apptainer exec mytool_1.0.sif python3 script.py
```

Other useful sections: `%files src dst` (copy files in at build time),
`%test` (run after build), `Bootstrap: localimage` / `From: base.sif`
(layer on top of an existing sif, e.g. the NGC PyTorch image).

Conda inside a container (`templates/apptainer/conda-env.def`) uses a
Miniforge base and `environment.yml`, which is the most reproducible way to
freeze a Python stack for the lab.

### Option B: build on your Mac with Docker, ship the tarball

Useful when the recipe needs real root, lots of CPU, or you already have a
Dockerfile. Apple Silicon must target `linux/amd64` (all CoreHPC nodes are
x86_64).

```bash
docker buildx build --platform linux/amd64 -t mytool:1.0 .
docker save mytool:1.0 -o mytool_1.0.tar
scripts/chpc-stage.sh mytool_1.0.tar /mnt/scratch/user/$USER/apptainer/
# on the login node:
apptainer build mytool_1.0.sif docker-archive:///mnt/scratch/user/$USER/apptainer/mytool_1.0.tar
```

(Or push the Docker image to GHCR/Docker Hub and `apptainer pull docker://...` on the login node.)

### Option C: develop in a sandbox, then freeze

```bash
# login node (internet): create the writable sandbox from a base
apptainer build --sandbox mytool_dev docker://ubuntu:22.04
# compute node (CPU): compile / install interactively
salloc -p cpu -c 16 --mem 32G -t 4:00:00
apptainer shell --writable --fakeroot mytool_dev      # drop --fakeroot if not permitted
# ... apt-get/pip/make (anything needing internet must be fetched on the login node first) ...
exit; exit
# login node: freeze it
apptainer build mytool_1.0.sif mytool_dev
```

Sandboxes are directories with many small files; keep them on scratch and
delete them once frozen. Always regenerate the `.def` so the build is
reproducible; a sif from a sandbox is a snapshot, not a recipe.

## Running containers

```bash
apptainer exec image.sif <command>             # run one command
apptainer run image.sif [args]                  # run the %runscript
apptainer shell image.sif                       # interactive shell inside
apptainer inspect image.sif                     # labels, help, def file (--deffile)
apptainer exec --nv image.sif nvidia-smi        # GPU
```

### Bind mounts (important on CoreHPC)

`$HOME`, `/tmp` and `$PWD` are bound automatically. `/mnt/scratch` and
`/mnt/fac` are NOT (unless the admins configured it; `scripts/chpc-discover.sh`
records the site bind list). Add them explicitly, and use the same path
inside as outside so scripts work identically with and without the container:

```bash
apptainer exec --nv --bind /mnt/scratch,/mnt/fac image.sif python train.py
```

Set once in `lab/chpc.env` so every wrapper picks it up:
`export APPTAINER_BIND=/mnt/scratch,/mnt/fac`.

`--containall` isolates `$HOME` and env vars (cleaner, avoids your
`~/.local` Python packages leaking into the container); `--cleanenv` just
drops host env vars. `--pwd /path` sets the working directory.

### In a SLURM job

```bash
#!/bin/bash
#SBATCH -p gpu --gres=gpu:1 -c 8 --mem 32G -t 4:00:00
source /mnt/fac/<FAC_SHARE>/chpc/chpc.env
srun apptainer exec --nv --bind /mnt/scratch,/mnt/fac \
     $CHPC_CONTAINERS/pytorch_24.01.sif python train.py
```

Mix host steps and container steps freely; each `srun` is a job step. MPI
inside a container works with `srun apptainer exec mpi_app.sif ./binary`
provided the container's MPI matches the host's (OpenMPI 5 / PMIx); NGC
images generally do.

## Sharing containers across the lab (our convention)

Layout on FAC (persistent, canonical) with a hot copy on group scratch:

```
$CHPC_LAB = /mnt/fac/<FAC_SHARE>/chpc
$CHPC_LAB/containers/<tool>_<version>.sif     immutable; never overwrite, bump the version
$CHPC_LAB/containers/defs/<tool>_<version>.def the recipe (also in this git repo under templates/apptainer or a lab repo)
$CHPC_LAB/containers/README.md                one line per image: what, version, who built, date, how to run
$CHPC_LAB/bin/<tool>                          wrapper: apptainer exec --nv --bind ... $CHPC_CONTAINERS/<tool>_<version>.sif "$@"
/mnt/scratch/group/<FAC_SHARE>/containers/    rsync'd copy for fast start-up (lab/bin/chpc-stage-containers)
```

Rules:

1. Build or pull into your own scratch, test in an interactive job, then
   `cp` to `$CHPC_LAB/containers/` and `chmod 644`. Group-readable, not writable by others.
2. Never modify a published sif. New version = new file name; update the
   wrapper's default.
3. Every image gets a `.def` (or the `docker://` URL in the README) so it
   can be rebuilt after a CVE or when the image is lost.
4. Wrappers live in `$CHPC_LAB/bin` and are used the same way on the login
   node, in `salloc`, and in `sbatch`: `mytool --help`.
5. Jobs read the sif from group scratch when present (fast VAST), falling
   back to FAC. `lab/bin/chpc-stage-containers` refreshes the scratch copy;
   run it after publishing and after each quarterly purge.
6. Reference data used by the containers goes in `$CHPC_LAB/data/` and is
   bound read-only: `--bind $CHPC_LAB/data:/refdata:ro`.

`lab/README.md` and `lab/bin/` implement this.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `FATAL: ... permission denied` during build | `--fakeroot`; or build on Mac (Option B) |
| `no space left on device` while building | `APPTAINER_TMPDIR`/`CACHEDIR` still on home; set them to scratch |
| `Disk quota exceeded` | same |
| Command not found inside | `$PATH` inside container; use absolute path or fix `%environment` |
| Cannot see `/mnt/scratch` | `--bind /mnt/scratch,/mnt/fac` |
| GPU not visible | `--nv`; and the job must have `--gres=gpu:N` |
| Pull times out in a job | compute nodes have no internet; pull on the login node |
| Host Python packages interfere | `--containall` or `export PYTHONNOUSERSITE=1` |
| Slow start from FAC | stage sif to group scratch (`chpc-stage-containers`) |
