#!/usr/bin/env bash
# Run from a copied tutorial directory inside a GPU allocation.
# bash run.sh boltz|protenix|chai1|rf3 [none|template] [--dry-run]
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1

usage() {
  echo 'Usage: bash run.sh boltz|protenix|chai1|rf3 [none|template] [--dry-run]'
  echo 'Examples: bash run.sh boltz --dry-run; bash run.sh chai1 template'
}
if [[ $# -eq 0 ]]; then usage; exit 2; fi
tool=$1
shift
mode=none
dry_run=false
for arg in "$@"; do
  case "$arg" in
    none|template) mode=$arg ;;
    --dry-run) dry_run=true ;;
    *) usage >&2; exit 2 ;;
  esac
done
case "$tool" in boltz|protenix|chai1|rf3) ;; *) usage >&2; exit 2 ;; esac
# RF3 does support templates, via template_selection with residue ranges, but
# that is a different exercise from the other three and nothing here has run it.
if [[ $tool == rf3 && $mode == template ]]; then
  echo 'rf3 template mode is not part of this tutorial yet. Use: bash run.sh rf3' >&2
  exit 2
fi

work=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
cd "$work"
python3 "$work/check_inputs.py"
out="$work/out/$tool-$mode"
printf '\nTool: %s; mode: %s; output: %s\n' "$tool" "$mode" "$out"
echo 'Five samples, seed 1, single-sequence inputs; no MSA-server calls.'
if [[ $mode == template ]]; then
  if [[ $tool == protenix ]]; then
    echo 'Templates: related 8VRA antibody chains only; pMHC chains receive none.'
  else
    echo 'Templates: own 8UDR reference; reconstruction demonstration, not an independent benchmark.'
  fi
fi

# In a dry-run the cache variables remain literal placeholders. Nothing is
# sourced and no files are prepared, so this also works on a student's laptop.
boltz_cache='${BOLTZ_CACHE}'
rf3_ckpt='${RF3_CKPT}'
if [[ $dry_run == false ]]; then
  if [[ -n ${CHPC_REPO:-} && $work == "$CHPC_REPO/examples/p1b7" ]]; then
    echo 'This is the checked-in example folder. First copy it to your scratch working folder.' >&2
    exit 2
  fi
  if [[ -z ${SLURM_JOB_ID:-} ]]; then
    echo 'No Slurm allocation. Use the tutorial srun command or sbatch p1b7.sbatch.' >&2
    exit 2
  fi
  if ! command -v nvidia-smi >/dev/null 2>&1 ||
     ! gpu_names=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null) ||
     [[ -z $gpu_names ]]; then
    echo 'No usable GPU on this host. Enter the srun GPU shell or submit p1b7.sbatch.' >&2
    echo 'A bare salloc shell can still be on the login node; do not start prediction there.' >&2
    exit 2
  fi
  if ! command -v chpc-tool >/dev/null 2>&1; then
    echo 'chpc-tool missing. First run: source "$HOME/corehpc/env.sh"' >&2
    exit 2
  fi
  if [[ -e $out ]]; then
    echo "Output already exists: $out" >&2
    echo 'Use a fresh scratch copy to rerun; existing results are retained.' >&2
    exit 2
  fi
  if [[ $tool == boltz ]]; then
    tool_exports=$(chpc-tool export boltz)
    eval "$tool_exports"
    boltz_cache=$BOLTZ_CACHE
  fi
  if [[ $tool == rf3 ]]; then
    # RF3 ships inside the rfdiffusion3 image and has no entry of its own yet;
    # that entry comes after this run passes. RF3_CKPT must be an absolute path:
    # the image's own .env pins FOUNDRY_CHECKPOINT_DIRS and dotenv wins, so a
    # checkpoint NAME resolves inside the container instead of on the share.
    tool_exports=$(chpc-tool export rfdiffusion3)
    eval "$tool_exports"
    rf3_ckpt=$RF3_CKPT
  fi
  if [[ $mode == template && $tool == boltz ]]; then
    python3 "$work/prepare_templates.py" boltz
  elif [[ $mode == template && $tool == protenix ]]; then
    tool_exports=$(chpc-tool export protenix)
    eval "$tool_exports"
    python3 "$work/prepare_templates.py" protenix "$PROTENIX_ROOT_DIR"
  fi
