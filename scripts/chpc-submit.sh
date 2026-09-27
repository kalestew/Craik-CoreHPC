#!/usr/bin/env bash
# Upload a selected job folder over Globus, wait, then submit it over SSH.
# Usage: chpc-submit.sh LOCAL_JOB_DIR RELATIVE_SCRIPT.sbatch [--corehpc REMOTE_CHECKOUT]
#                       [--dry-run] [--wait SECONDS] [-- JOB_ARGS...]
#
# The folder must contain the job's scripts and inputs. No checkout is cloned
# or mirrored. The default uses the shared cluster installation; --corehpc
# selects an existing checkout ON THE CLUSTER, not the checkout on this Mac.
# Globus reads the live folder: do not edit its inputs until transfers finish.
#
# Excluded directory names at every depth: .git .venv .chpc out outputs
# results logs prepared __pycache__; excluded files: .git .env chpc.env.local *.pyc.
# Those are exact names except *.pyc, not a general secret/dependency detector.
# Slurm stdout and stderr both go to logs/slurm-JOB_ID.out, overriding the
# batch script's output/error directives so the receipt always names the log.
# WORKDIR is exported as the remote job folder for the standard Slurm templates.
# stdout prints the submitted job ID. Diagnostics and receipt locations use stderr.
set -euo pipefail

_s=${BASH_SOURCE[0]}
while [ -L "$_s" ]; do
  _d=$(cd "$(dirname "$_s")" && pwd)
  _s=$(readlink "$_s")
  [[ $_s == /* ]] || _s=$_d/$_s
done
source "$(cd "$(dirname "$_s")/.." && pwd)/env.sh"

die() { echo "chpc-submit: $*" >&2; exit 1; }
usage() { sed -n '2,17p' "$_s" | sed 's/^# \{0,1\}//'; }
if [[ ${1:-} == -h || ${1:-} == --help ]]; then usage; exit 0; fi
[ $# -ge 2 ] || { usage >&2; exit 2; }
selected=$1
batch=$2
shift 2
remote_corehpc=
dry_run=0
wait_seconds=3600
job_args=()
while [ $# -gt 0 ]; do
  case $1 in
    --corehpc|--wait)
      [ $# -ge 2 ] || die "$1 requires a value"
      case $1 in --corehpc) remote_corehpc=$2 ;; --wait) wait_seconds=$2 ;; esac
      shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --) shift; job_args=("$@"); break ;;
    *) die "unknown option '$1'; put job arguments after --" ;;
  esac
done
case $wait_seconds in ''|*[!0-9]*) die "--wait must be a positive number of seconds" ;; esac
[ "$wait_seconds" -gt 0 ] || die "--wait 0 cannot submit safely: both transfers must finish first"
case $CHPC_USER in ''|.|..|*[!A-Za-z0-9_.-]*) die "CHPC_USER is not a campus username" ;; esac
case $FAC_SHARE in ''|.|..|*[!A-Za-z0-9_.-]*) die "FAC_SHARE must be a single share name" ;; esac
case $remote_corehpc in
  '') ;;
  /Users/*|/Volumes/*) die "--corehpc names an existing checkout on the cluster, not a laptop path" ;;
  /*) ;;
  *) die "--corehpc must be an absolute checkout path on the cluster" ;;
esac
case /$remote_corehpc/ in */../*|*/./*) die "--corehpc must not contain . or .. path components" ;; esac
[ -d "$selected" ] || die "job folder does not exist: $selected"
selected=$(cd "$selected" && pwd -P)
case $batch in
  /*|'') die "the batch script must be a path relative to the selected folder" ;;
  *.sbatch) ;;
  *) die "the selected batch script must end in .sbatch" ;;
esac
case /$batch/ in */../*|*/./*|*//* ) die "the batch script must not contain empty, . or .. path components" ;; esac

# A symlink component may be ignored by Globus or escape the selected folder.
# Refuse it before moving any data, even if the current target happens to exist.
rest=$batch
checked=$selected
while [ -n "$rest" ]; do
  part=${rest%%/*}
  if [ "$rest" = "$part" ]; then rest=; else rest=${rest#*/}; fi
  case $part in
    .git|.venv|.chpc|.env|chpc.env.local|out|outputs|results|logs|prepared|__pycache__|*.pyc)
      die "the batch script is inside an excluded name: $part" ;;
  esac
  checked=$checked/$part
  [ ! -L "$checked" ] || die "the batch script path must not use symlinks: $checked"
