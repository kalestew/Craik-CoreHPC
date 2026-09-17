# 9. SGE (Wynton) to SLURM (CoreHPC)

From the wiki's translator page, trimmed to what the lab uses. Wynton
retires by February 2027; protected-data accounts closed January 2026.

## Commands

| Task | SGE | SLURM | Notes |
|------|-----|-------|-------|
| Submit batch job | `qsub job.sh` | `sbatch job.sh` | |
| Interactive job | `qsub -I` / `qlogin` | `salloc ...` or `srun ... --pty bash` | |
| Memory | `-l mem_free=5G` | `--mem=8G` (per node) or `--mem-per-cpu=4G` | SGE was per slot |
| Walltime | `-l h_rt=01:00:00` | `--time=01:00:00` | |
| Queue | `-q short.q` | `-p community_short` | queues = partitions |
| Job name | `-N name` | `-J name` / `--job-name` | |
| stdout / stderr | `-o out -e err` / `-j y` | `-o out -e err`; only `-o` merges | |
| CPUs | `-pe smp 8` | `--cpus-per-task=8` | |
| MPI ranks | `-pe mpi 32` | `--ntasks=32` | launch with `srun`, not `mpirun` |
| GPU | `-l gpu=1` (`gpu.q`) | `-p gpu --gres=gpu:1` | |
| Exclusive node | `-l exclusive` | `--exclusive` | |
| List jobs | `qstat` / `qstat -u '*'` | `squeue -u $USER` / `squeue` | |
| Job detail | `qstat -j id` | `scontrol show job id` | |
| History | `qacct -j id` | `sacct -j id` | |
| Delete | `qdel id` | `scancel id` | |
| Hold / release | `qhold` / `qrls` | `scontrol hold` / `scontrol release` | |
| Requeue | `qmod -rj id` | `scontrol requeue id` | |
| Array | `-t 1-100` | `--array=1-100` | |
| Array throttle | `-t 1-100 -tc 10` | `--array=1-100%10` | |

## Variables

| SGE | SLURM |
|-----|-------|
| `$JOB_ID` | `$SLURM_JOB_ID` |
| `$JOB_NAME` | `$SLURM_JOB_NAME` |
| `$QUEUE` | `$SLURM_JOB_PARTITION` |
| `$PE_HOSTFILE` | `$SLURM_JOB_NODELIST` (`scontrol show hostnames`) |
| `$SGE_TASK_ID` | `$SLURM_ARRAY_TASK_ID` |
| `$NSLOTS` | `$SLURM_CPUS_PER_TASK` (or `$SLURM_NTASKS`) |
| `$TMPDIR` | `/tmp` on the node (make your own subdir) |

## Script side by side

```bash
# SGE (Wynton)                       # SLURM (CoreHPC)
#!/bin/bash                          #!/bin/bash
#$ -N myjob                          #SBATCH -J myjob
#$ -q short.q                        #SBATCH -p community_short
#$ -pe smp 8                         #SBATCH --cpus-per-task=8
#$ -l h_rt=01:00:00                  #SBATCH --time=01:00:00
#$ -l h_vmem=4G                      #SBATCH --mem-per-cpu=4G
#$ -o out.txt -e err.txt             #SBATCH -o out.txt -e err.txt
./my_program                         srun ./my_program
```

## Behavioural differences that bite

- SLURM memory is per node by default; `--mem` too small = OOM-kill, shown
  as `OUT_OF_MEMORY` in `sacct`.
- No `-cwd` needed; SLURM starts in the submit directory.
- Wynton's `/wynton/scratch` and `/wynton/group` have no crossover. Data
  must be moved via Globus or the FAC share (doc 02).
- Long jobs: `community` allows 336 h; `cpu`/`gpu` stop at 96 h. Add
  checkpointing.
- CBI modules exist on CoreHPC too (`module load CBI`), but the software
  list is not identical; check `module avail` after loading.
