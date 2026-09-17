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

Top-level collections seen in `/etc/modulefiles`: `CBI`, `RAD`, `Sali`,
`nvidia-hpc`. These are nested collections: load one, then `module avail`
again to see what it adds. `CBI` (Computational Biology & Informatics, the
same group that ran Wynton's CBI modules) provides Miniforge3 and many
bioinformatics tools. `Sali` is the Sali lab's collection (likely IMP,
modeller, etc.). `nvidia-hpc` provides the NVIDIA HPC SDK (`nvhpc`,
`nvhpc-hpcx` for CUDA-aware MPI, CUDA toolkits). `RAD` is radiology's.

GPU jobs: `module load nvidia-hpc` then `module load nvhpc-hpcx` if you
need CUDA compilers or CUDA-aware MPI. A conda env or container that ships
its own CUDA runtime only needs the driver, which is always present.

Compilers and MPI stacks: `gnu14`, `openmpi5`, `mpich`, `mvapich2`, `cmake`,
`boost`, `papi`, `tau`, `scorep` under `/opt/ohpc/pub`.

Apptainer is installed as a base package; no module is needed (the generic
Apptainer guide's `module load apptainer` line is harmless if it fails,
but on CoreHPC just call `apptainer`).

`scripts/chpc-discover.sh` records the full current module list in
`docs/cluster-facts.md`.

## Miniforge / conda

CoreHPC supports Miniforge3 only. Do not install Anaconda (licensing) and
do not install your own Miniforge in shared locations.

### One-time setup (per user)

```bash
module load CBI
module load miniforge3
conda --version
# if 'conda activate' complains, source the hook once (the module exports _CONDA_ROOT):
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
source "$_CONDA_ROOT/etc/profile.d/conda.sh"    # or: . /opt/ohpc/pub/miniforge3/<ver>/etc/profile.d/conda.sh
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

## When to use what

| Need | Use |
|------|-----|
| Compilers, MPI, CUDA toolkit | modules |
| Python/R stack for one project | conda env on scratch, `.yml` on FAC |
| Reproducible, shareable, complex or fragile stack (deep-learning tools, bio pipelines, anything with system libs) | Apptainer container (doc 07) |
| Tool already in the CBI/Sali collections | `module load CBI` then `module avail` |
