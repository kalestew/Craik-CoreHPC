# 6. Software: modules, Miniforge/conda, Jupyter

## Environment modules

Software is exposed through environment modules, identical on login and
compute nodes.

```bash
module avail                 # everything visible now
module load <name>[/version]
module list                  # what is loaded
module unload <name> ; module purge
module spider <name>         # search including nested collections (Lmod)
module show <name>           # what a module sets
```

Loaded by default at login (from the primer's listing): `gnu14/14.2.0`,
`openmpi5/5.0.7`, `hwloc`, `ucx`, `libfabric`, `autotools`, `prun`, `ohpc`.

Top-level collections in `/etc/modulefiles`: `CBI`, `RAD`, `Sali`,
`nvidia-hpc`. These are nested: load one, then `module avail` again.
Full lists are in `docs/cluster-facts.md` (captured 2026-09-18). Highlights:

- **CBI** (`/mnt/software/cbi`, the group that ran Wynton's CBI stack):
  `miniforge3` (25.11 to 26.3.2-3, default 26.3.2-3), `python/3.14.6`,
  `r/4.5.3`, `julia/1.13`, `matlab/R2025b`, `uv`, `snakemake/9.27`,
  `nextflow/26.04`, `samtools`, `bcftools`, `htslib`, `bwa`, `bowtie2`,
  `star`, `salmon`, `kallisto`, `gatk/4.7`, `picard`, `bedtools2`,
  `blast/2.17`, `cellranger/10.1`, `sratoolkit`, `cutadapt`, `trimgalore`,
  `fastqc`, `globus-cli`, `rclone`, `restic`, `aws-cli`, `hdf5`, `netcdf`,
  `gsl`, `openjdk`, `node`, `go`, `rust`, `cmake`, `scl-gcc-toolset/15`,
  `dmtcp` (checkpointing), `tmux` helpers (`byobu`), `ncdu`, `htop`, `jq`.
- **Sali** (Sali lab): `modeller/10.8`, `imp/2.25`, `rosetta/3.10`,
  `phenix/1.19`, `relion/3.0`, `dssp`, `fpocket`, `psipred`, `muscle`,
  `usearch`, `blast+/2.12`, `patch_dock`, `zdock`, `scwrl`, `cuda/12.8.1`
  (also 12.4, 11.5), `eigen`, `boost`, `hdf5`, `gnuplot`, `imod`, a
  `python3/*` set (biopython, numpy, scipy, pandas, matplotlib,
  tensorflow/2.19, jax-cuda12/0.9, scikit, h5py, ihm, modelcif),
  `anaconda/py311` and `conda-forge/py313` (prefer CBI miniforge3).
- **nvidia-hpc** (`/opt/nvidia/hpc_sdk`): `nvhpc/26.5` (compilers + CUDA),
  `nvhpc-hpcx/26.5` (CUDA-aware OpenMPI/HPC-X), `nvhpc-hpcx-cuda12/26.5`,
  `nvhpc-hpcx-cuda13/26.5`, `nvhpc-hpcx-cuda12-openmpi5/26.5`, `nvhpc-nompi`,
  `nvhpc-byo-compiler`; 25.1 versions also present.
- **RAD** (radiology, `/mnt/software/rad`): `SCS/*` neuroimaging tools
  (ANTs, ITK-SNAP, afni, MRIcroGL, dcmtk, connectome workbench, ...).

GPU jobs: `module load nvidia-hpc` then `module load nvhpc-hpcx` (or
`module load Sali cuda/12.8.1` for just a CUDA toolkit) when you need
`nvcc` or CUDA-aware MPI. A conda env or container that ships its own
CUDA runtime only needs the driver, which is always present on GPU nodes.
`nvidia-smi` does not exist on the login node.

Compilers and MPI stacks: `gnu14`, `openmpi5`, `mpich`, `mvapich2`, `cmake`,
`boost`, `papi`, `tau`, `scorep` under `/opt/ohpc/pub`.

Apptainer 1.5.2 is installed as a base package at `/usr/bin/apptainer`;
no module is needed and there is no `apptainer` module (the generic wiki
guide's `module load apptainer` line fails harmlessly). `singularity` is a
symlink to it.

`scripts/chpc-discover.sh` records the full current module list in
`docs/cluster-facts.md`.

## Miniforge / conda

CoreHPC supports Miniforge3 only. Do not install Anaconda (licensing) and
do not install your own Miniforge in shared locations.

### One-time setup (per user)

```bash
module load CBI
module load miniforge3            # default 26.3.2-3 -> conda 26.5, mamba, python 3.13, jupyter
conda --version
# if 'conda activate' complains, source the hook once (the module exports _CONDA_ROOT,
# currently /mnt/software/cbi/software/miniforge3-26.3.2-3):
source "$_CONDA_ROOT/etc/profile.d/conda.sh"

# Keep envs and package cache OFF the 20 GiB home:
mkdir -p /mnt/scratch/user/$USER/{envs,pkgs}
conda config --append envs_dirs /mnt/scratch/user/$USER/envs
conda config --append pkgs_dirs /mnt/scratch/user/$USER/pkgs
conda config --set channel_priority strict     # conda-forge only, cleaner solves
cat ~/.condarc
```

The wiki writes `/scratch/user/...`; `/mnt/scratch/user/...` is the real
path. Optionally `conda init bash` once, but CoreHPC's own admin notes
recommend NOT auto-activating conda in login shells; instead source the
hook inside job scripts.

Beware: scratch is purged after 30 days of inactivity. An env you have not
touched in a month can vanish. Always keep an `environment.yml` export on
FAC (`$CHPC_LAB/envs/`) so it can be recreated in minutes. Recreate on the
login node (compute nodes have no internet).

### Daily use

```bash
conda create -n proj python=3.11
conda activate proj
conda install numpy pandas matplotlib            # conda-forge is the default channel
conda install -c conda-forge -c bioconda samtools
pip install some-pypi-only-package               # pip last, after conda packages
conda env export > environment.yml               # save it to $CHPC_LAB/envs/proj.yml
conda env create -f environment.yml              # rebuild anywhere
conda env list ; conda list ; conda remove -n proj --all
```

`mamba` is available in Miniforge and is much faster: substitute `mamba`
for `conda` in create/install commands.

### In a job script

```bash
module load CBI miniforge3
source "$_CONDA_ROOT/etc/profile.d/conda.sh"    # the wiki's /opt/ohpc/pub/miniforge3 path no longer exists
conda activate proj
srun python script.py
```

### PyTorch / CUDA in conda

Install the CUDA-enabled build from conda-forge or PyPI on the login node
(`pip install torch --index-url https://download.pytorch.org/whl/cu128` or
`conda install pytorch pytorch-cuda=12.x -c pytorch -c nvidia`), then test
in a GPU interactive job: `python -c 'import torch; print(torch.cuda.is_available())'`.
Point caches at scratch: `export PIP_CACHE_DIR=/mnt/scratch/user/$USER/pip HF_HOME=/mnt/scratch/user/$USER/hf`.

### Migrating an Anaconda env from Wynton

`conda env export --no-builds > env.yml` on the old system, remove
`defaults` from `channels:` (keep `conda-forge` first), fix the `prefix:`
line or delete it, then `conda env create -f env.yml` on CoreHPC. Old envs
may not solve; recreate manually if so.

## Jupyter kernels for Open OnDemand

```bash
conda activate proj
conda install ipykernel
python -m ipykernel install --user --name proj --display-name "Python (proj)"
jupyter kernelspec list
```

The kernelspec lands in `~/.local/share/jupyter/kernels/` and shows up in
OnDemand's JupyterLab. R: `conda install r-irkernel` then
`R -e 'IRkernel::installspec(name="proj-r", displayname="R (proj)")'`.

## Three ways Lmod breaks in a script

All three were hit while wiring `chpc-tool`'s `KIND=module` support, and all
three look like a missing or broken module rather than what they are. Verified
on the login node 2026-09-17.

**Never pipe `module load`.** `module` is a shell *function*, and
`module load CBI | head` runs it in a subshell, so the environment change never
reaches you. It looks exactly like the module not existing.

**Do not re-source `/etc/profile.d/lmod.sh` if Lmod is already there.** bash
exports both the `module` function and `MODULEPATH` to child processes, so a
script started from a login shell already has a working, fully populated Lmod.
Sourcing the init again rebuilds `MODULEPATH` from the system default and drops
`/etc/modulefiles` and `/etc/scl/modulefiles` from the front of it — which is
where the `CBI`, `Sali` and `RAD` collections live. The symptom is

```
Lmod has detected the following error: These module(s) or extension(s) exist
but cannot be loaded as requested: "Sali"
```

which reads like a broken modulefile and is really a `MODULEPATH` the script
destroyed one line earlier. Guard it with `command -v module`. A script that
must work from a genuinely empty environment should prepend those two
directories itself rather than re-initialise.

**`/etc/profile.d/lmod.sh` is not `set -u` clean.** It reads `$SLURM_NODELIST`
unguarded at line 10, so sourcing it under `set -u` outside a job dies with
`SLURM_NODELIST: unbound variable`. Wrap the source in `set +u` / `set -u`.

**Collections are a hierarchy, and load in order.** `module load Sali dssp/2.2.1`
as a single command fails: `dssp` is not visible until `Sali` is loaded. Load
them one at a time.

## When to use what

| Need | Use |
|------|-----|
| Compilers, MPI, CUDA toolkit | modules |
| Python/R stack for one project | conda env on scratch, `.yml` on FAC |
| Reproducible, shareable, complex or fragile stack (deep-learning tools, bio pipelines, anything with system libs) | Apptainer container (doc 07) |
| Tool already in the CBI/Sali/RAD collections | `module load CBI` then `module avail` |
| MOE | native install on FAC: `/mnt/fac/CX500146_DS1/software/moe2024.0601` (with `license.dat`, `custom/hpc.cfg`); jobs in `moejobs/` |
