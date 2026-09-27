# 3. Interactive jobs

An interactive job gives you a terminal on a **compute node** for testing or
debugging. Slurm, the cluster's scheduler, reserves the requested resources
until you exit or your time limit runs out. Use a
[batch job](04-batch-jobs.md) for a long prediction that should run while your
laptop is closed. The [P1B7 / 8UDR walkthrough](11-p1b7-walkthrough.md) uses
batch jobs for the structure-prediction runs.

## First, check where you are

**On your laptop**, connect as described in [access and SSH](01-access-and-ssh.md):

```bash
ssh chpc
```

**On the login node:**

```bash
hostname
whoami
```

The hostname should contain `chpc-ucsf-login-vm1`. The login node is where you
request a job; the compute node is where you run calculations. Download
inputs and model weights on the login node before requesting a compute
session: compute nodes cannot fetch them from the internet.

## Get a shell on a CPU node

**On the login node**, paste the whole command:

```bash
srun --partition=community_short --qos=cmnt_short --nodes=1 --ntasks=1 \
  --cpus-per-task=2 --mem=4G --time=00:15:00 --pty bash -l
```

This requests one task, two CPU cores, 4 GB of memory and 15 minutes.
`community_short` is suitable for a short CPU practice session and requires
`--qos=cmnt_short`. The terminal may say the job is queued and then wait;
that means Slurm is finding resources, not that the terminal is broken.
Wait for a new shell prompt. To abandon the request while it is waiting,
press Control-C.

**Now in the allocated shell**, check before running any calculation:

```bash
hostname
printf 'Job ID: %s\n' "$SLURM_JOB_ID"
pwd
```

Expect a compute hostname such as `ccpu1-01` and a numeric job ID. If the
hostname still says `chpc-ucsf-login-vm1`, stop: you have not reached a compute
shell. Your home and scratch files are shared, so changing nodes does not
require another copy of those files.

For a scratch working directory and a harmless first command:

```bash
mkdir -p "/mnt/scratch/user/$USER/corehpc-practice"
cd "/mnt/scratch/user/$USER/corehpc-practice"
date > interactive-check.txt
cat interactive-check.txt
```

`>` writes the command's output into a file (replacing that file if it
already exists); `cat` displays the file. This practice file is safe to
replace. When finished, release the session:

```bash
exit
```

Run `hostname` after the login prompt returns. You should be back on the login node. This `exit` ends the `srun` shell and
releases its allocation; a second `exit` would disconnect from CoreHPC.

For a CPU session with more memory or a longer time limit, use the `cpu`
partition instead:

```bash
srun --partition=cpu --nodes=1 --ntasks=1 --cpus-per-task=4 \
  --mem=8G --time=01:00:00 --pty bash -l
```

Long serial CPU work can use `community` (up to 14 days); no special QoS
flag is needed there. Request long production runs with `sbatch`.

### If another guide uses `salloc`

`salloc` reserves resources. **Do not assume that it moves your shell to a
compute node.** Start the compute shell explicitly with `srun` after the
allocation is granted:

```bash
salloc --partition=cpu --nodes=1 --ntasks=1 --cpus-per-task=4 --mem=8G --time=01:00:00
srun --pty bash -l
hostname
```

