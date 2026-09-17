#!/bin/bash
#SBATCH --job-name=mpi_job
#SBATCH --partition=cpu              # not community (no InfiniBand)
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=32
#SBATCH --cpus-per-task=1
#SBATCH --mem=0                      # all memory on each node
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail
mkdir -p logs
module purge
module load gnu14 openmpi5           # default stack; or: module load nvidia-hpc nvhpc-hpcx

srun ./mpi_program                   # srun, not mpirun
