# 4. Batch jobs with sbatch

A **batch job** is a script that Slurm runs on a compute node when resources
are available. You submit it from the login node with `sbatch`; it keeps
running if you disconnect, close your laptop, or leave for the day. This is
the usual way to run a structure prediction. First try the tiny job below,
then follow the [P1B7 / 8UDR walkthrough](11-p1b7-walkthrough.md) for Boltz,
Protenix and Chai-1.

If the batch script and inputs are on your laptop, the
[Globus submission helper](11-p1b7-walkthrough.md#submit-from-your-laptop-with-globus)
transfers the job folder, waits for completion, and runs `sbatch` on the
cluster for you. The steps below teach the same scheduler commands from
an SSH session.

Ready-to-edit templates live in [`templates/slurm/`](../templates/slurm/).
[`tool-gpu.sbatch`](../templates/slurm/tool-gpu.sbatch) runs a lab registry
tool; [the tool guide](../tools/README.md) explains its settings. Wiki sources
for this page: Access Primer, Submission Examples, Advanced Topics.

## Your first batch job

This practice run uses one CPU for a few seconds. It checks that you can
submit a job, find its log and confirm that it finished. It needs no Python
installation, structure files, GPU or downloaded model weights.

### 1. Connect and make a working folder

**On your laptop:**

```bash
ssh chpc
```

**On the login node:**

```bash
hostname
mkdir -p "/mnt/scratch/user/$USER/corehpc-first-job/logs"
cd "/mnt/scratch/user/$USER/corehpc-first-job"
pwd
```

Check that the hostname contains `chpc-ucsf-login-vm1` and the working folder
ends in your username followed by `/corehpc-first-job`. These files live in
your own scratch directory. Scratch is temporary storage; keep valuable
results on FAC as explained in [storage and data movement](02-storage-and-data.md).

### 2. Create the script

**Still on the login node**, paste the entire block, from `cat` through the
last `EOF`, then press Return. It writes a text file called `hello.sbatch`;
repeating it replaces that practice file. `EOF` is a delimiter marking the
end of the file contents, not a command you run separately.

```bash
cat > hello.sbatch <<'EOF'
#!/bin/bash
#SBATCH --job-name=corehpc_hello
#SBATCH --partition=community_short
#SBATCH --qos=cmnt_short
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#SBATCH --time=00:05:00
#SBATCH --output=logs/%x_%j.out

set -euo pipefail
printf 'Job ID: %s\n' "$SLURM_JOB_ID"
printf 'Compute node: '
hostname
printf 'Working directory: '
pwd
srun bash -c 'date; sleep 15; echo "Practice job finished successfully."'
EOF
```

The `#SBATCH` lines ask Slurm for resources. `community_short` needs the
matching `cmnt_short` QoS. `--time=00:05:00` is a five-minute **limit**, not a
request to run for exactly five minutes. All later lines are the commands
the compute node will execute. `%x` and `%j` become the job name and unique
job ID in the log filename. Errors go into the same log.

Review the file you created:

```bash
cat hello.sbatch
```

### 3. Submit once and save the job ID

**On the login node, in the same folder:**

```bash
sbatch --test-only hello.sbatch
```

This checks whether Slurm accepts the request without submitting a job. It
does not run or validate the program in the script. If it reports an error,
resolve that before continuing. Then submit:

```bash
JOB_ID=$(sbatch --parsable hello.sbatch)
printf '%s\n' "$JOB_ID" > last-job-id.txt
printf 'Submitted job %s\n' "$JOB_ID"
```

Expect a numeric job ID, such as `1999999` (your number will differ). Each
`sbatch` call submits a **new** job, even if the filename is unchanged. Do
not keep resubmitting while you wait. If submission fails or no job ID is
printed, stop and read the error instead of using the following commands.

### 4. Check the queue and read the output

```bash
squeue -j "$JOB_ID" -o "%.18i %.16j %.10T %.10M %R"
```

`PENDING` means waiting; `RUNNING` means the compute node has started your
script. A reason such as `Priority` or `Resources` is normal while waiting.
A very short job may already have disappeared from `squeue`; that alone
does not say whether it succeeded or failed.

The log appears only after the job starts. List the logs:

```bash
ls -lh logs/
```

Once `corehpc_hello_` followed by your job ID appears, read it:

```bash
cat "logs/corehpc_hello_${JOB_ID}.out"
sacct -j "$JOB_ID" --format=JobID,JobName,State,ExitCode,Elapsed
```

A successful run prints a compute hostname, the scratch folder and
`Practice job finished successfully.` The allocation row in `sacct` should
say `COMPLETED` with `ExitCode` `0:0`. Additional `.batch`, `.extern` and
`.0` rows describe parts of the same job. Accounting can take a short time
to update; check again if the job has just finished.

For a longer run, watch new log lines as they arrive:

```bash
tail -f "logs/corehpc_hello_${JOB_ID}.out"
```

Press **Control-C** to stop watching. That stops `tail`, not the submitted
job. If a log does not exist yet, check `squeue`; a pending job has not opened
its log. If the job finished with `FAILED`, `TIMEOUT` or `OUT_OF_MEMORY`,
read the end of its log before resubmitting.

### 5. Reconnect or cancel when needed

You may type `exit` to disconnect after submission; the batch job continues.
After `ssh chpc` in a new terminal, return to the working folder and reload
the saved job ID (`JOB_ID` variables do not survive a new shell):

```bash
cd "/mnt/scratch/user/$USER/corehpc-first-job"
JOB_ID=$(cat last-job-id.txt)
squeue -u "$USER"
sacct -j "$JOB_ID" --format=JobID,JobName,State,ExitCode,Elapsed
```

If you deliberately want to stop **this** pending or running job:

```bash
scancel "$JOB_ID"
```

Cancellation can take a moment. Check `squeue` or `sacct` again; a completed
job cannot be canceled. Do not use `scancel -u "$USER"` unless you intend to
stop **all** of your jobs, including unrelated work.

Once this practice job succeeds, continue to the
[P1B7 structure-prediction walkthrough](11-p1b7-walkthrough.md). The same
submit → job ID → log → completion checks apply there; the scientific inputs
and GPU resources are different.

## Anatomy of a job script

The following is a reference for a larger CPU job, **not another practice
script to submit unchanged**. Replace `my_script.py` and the module name
with your program's instructions. Put all `#SBATCH` directives before the
first executable shell command. Slurm reads these directives itself and
does not expand shell variables such as `$USER` in them; use relative log
paths or write the full path. See the official
[`sbatch` reference](https://slurm.schedmd.com/sbatch.html).

```bash
#!/bin/bash
#SBATCH --job-name=myjob
#SBATCH --partition=cpu              # cpu (default) | gpu | community | community_short   (pod, large_gpu: not ours)
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

- For `cpu`, `gpu` and `community`, the lab's default `hpc_core` QoS works.
  Only `community_short` requires adding `#SBATCH --qos=cmnt_short`.
- Command-line flags override `#SBATCH` lines: `sbatch --mem=64G job.sh`.
- `srun` inside the script is recommended by CoreHPC so SLURM manages the
  process lifecycle; for a plain serial command it is optional.
- `sbatch --wrap 'cmd'` submits a one-liner without a script.
- `sbatch --test-only job.sh` estimates when it would start without submitting.
- The submit directory becomes the job's working directory; make `logs/` first.

## Requesting GPUs

For registry tools, start with [the GPU job template](../templates/slurm/tool-gpu.sbatch)
and the [P1B7 walkthrough](11-p1b7-walkthrough.md). The following is only the
GPU-specific fragment of a script, not a complete runnable job:

```bash
#SBATCH --partition=gpu
#SBATCH --gres=gpu:nvidia_l40s:1     # supported by every current lab registry tool
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
module load nvidia-hpc               # CUDA toolchain (see doc 06); conda/containers bring their own CUDA runtime
srun python train.py
```

`--gres=gpu:1` requests any GPU and may select an architecture unsupported by
your container; check [GPU compatibility](../tools/README.md#which-gpu) first.
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
`module load nvidia-hpc; module load nvhpc-hpcx` (defaults to 26.5). The
primer's `nvhpc-hpcx/25.5` does **not** exist here -- the collection carries
25.1 and 26.5 only, so copying that line fails. Check with `module spider`.
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

Run these commands on the login node. The table below is a reference:
replace `<id>` with your actual numeric job ID, including removing the angle
brackets. Unlike the copyable first-job blocks, it uses placeholders.

| Task | Command |
|------|---------|
| Queue (yours) | `squeue -u $USER` ; `squeue -u $USER --start` for estimated start |
| Why pending | `squeue -j <id> -o "%i %T %r"` ; `scontrol show job <id>` |
| Priority breakdown | `sprio -j <id>` |
| Node states | `sinfo` ; `sinfo -Nel` ; `sinfo -o "%P %n %e %m %a %c %C %G"` |
| Live efficiency | `sstat -j <id> --format=JobID,MaxRSS,AveCPU` |
| After completion | `sacct -j <id> --format=JobID,JobName,Partition,State,Elapsed,TotalCPU,MaxRSS,ReqMem,AllocTRES%40` |
| Efficiency summary | `seff <id>` — one-screen CPU/memory utilisation vs request |
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
- Fair-share charges you for what you consume, so *fewer, larger* jobs leave
  you with more priority afterwards than many small ones doing the same work.
  An array is one submission but N tasks, and the tasks are what fair-share
  counts -- so throttle with `--array=1-N%k` and batch several units of work
  per task rather than emitting one task per unit. The CoreHPC training made
  this point explicitly on 2026-09-11.
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
reports `NCPUS=0`.

It asks for `--array` so a pending range is expanded rather than collapsed into
one row, and falls back to a plain query if this `sacct` build does not take
that option, saying so: without it a core estimate off a running array
undercounts. Do not assume the flag is accepted, and do not let one go
unverified into a tool that runs under `set -euo pipefail` -- an unrecognised
option exits non-zero and takes the whole invocation with it, and a test
harness whose `sacct` is a `cat` cannot catch it.

Each recommendation is gated on its OWN accounting, because they are measurable
independently. No MaxRSS withholds the memory suggestion alone; CPU efficiency
still reports, and it is the number that showed these tools are single-threaded.
A failed or timed-out task, more than one node, numbered `srun` steps or mixed
core requests withhold both: a killed task's peak is unknown, one efficiency
over differing core counts means nothing, and MaxRSS is a per-task peak rather
than total memory across MPI ranks. See the [Slurm accounting definitions](https://slurm.schedmd.com/sacct.html).

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