After your work, `exit` once to leave the compute shell, then `exit` again
to leave the `salloc` shell and release the allocation. The direct
`srun ... --pty bash -l` examples above require only one `exit` and are
easier for your first session. See the official
[`salloc` description](https://slurm.schedmd.com/salloc.html) and
[`srun` reference](https://slurm.schedmd.com/srun.html).

## Get a shell on a GPU node

**From the login node** (exit any existing CPU session first):

```bash
srun --partition=gpu --gres=gpu:nvidia_l40s:1 --nodes=1 --ntasks=1 \
  --cpus-per-task=8 --mem=64G --time=01:00:00 --pty bash -l
```

**Once the compute shell starts:**

```bash
hostname
printf 'Job ID: %s\n' "$SLURM_JOB_ID"
nvidia-smi
```

`nvidia-smi` should display the allocated NVIDIA L40S GPU. If it fails, do
not start a structure prediction; check that the allocation really started.
An allocated GPU stays reserved even when you are not using it, so type
`exit` when done.

The L40S is supported by every current lab registry tool. A request for
`--gres=gpu:1` can land on a Blackwell GPU that some of the lab containers do
not support. See [tool GPU compatibility](../tools/README.md#which-gpu) before
changing the request. `pod` and `large_gpu` are not enabled for the lab.
The lab's containers supply their own CUDA runtime; `module load nvidia-hpc`
is only needed when your specific workflow requires the CUDA toolkit or
compilers.

## Keep the session alive across disconnects

A plain interactive session can end when SSH or the VPN disconnects. If
you need to reconnect to one, first start `tmux` **on the login node**:

```bash
systemd-run --scope --user tmux new -s work
```

`tmux` keeps a terminal session on the server. Inside that session, request
a compute shell as above, for example:

```bash
srun --partition=gpu --gres=gpu:nvidia_l40s:1 --nodes=1 --ntasks=1 \
  --cpus-per-task=8 --mem=64G --time=01:00:00 --pty bash -l
hostname
```

To detach without stopping the session, press **Control-B**, release both
keys, then press **D**. You return to the login shell, while the interactive
job continues to use its resources and walltime. Do not type `exit` inside
the compute shell if you intend to leave it running.

Later, **from your laptop**, reconnect:

```bash
ssh chpc
```

**On the login node:**

```bash
tmux ls
tmux attach -t work
```

If `tmux ls` has no `work` session, check `squeue -u "$USER"` before starting
another allocation; do not assume the previous job is gone. The systemd
scope permits a session to survive logout for up to 24 hours, and it does
not extend the job's walltime. When completely finished, `exit` leaves the
compute shell; another `exit` closes the tmux shell. For overnight production
runs, prefer a batch job: it needs neither SSH nor tmux to stay connected.

## Inspect an already running batch job

Start with the job's log and [batch monitoring commands](04-batch-jobs.md#monitoring).
An extra shell inside an active allocation is an advanced debugging step;
it shares the allocation and does not grant extra resources.

**On the login node**, enter your own running job ID at the prompt:

```bash
squeue -u "$USER"
printf 'Running job ID to inspect: '
read -r JOB_ID
```

After entering the job ID, run:

```bash
srun --jobid="$JOB_ID" --overlap --nodes=1 --ntasks=1 --cpus-per-task=1 --pty bash -l
```

`--overlap` permits this inspection step alongside the main step; run only
lightweight checks in it. On a GPU job, `nvidia-smi` shows GPU utilization.
Type `exit` when finished inspecting. Do not run another prediction inside
this shell or cancel the main job accidentally.

## Jupyter / RStudio / VS Code / MATLAB

[Open OnDemand](https://chpc-ucsf-ondemand-vm1.corehpc.ucsf.edu/) launches these
as interactive Slurm jobs with a form for partition, CPUs, memory, GPUs and
time. Connect VPN before opening the site. Conda environments appear as
kernels once you register them ([Jupyter kernels](06-software-modules-conda.md)).

For a manual Jupyter tunnel, first start Jupyter **inside an allocated
compute shell**:

```bash
hostname
jupyter lab --no-browser --ip=0.0.0.0 --port=8888
```

Leave that command running. In a **second terminal on your laptop**, enter
the compute hostname that the previous `hostname` command printed:

```bash
printf 'Compute hostname running Jupyter: '
read -r COMPUTE_NODE
```

After entering that hostname, run:

```bash
ssh -N -L "8888:$COMPUTE_NODE:8888" chpc
```

Leave the tunnel running and open the `http://localhost:8888/...` URL with
the token printed by Jupyter. When finished, stop Jupyter with Control-C
and confirm its shutdown if prompted, exit the compute shell, then stop
the laptop tunnel with Control-C. Open OnDemand avoids this manual setup.

## Sizing an interactive request

- Ask for what you need plus a margin; larger requests may wait longer.
- `--mem` is memory per node; `--mem-per-cpu` scales with the CPU count.
- Walltime is elapsed time, including idle time after the allocation starts.
  Default walltime is one hour; always pass `--time` explicitly.
- Default memory is 4 GB per CPU (6 GB on `gpu`). `--gres=gpu:1` alone
  defaults to 32 CPUs, so specify `--cpus-per-task` as in the examples.
- The `gpu` partition allows 21 jobs and 8 GPUs per user. An idle interactive
  GPU session still counts against those limits and fair-share usage.
