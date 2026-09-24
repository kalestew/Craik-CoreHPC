# 4. Batch jobs with sbatch

Ready-to-edit templates live in `templates/slurm/`. This doc explains the
pieces. Wiki sources: Access Primer, Submission Examples, Advanced Topics.

## Anatomy of a job script

```bash
#!/bin/bash
#SBATCH --job-name=myjob
#SBATCH --partition=cpu              # cpu (default) | gpu | community | community_short   (pod, large_gpu: not ours)
#SBATCH --qos=cmnt_short             # ONLY for community_short; other partitions take our default QoS hpc_core
#SBATCH --nodes=1
#SBATCH --ntasks=1                   # processes (MPI ranks); = --nodes for one task per node
#SBATCH --cpus-per-task=8            # threads per process
#SBATCH --mem=32G                    # per node (or --mem-per-cpu=4G)
#SBATCH --time=04:00:00              # D-HH:MM:SS; default 1 h; max 96 h cpu/gpu, 14 d community, 1 h community_short
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
Bind each process to its closest GPU: `--gpu-bind=closest`. See doc 08 for
two-GPU jobs. The lab has no POD or large_gpu access.

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

- Test interactively, then submit. Use `community_short` (1 h, needs
  `--qos=cmnt_short`) for smoke tests; it started our test job in seconds.
- Serial or embarrassingly parallel CPU work belongs on `community`: same
  QoS we already have, 14-day limit, and the queue is empty while `cpu`
  routinely has ~1000 pending jobs. Keep MPI on `cpu` (InfiniBand).
- Request what you need with a buffer; over-asking slows your start and
  hurts fair-share. Check `sacct ... MaxRSS,TotalCPU` afterwards and tune.
- Use arrays, not loops of `sbatch`.
- Read inputs from scratch; stage big inputs from FAC once.
- Write logs to a `logs/` dir on scratch, not home.
- Prefer containers or exported conda envs so a lab-mate can rerun it.
- Clean up `/tmp` and intermediate scratch files at the end of the job.

## Right-sizing a job you have already run

`chpc-jobstats <jobid>` reads a finished job's own accounting and prints what
it should have asked for. `--tasks` lists every array task, `--mine` sweeps
the last week.

The two numbers that matter are not sacct columns. CPU efficiency is
`TotalCPU / (Elapsed x NCPUS)`, and memory is recorded on steps, separate from
the allocation row carrying the job's state. The tool joins step memory to
allocations without counting step CPU a second time and refuses to count a
task that is not `COMPLETED` -- a RUNNING task's
TotalCPU is sampled on a poll interval and lags its Elapsed, and a PENDING one
reports `NCPUS=0`. `sacct --array` expands pending ranges so task counts stay
accurate. Missing RSS, failed tasks, multiple nodes, numbered steps, or mixed
core requests suppress sizing recommendations: MaxRSS is a per-task peak,
not total memory across MPI ranks. See the [Slurm accounting definitions](https://slurm.schedmd.com/sacct.html).

Measured examples from the IgGase campaign, all three of them single-threaded
programs that had been given 2-4 cores:

| stage             | asked | used  | mem asked | mem high-water |
|-------------------|-------|-------|-----------|----------------|
| Rosetta cartesian_ddg | 2 | 0.99  | 8 G       | 778 M          |
| Rosetta FastRelax | 4     | 0.99  | 16 G      | 676 M          |
| FoldX BuildModel  | 2     | 0.99  | 8 G       | 143 M          |

Read a DISTRIBUTION, never one task. Over 60 ddG tasks the median was 422 M
and the max 778 M -- 1.8x apart -- so sizing memory off the first task that
finished would have set a limit 2.6x over the real peak while looking like
4.7x.

Over-asking for memory does not waste RAM so much as cap how many tasks fit
per node, which is what binds an array before cores do. Over-asking for cores
is billed: `AllocTRES` on this cluster shows `billing=cpu`.

### Arrays, throttles, and what a `%N` means

`%N` limits simultaneous array tasks. For these one-task jobs,
`N x cpus-per-task` gives the maximum core footprint of one array. Limits may
come from both the partition QoS and the job QoS; inspect both:

```
sacct -j <id> --format=JobID,QOS,AllocTRES%40      # what your job ran under
scontrol show partition cpu | tr ' ' '\n' | grep QoS
sacctmgr -nP show qos format=Name,MaxTRESPU%40,MaxJobsPU
```

On `cpu` that is the `cpu` QoS at `cpu=2048,node=8` per user, while the job's
own `hpc_core` QoS declares no limits at all. A throttle set to a number
nobody can source is the common case and it is expensive: one array here sat
at `%20` -- 40 of 2048 permitted cores, 2% -- for eleven hours on a partition
with 10,000 idle cores, because `%20` had been copied from a template.

Pick `throttle x cpus-per-task` as a fixed fraction of the core cap and
keep it the same across stages, so a stage that needs 8 cores a task gets a
proportionally smaller `%N` instead of eight times the footprint. This does
not reserve those cores or guarantee placement within eight nodes. Other jobs,
other arrays and fragmentation can still cause QoS waits. See [Slurm array
throttles](https://slurm.schedmd.com/job_array.html).

### Array or fork? The bookends decide, not the overhead

Per-job scheduler overhead is not the reason to choose. Measured here: a task
reaches its first line of real work about **2 seconds** after Slurm starts it,
which is 0.1% of a 37-minute task. Packing work into fewer, fatter jobs to
save that is optimising the wrong thing, and it costs you per-task restart and
per-task failure isolation.

What decides it is whether the work has serial bookends.

- **Array** when each unit is independent end to end. Failures are isolated,
  each task restarts on its own, and the scheduler backfills small jobs far
  more easily than one large allocation.
- **Fork inside one job** (`&` plus `wait`, one process per allocated core)
  when a shared prologue must run before every unit and a shared epilogue
  after all of them. An array would need a barrier between those, which means
  a second job and a second dependency edge; a forking job gets it for free
  because the bookends are the top and bottom of the script.

Both patterns are in `templates/slurm/`. Neither helps a program that is
genuinely multi-threaded -- check first, because efficiency near `1/N` cannot
tell "single-threaded" from "had nothing to do this run". Rosetta prints
`extras: []` in its banner for a serial build.

### `community` is empty and almost nobody uses it

Measured 2026-09-24: `cpu` had 720 jobs pending against 833 running, while
`community` had **0 pending and 7,584 of 7,680 cores idle**. Same `hpc_core`
association, `cmnt` QoS at `cpu=768,node=8`, and a 14-day limit against
`cpu`'s 4-day.

For serial or embarrassingly parallel CPU work this is usually the better
queue. The caveat is hardware, not policy: `community` nodes are 96-core /
256 G (`ccpu1-*`) where `cpu` nodes are 336-512 core / 1.5 T (`gcpu2-*`), and
neither exposes a CPU model through `Features`, so per-core speed is not
knowable from the scheduler. Before moving a long campaign, run the same task
on both and compare `Elapsed`:

```
sbatch --partition=community --array=0-3 my.sbatch
sbatch --partition=cpu       --array=0-3 my.sbatch
chpc-jobstats <id1> --tasks; chpc-jobstats <id2> --tasks
```

A partition is one line in the header, so this is cheap to test and cheap to
revert. Do not move a campaign mid-flight on the queue depth alone -- a slower
core makes every task longer for as long as the campaign runs.
