# 4. Batch jobs with sbatch

Ready-to-edit templates live in `templates/slurm/`. This doc explains the
pieces. Wiki sources: Access Primer, Submission Examples, Advanced Topics.

## Anatomy of a job script

```bash
#!/bin/bash
#SBATCH --job-name=myjob
#SBATCH --partition=cpu              # cpu (default) | gpu | pod | large_gpu | community | community_short
#SBATCH --nodes=1
#SBATCH --ntasks=1                   # processes (MPI ranks); = --nodes for one task per node
#SBATCH --cpus-per-task=8            # threads per process
#SBATCH --mem=32G                    # per node (or --mem-per-cpu=4G)
#SBATCH --time=04:00:00              # D-HH:MM:SS; partition max: 96 h (cpu/gpu/pod), 24 h large_gpu, 336 h community
#SBATCH --output=logs/%x_%j.out      # %x job name, %j job id, %A/%a array id/task
#SBATCH --error=logs/%x_%j.err       # omit to merge into --output
#SBATCH --mail-type=END,FAIL         # optional
#SBATCH --mail-user=you@ucsf.edu

set -euo pipefail
module purge
module load <what you need>
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

srun -u python my_script.py          # srun lets SLURM track the step; -u = unbuffered output
```

- Command-line flags override `#SBATCH` lines: `sbatch --mem=64G job.sh`.
- `srun` inside the script is recommended by CoreHPC so SLURM manages the
  process lifecycle; for a plain serial command it is optional.
- `sbatch --wrap 'cmd'` submits a one-liner without a script.
- `sbatch --test-only job.sh` estimates when it would start without submitting.
- The submit directory becomes the job's working directory; make `logs/` first.

## Requesting GPUs

```bash
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1                 # any GPU; gpu:nvidia_h100_nvl:1 for a specific model
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
module load nvidia-hpc               # CUDA toolchain (see doc 06); conda/containers bring their own CUDA runtime
srun python train.py
```

Multiple GPUs on one node: `--gres=gpu:2` (gpu partition nodes have 1–2).
Bind each process to its closest GPU: `--gpu-bind=closest`. For 8+ GPUs
and multi-node see doc 08 (POD, `--account=ucsf_pod --qos=pod`).

## Job arrays

```bash
#SBATCH --array=1-100%20             # tasks 1..100, at most 20 running at once
#SBATCH --output=logs/%x_%A_%a.out
INPUT=$(sed -n "${SLURM_ARRAY_TASK_ID}p" inputs.txt)
srun python process.py "$INPUT"
```

Throttle large campaigns (`%N`); CoreHPC asks you to talk to them before very
large runs. `scancel <arrayid>` cancels all tasks; `scancel <arrayid>_<n>` one.

## Dependencies and pipelines

```bash
jid1=$(sbatch --parsable preprocess.sbatch)
jid2=$(sbatch --parsable --dependency=afterok:$jid1 train.sbatch)
sbatch --dependency=afterok:$jid2 evaluate.sbatch
```

Types: `afterok` (success), `afternotok` (failure), `afterany` (finished),
`singleton` (one job of this name at a time).

## MPI and multi-node

OpenMPI 5 (`openmpi5/5.0.7`) and `gnu14` are loaded by default at login.

```bash
#SBATCH --partition=cpu
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=8
#SBATCH --cpus-per-task=1
srun ./mpi_program                    # use srun, not mpirun
```

If the program was built with the NVIDIA HPC SDK MPI:
`module load nvidia-hpc; module load nvhpc-hpcx` (the primer shows
`module load nvidia/nvhpc/nvhpc-hpcx/25.5` as an alternative full path).
Hybrid MPI+OpenMP: `--ntasks-per-node=8 --cpus-per-task=4` and
`export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK`. Community nodes have no
InfiniBand: do not run MPI there.

## Checkpoint and requeue

```bash
#SBATCH --requeue
#SBATCH --signal=B:SIGTERM@120        # get SIGTERM 120 s before the limit
trap 'save_checkpoint; exit 0' SIGTERM
```

## Monitoring

| Task | Command |
|------|---------|
| Queue (yours) | `squeue -u $USER` ; `squeue -u $USER --start` for estimated start |
| Why pending | `squeue -j <id> -o "%i %T %r"` ; `scontrol show job <id>` |
| Priority breakdown | `sprio -j <id>` |
| Node states | `sinfo` ; `sinfo -Nel` ; `sinfo -o "%P %n %e %m %a %c %C %G"` |
| Live efficiency | `sstat -j <id> --format=JobID,MaxRSS,AveCPU` |
| After completion | `sacct -j <id> --format=JobID,JobName,Partition,State,Elapsed,TotalCPU,MaxRSS,ReqMem,AllocTRES%40` |
| Cancel | `scancel <id>` ; `scancel -u $USER` ; `scancel --name=myjob` |
| Hold / release | `scontrol hold <id>` ; `scontrol release <id>` |
| Scheduler config | `scontrol show partition` ; `sacctmgr show qos` ; `sacctmgr show assoc user=$USER` |

Node state codes: `idle`, `mix` (partly allocated), `alloc`, `drain`/`drng`
(taken out for maintenance), `down`, `down*` (slurmd unreachable), `maint`,
`resv` (reserved), `plnd`, `comp` (completing).

## Environment variables inside a job

`SLURM_JOB_ID`, `SLURM_JOB_NAME`, `SLURM_JOB_PARTITION`, `SLURM_JOB_NODELIST`
(`scontrol show hostnames $SLURM_JOB_NODELIST` expands it), `SLURM_JOB_NUM_NODES`,
`SLURM_NTASKS`, `SLURM_CPUS_PER_TASK`, `SLURM_ARRAY_JOB_ID`, `SLURM_ARRAY_TASK_ID`,
`SLURM_GPUS_PER_NODE`, `CUDA_VISIBLE_DEVICES`, `SLURM_SUBMIT_DIR`.

## Good practice (CoreHPC's list plus ours)

- Test interactively, then submit. Use `community_short` (1 h) for smoke tests.
- Request what you need with a buffer; over-asking slows your start and
  hurts fair-share. Check `sacct ... MaxRSS,TotalCPU` afterwards and tune.
- Use arrays, not loops of `sbatch`.
- Read inputs from scratch; stage big inputs from FAC once.
- Write logs to a `logs/` dir on scratch, not home.
- Prefer containers or exported conda envs so a lab-mate can rerun it.
- Clean up `/tmp` and intermediate scratch files at the end of the job.