done
[ -f "$checked" ] && [ -r "$checked" ] || die "batch script is not readable: $checked"

# Globus does not follow source symlinks. Failing early is clearer than a job
# discovering that an apparently present input or sibling-script link vanished.
# Apply the same name rules as the actual transfer, including .git as a FILE
# in a submodule and as a directory in an ordinary checkout.
command -v python3 >/dev/null || die 'python3 is needed for the selected-input audit'
python3 - "$selected" <<'PY'
import fnmatch
import os
from pathlib import Path
import sys

excluded_dirs = {'.git', '.venv', '.chpc', 'out', 'outputs', 'results', 'logs', 'prepared', '__pycache__'}
excluded_files = ('.git', '.env', 'chpc.env.local', '*.pyc')
bad = []
for directory, dirs, files in os.walk(sys.argv[1], followlinks=False):
    dirs[:] = [name for name in dirs if name not in excluded_dirs]
    for name in dirs + [name for name in files if not any(fnmatch.fnmatchcase(name, rule) for rule in excluded_files)]:
        path = Path(directory, name)
        if path.is_symlink():
            bad.append(str(path))
if bad:
    raise SystemExit('chpc-submit: included symlinks are not transferred by Globus; put the real input files in the selected bundle:\n' + '\n'.join(bad))
PY

folder=$(basename "$selected")
folder=$(printf '%s' "$folder" | LC_ALL=C tr -c 'A-Za-z0-9._-' '-')
folder=${folder:0:48}
submission="chpc-run-${folder}-$(date -u +%Y%m%dT%H%M%SZ)-$$-${RANDOM}"
remote_dir="$CHPC_USER_SCRATCH/$submission"
receipt_root="$CHPC_PROJECT/.chpc/submissions"
receipt="$receipt_root/$submission"
helper_local="$CHPC_REPO/scripts/chpc-submit-remote.sh"
helper_remote="$remote_dir/.chpc/submit/remote.sh"
[ -r "$helper_local" ] || die "missing submission helper: $helper_local"

transfer_inputs=("$CHPC_REPO/scripts/chpc-globus.sh" push "$selected" "$remote_dir"
                 --wait "$wait_seconds" --label "$submission-inputs" --sync-level checksum)
for excluded in .git .venv .chpc out outputs results logs prepared __pycache__; do
  transfer_inputs+=(--exclude-dir "$excluded")
done
for excluded in .git .env chpc.env.local '*.pyc'; do
  transfer_inputs+=(--exclude "$excluded")
done
transfer_helper=("$CHPC_REPO/scripts/chpc-globus.sh" push "$helper_local" "$helper_remote"
                 --wait "$wait_seconds" --label "$submission-helper" --sync-level checksum)
printf -v remote_command 'bash %q %q %q %q %q --' \
  "$helper_remote" "$remote_dir" "$batch" "$FAC_SHARE" "$remote_corehpc"