fi

preflight=()
case "$tool" in
  boltz)
    input="$work/boltz.yaml"
    [[ $mode == template ]] && input="$work/prepared/boltz/boltz.yaml"
    command=(chpc-tool exec boltz -- boltz predict "$input" --cache "$boltz_cache"
             --out_dir "$out" --use_potentials --no_kernels --diffusion_samples 5
             --max_parallel_samples 1 --recycling_steps 3 --sampling_steps 200
             --seed 1 --output_format pdb)
    ;;
  protenix)
    input="$work/protenix.json"
    command=(chpc-tool exec protenix --)
    if [[ $mode == template ]]; then
      input="$work/prepared/protenix/protenix.json"
      # env is INSIDE the container: chpc-tool exports the normal shared root
      # before starting it, so setting a host variable alone would be overwritten.
      command+=(env "PROTENIX_ROOT_DIR=$work/prepared/protenix/root"
                    "PROTENIX_DATA_ROOT_DIR=$work/prepared/protenix/root/data"
                    PROTENIX_MAX_TEMPLATE_DATE=3000-01-01 PROTENIX_TEMPLATE_FETCH_REMOTE=false)
      preflight=("${command[@]}" python "$work/protenix_template_check.py")
    fi
    command+=(protenix pred -i "$input" -o "$out" -n protenix_base_default_v1.0.0
              -s 1 -e 5 -c 10 -p 200 --use_msa false)
    [[ $mode == template ]] && command+=(--use_template true)
    ;;
  rf3)
    # one_model_per_file: the default packs all five samples into one file as
    #   separate models, and check_output.py reads model 1 only.
    # early_stopping_plddt_threshold=0.0: DISABLES early stopping. At its default
    #   of 0.5 a single-sequence input is exactly the case upstream says triggers
    #   it, and an early exit writes NO structure -- only metrics.csv and .score
    #   with early_stopped=True -- while exiting successfully. Left on, this
    #   tutorial's no-MSA run would most likely produce nothing and read as a
    #   broken install. The other three predictors have no equivalent behaviour.
    command=(chpc-tool exec rfdiffusion3 -- rf3 fold
             "inputs=$work/rf3.json" "out_dir=$out" "ckpt_path=$rf3_ckpt"
             seed=1 diffusion_batch_size=5 num_steps=200
             one_model_per_file=true early_stopping_plddt_threshold=0.0)
    ;;
  chai1)
    if [[ $mode == template ]]; then
      command=(chpc-tool exec chai1 -- python "$work/chai_template.py" "$out")
    else
      command=(chpc-tool exec chai1 -- chai-lab fold
               --constraint-path "$work/chai1.restraints" --num-trunk-recycles 3
               --num-diffn-timesteps 200 --num-diffn-samples 5 --num-trunk-samples 1
               --seed 1 "$work/chai1.fasta" "$out")
    fi
    ;;
esac
if [[ ${#preflight[@]} -gt 0 ]]; then
  printf 'Template preflight: '
  printf '%q ' "${preflight[@]}"
  printf '< /dev/null\n'
fi
printf 'Command: '
printf '%q ' "${command[@]}"
printf '< /dev/null\n'
if [[ $dry_run == true ]]; then
  echo 'Dry run complete. No files written, GPU work started, or jobs submitted.'
  exit 0
fi
mkdir -p "$work/logs" "$work/out"
log="$work/logs/$tool-$mode-${SLURM_JOB_ID}.log"
echo "Log: $log"
{
  printf 'Started: '; date -u
  printf 'Host: '; hostname
  printf 'Slurm job: %s\n' "$SLURM_JOB_ID"
  printf 'Command: '; printf '%q ' "${command[@]}"; printf '\n'
  if [[ ${#preflight[@]} -gt 0 ]]; then "${preflight[@]}" < /dev/null; fi
  "${command[@]}" < /dev/null
  python3 "$work/check_output.py" "$tool" "$out" --expected-samples 5
} 2>&1 | tee "$log"
