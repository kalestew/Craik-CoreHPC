# 3. Interactive jobs

Interactive sessions are real SLURM jobs on a compute node. Use them to
test commands, build software that needs CPU, debug, and run notebooks.
Never do that work on the login node.

## Get a shell on a CPU node

```bash
salloc -p cpu --cpus-per-task=4 --mem=8G --time=01:00:00
# prompt changes to the allocated node (e.g. gcpu2-04); run commands normally
exit           # releases the allocation
```

Equivalent with `srun` (the SGE guide prefers this form for interactive shells):

```bash
srun -p cpu --cpus-per-task=4 --mem=8G --time=01:00:00 --pty bash -l
```

Quick throwaway test (1 h max):

```bash
srun -p community_short -c 2 --mem 4G --pty bash -l
```

## Get a shell on a GPU node

```bash
srun -p gpu --gres=gpu:1 --cpus-per-task=8 --mem=32G --time=02:00:00 --pty bash -l
nvidia-smi                                # confirm the GPU is visible
module load nvidia-hpc                    # CUDA toolkit / compilers if needed
```

Pick a GPU model: `--gres=gpu:nvidia_h100_nvl:1` (see doc 05 for names).

POD (needs approval): add `--account=ucsf_pod --qos=pod -p pod --gres=gpu:8`.

## Keep the session alive across disconnects

Wrap it in tmux on the login node, then `salloc` inside tmux:

```bash
systemd-run --scope --user tmux new -s work    # survives logout up to 24 h
salloc -p gpu --gres=gpu:1 -c 8 --mem 32G -t 8:00:00
# ... work ...
# Ctrl-b d to detach; later: ssh chpc; tmux attach -t work
```

Notes from the FAQ: do not `exit` inside tmux/screen if you want it kept;
`screen -D -R name` creates-or-reattaches; `tmux ls` lists sessions.

## Attach a shell to a running batch job

Useful to inspect GPU utilization or files on the node your job runs on:

```bash
squeue -u $USER                                      # find JOBID and node
srun --jobid=<JOBID> --nodelist=<node> --pty /bin/bash
nvidia-smi --query-compute-apps=pid,process_name,gpu_name,gpu_uuid,used_memory --format=csv | sort -k5
# count GPUs actually in use by the job:
nvidia-smi --query-compute-apps=pid,process_name,gpu_name,gpu_uuid,used_memory --format=csv | awk '{print $5}' | grep GPU | sort -u | wc -l
```

`srun --jobid` steps share the job's allocation, so they cannot use more
than the job requested.

## Jupyter / RStudio / VS Code / MATLAB

Open OnDemand at <https://chpc-ucsf-ondemand-vm1.corehpc.ucsf.edu/> launches
these as interactive SLURM jobs with a form for partition, CPUs, memory,
GPUs and time. Conda environments appear as kernels once you register them
(doc 06, "Jupyter kernels").

Manual Jupyter over an SSH tunnel also works if you prefer:

```bash
# in an interactive job on node NODE:
jupyter lab --no-browser --ip=0.0.0.0 --port=8888
# on your laptop (the chpc alias tunnels through the bastion):
ssh -N -L 8888:NODE:8888 chpc
```

## Sizing an interactive request

- Ask for what you need plus a margin; big requests wait longer.
- `--mem` is per node; `--mem-per-cpu` scales with `-c`.
- Default walltime is partition-dependent; always pass `--time`.
- The `gpu` partition allows 4 jobs and 8 GPUs per user; an idle
  interactive GPU session counts against that and against fair-share.