if [ ${#job_args[@]} -gt 0 ]; then
  for argument in "${job_args[@]}"; do
    printf -v quoted ' %q' "$argument"
    remote_command=$remote_command$quoted
  done
fi
printf -v recovery_command 'ssh %q %q' "$CHPC_HOST" "$remote_command"

echo "Selected inputs: $selected" >&2
echo "Cluster work folder: $remote_dir" >&2
if [ -n "$remote_corehpc" ]; then
  echo "Installation: existing cluster checkout $remote_corehpc" >&2
else
  echo "Installation: shared /mnt/fac/$FAC_SHARE/chpc.env (not the local checkout's registry)" >&2
fi
echo 'Globus reads the live selected folder; leave its inputs unchanged until transfer completion.' >&2
if [ "$dry_run" = 1 ]; then
  printf 'TRANSFER'; printf ' %q' "${transfer_inputs[@]}"; printf '\n'
  printf 'TRANSFER'; printf ' %q' "${transfer_helper[@]}"; printf '\n'
  printf 'AFTER BOTH SUCCEED: ssh %q %q\n' "$CHPC_HOST" "$remote_command"
  printf 'Receipt would be: %s\n' "$receipt"
  echo 'Dry run: no folders created, transfers queued, SSH connections opened, or jobs submitted.'
  exit 0
fi

mkdir -p "$receipt_root"
mkdir "$receipt"
printf '%s\n' "$receipt" > "$receipt_root/latest"
printf '%s\n' "$remote_dir" > "$receipt/remote-dir.txt"
printf '%s\n' "$remote_command" > "$receipt/command.txt"
printf '%s\n' "$recovery_command" > "$receipt/recovery-command.txt"
printf '%s\n' "$remote_dir/logs/slurm-%j.out" > "$receipt/log-pattern.txt"
{
  printf 'source: %q\nscript: %q\nhost: %q\n' "$selected" "$batch" "$CHPC_HOST"
  printf 'installation: %q\n' "${remote_corehpc:-/mnt/fac/$FAC_SHARE/chpc.env}"
  printf 'local_corehpc_revision: '
  git -C "$CHPC_REPO" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
  echo 'The local revision identifies this dispatcher, not the shared cluster registry.'
  printf 'job_arguments:'
  if [ ${#job_args[@]} -gt 0 ]; then printf ' %q' "${job_args[@]}"; fi
  printf '\n'
} > "$receipt/request.txt"
echo "Receipt: $receipt" >&2

transfer_one() {
  local name=$1
  shift
  printf '%s\n' "transferring-$name" > "$receipt/status.txt"
  if "$@" > "$receipt/transfer-$name.txt" 2> >(tee "$receipt/transfer-$name.log" >&2); then
    [ -s "$receipt/transfer-$name.txt" ] || die "$name transfer returned no task ID; no job submitted (receipt: $receipt)"
  else
    printf '%s\n' "transfer-$name-failed-or-pending" > "$receipt/status.txt"
    die "$name transfer did not confirm success; no job submitted. The queued task may still be running; inspect $receipt/transfer-$name.log."
  fi
}
transfer_one inputs "${transfer_inputs[@]}"
transfer_one helper "${transfer_helper[@]}"
printf '%s\n' 'transfers-succeeded' > "$receipt/status.txt"

if ! ssh -O check "$CHPC_HOST" >/dev/null 2>&1; then
  "$CHPC_REPO/scripts/chpc-prime.sh" >&2 || die "SSH login failed after transfer; receipt: $receipt"
fi
printf '%s\n' 'awaiting-submit-response' > "$receipt/status.txt"
if result=$(ssh "$CHPC_HOST" "$remote_command" 2> >(tee "$receipt/submit.log" >&2)); then
  pattern='^[0-9]+(;[A-Za-z0-9_.-]+)?$'
  if [[ ! $result =~ $pattern ]]; then
    printf '%s\n' "$result" > "$receipt/unrecognized-response.txt"
    printf '%s\n' 'submission-response-unknown' > "$receipt/status.txt"
    die "SSH returned an unrecognized job ID. Do not submit another copy; inspect the remote .chpc/submit receipt. Recovery command: $recovery_command"
  fi
else
  printf '%s\n' 'submission-response-unknown' > "$receipt/status.txt"
  die "SSH did not confirm the job ID. The remote receipt prevents duplicate submission; recover using: $recovery_command"
fi
job_id=${result%%;*}
printf '%s\n' "$job_id" > "$receipt/job-id.txt"
printf '%s\n' "$remote_dir/logs/slurm-$job_id.out" > "$receipt/log-path.txt"
printf '%s\n' 'submitted' > "$receipt/status.txt"
printf 'Submitted job %s; log %s\nReceipt: %s\n' "$job_id" "$remote_dir/logs/slurm-$job_id.out" "$receipt" >&2
printf '%s\n' "$job_id"
