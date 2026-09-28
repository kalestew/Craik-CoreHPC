#!/bin/bash
# Submit from your scratch copy of examples/p1b7, on the LOGIN node:
#   mkdir -p logs
#   sbatch p1b7.sbatch boltz
#   sbatch p1b7.sbatch rf3
#   sbatch p1b7.sbatch chai1 template
#   sbatch p1b7.sbatch protenix template
# See docs/11-p1b7-walkthrough.md. Each tool/mode needs a fresh output directory.
# These are starting requests, not measured requirements for this full Fab.
#SBATCH --job-name=p1b7
#SBATCH --account=hpc_core
#SBATCH --partition=gpu
#SBATCH --gres=gpu:nvidia_l40s:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x_%j.out
set -euo pipefail

if [ -n "${COREHPC:-}" ]; then
    [ -r "$COREHPC/env.sh" ] || { echo "Cannot read $COREHPC/env.sh; COREHPC must be a cluster path." >&2; exit 1; }
    source "$COREHPC/env.sh"
    echo "Registry: checkout $COREHPC"
    git -C "$COREHPC" rev-parse HEAD
else
    # Laptop dispatch uses the shared installation, without requiring a
    # second clone in the user's cluster home or copying a Mac path here.
    CHPC_ENV="${CHPC_ENV:-/mnt/fac/${FAC_SHARE:-CX500146_DS1}/chpc.env}"
    source "$CHPC_ENV"
    echo "Registry: shared installation ($CHPC_ENV)"
fi
cd "${SLURM_SUBMIT_DIR:?Submit this script with sbatch from your scratch run directory}"
if [ ! -r run.sh ] || [ ! -r manifest.json ]; then
    echo "Submit from your scratch copy of examples/p1b7, not from the repository root." >&2
    exit 1
fi
if [ "$#" -eq 0 ]; then
    echo "Choose a tool: sbatch p1b7.sbatch boltz|chai1|protenix|rf3 [template]" >&2
    exit 1
fi

date -Is
hostname
printf 'Job: %s\nWork directory: %s\n' "$SLURM_JOB_ID" "$PWD"
# rf3 has no registry entry of its own yet: it is a second program inside the
# rfdiffusion3 image, so that is the entry whose placement and weights matter.
entry="$1"
if [ "$entry" = rf3 ]; then entry=rfdiffusion3; fi
chpc-tool show --env "$entry"
nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader
srun -u bash run.sh "$@"
echo "Prediction and tutorial checks finished. Save this directory to FAC."
