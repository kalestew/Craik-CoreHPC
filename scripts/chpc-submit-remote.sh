#!/usr/bin/env bash
# Internal helper transferred over Globus by chpc-submit.sh. No transfer over SSH.
# bash remote.sh WORK RELATIVE_SCRIPT FAC_SHARE REMOTE_COREHPC -- JOB_ARGS...
# A persistent mkdir guard makes the sbatch transaction at most once. A valid
# saved response can be recovered after SSH disconnects without a second job.
set -euo pipefail
die() { echo "chpc-submit-remote: $*" >&2; exit 1; }
[ $# -ge 5 ] || die 'incomplete dispatch arguments'
work=$1
batch=$2
share=$3
checkout=$4
shift 4
[ "$1" = -- ] || die 'expected -- before job arguments'
shift
case $work in /*) ;; *) die 'work folder must be absolute' ;; esac
case /$batch/ in */../*|*/./*|*//* ) die 'batch script must stay within the work folder' ;; esac
case $batch in ''|/*) die 'batch script must be relative' ;; esac
case $share in ''|.|..|*[!A-Za-z0-9_.-]*) die 'invalid FAC share' ;; esac
cd "$work"
work=$(pwd -P)
[ -f "$batch" ] && [ ! -L "$batch" ] || die "missing regular batch script: $batch"
batch_parent=$(cd "$(dirname "$batch")" && pwd -P)
case $batch_parent in "$work"|"$work"/*) ;; *) die 'batch script escapes the work folder' ;; esac
state="$work/.chpc/submit"
mkdir -p "$state"
printf -v request '%q %q %q' "$batch" "$share" "$checkout"
if [ $# -gt 0 ]; then
  for argument in "$@"; do printf -v quoted ' %q' "$argument"; request=$request$quoted; done
fi
if [ -f "$state/request.txt" ] && [ "$(cat "$state/request.txt")" != "$request" ]; then
  die 'this folder already records a different submission request; use a fresh dispatch'
fi
pattern='^[0-9]+(;[A-Za-z0-9_.-]+)?$'
if [ -s "$state/sbatch-result.txt" ]; then
  saved=$(cat "$state/sbatch-result.txt")
  if [[ $saved =~ $pattern ]]; then
    printf '%s\n' "${saved%%;*}" > "$state/job-id.txt"
    echo "Recovered existing submission ${saved%%;*}; no new sbatch call." >&2
    printf '%s\n' "$saved"
    exit 0
  fi
fi
# SSH does not need or receive the Mac environment. Also clear stale cluster
# shell overrides before selecting the explicitly requested installation.
for dispatch_variable in $(compgen -v CHPC_); do unset "$dispatch_variable"; done
unset COREHPC
export FAC_SHARE="$share"
export CHPC_USER="${USER:-$(id -un)}"
if [ -n "$checkout" ]; then
  case $checkout in /*) ;; *) die 'cluster checkout must be absolute' ;; esac
  [ -r "$checkout/env.sh" ] || die "no env.sh at cluster checkout $checkout"
  export COREHPC="$checkout"
  source "$COREHPC/env.sh" >&2
  export PATH="$COREHPC/lab/bin:$COREHPC/scripts:$PATH"
  installation="checkout $COREHPC"
else
  export CHPC_ENV="/mnt/fac/$FAC_SHARE/chpc.env"
  [ -r "$CHPC_ENV" ] || die "shared environment missing: $CHPC_ENV"
  source "$CHPC_ENV" >&2
  export PATH="$(dirname "$CHPC_ENV")/bin:$PATH"
  installation="shared $CHPC_ENV"
fi
export WORKDIR="$work"
mkdir -p "$work/logs"
# Acquire the persistent guard only after pre-submission checks. A missing
# installation has not contacted Slurm, so fixing it can safely retry here.
if ! mkdir "$state/submit.lock" 2>/dev/null; then
  die "submission is already in progress or its result is uncertain. Inspect $state/sbatch-result.txt and Slurm before taking further action; no second job was submitted."
fi
printf '%s\n' "$request" > "$state/request.txt"
{
  printf 'installation: %s\nenvironment: %s\nregistry: %s\nworkdir: %s\n' "$installation" "${CHPC_ENV:-}" "${CHPC_TOOLS:-}" "$WORKDIR"
  printf 'chpc_tool: %s\n' "$(command -v chpc-tool || true)"
  if [ -n "${COREHPC:-}" ]; then
    printf 'checkout_revision: '
    git -C "$COREHPC" rev-parse HEAD 2>/dev/null || printf 'unavailable\n'
  fi
} > "$state/environment.txt"
cat "$state/environment.txt" >&2
printf '%s\n' 'submitting' > "$state/status.txt"
# Write sbatch's response directly on the cluster before sending it over SSH.
# Keep the guard even on failure: an interrupted response must never authorize
# another sbatch automatically. The local receipt includes this recovery path.
if sbatch --parsable --export=ALL --chdir="$work" \
     --output="$work/logs/slurm-%j.out" --error="$work/logs/slurm-%j.out" \
     "./$batch" "$@" > "$state/sbatch-result.txt" 2> "$state/sbatch-error.txt"; then
  saved=$(cat "$state/sbatch-result.txt")
  if [[ ! $saved =~ $pattern ]]; then
    printf '%s\n' 'submission-response-unknown' > "$state/status.txt"
    die 'sbatch did not return a recognizable job ID; inspect the saved response before retrying'
  fi
else
  printf '%s\n' 'sbatch-failed-or-uncertain' > "$state/status.txt"
  cat "$state/sbatch-error.txt" >&2
  die 'sbatch failed; the saved guard prevents an accidental duplicate submission'
fi
printf '%s\n' "${saved%%;*}" > "$state/job-id.txt"
printf '%s\n' 'submitted' > "$state/status.txt"
cat "$state/sbatch-error.txt" >&2
printf '%s\n' "$saved"
