#!/usr/bin/env bash
# Move data between this machine and CoreHPC over Globus, the approved path.
#
# The AUP names three transfer paths -- Globus, the FAC share, and Open
# OnDemand -- and the bastion is not one of them. `scripts/chpc-stage.sh` is
# rsync through the bastion and predates that finding; this is its replacement
# and the thing a pipeline should depend on. See docs/02-storage-and-data.md.
#
# Usage:
#   chpc-globus.sh doctor                       what is set up, what is not
#   chpc-globus.sh env                          the resolved settings, one per line
#   chpc-globus.sh push <local> <cluster>       this machine -> the cluster
#   chpc-globus.sh pull <cluster> <local>       the cluster -> this machine
#
# Options:  --dry-run   print every command instead of running it
#           --label S   name the Globus task (default: chpc-<verb>-<timestamp>)
#           --wait S    seconds to wait for the transfer (default 3600; 0 = queue
#                       and return the task id)
#
# ---------------------------------------------------------------------------
# WHY A TRANSFER HAS TWO LEGS
#
# There is no Globus collection on FAC. The two CoreHPC collections are User
# Home and User Scratch, so Globus reaches scratch and no further -- and FAC is
# where anything persistent belongs, because scratch is purged at thirty days.
#
# So a push to FAC is: one Globus transfer into $CHPC_GLOBUS_STAGING, then a
# cluster-local `cp` into place, then `chpc-fac-fixacl` -- because a new file on
# the share inherits a DENY entry for its own owner and is otherwise unreadable
# by the person who just wrote it. A pull from FAC is the same trip backwards.
#
# A transfer to or from scratch itself is one leg, and this script says which it
# did rather than leaving you to infer it.
# ---------------------------------------------------------------------------
set -euo pipefail

_s=${BASH_SOURCE[0]}; while [ -L "$_s" ]; do _d=$(cd "$(dirname "$_s")" && pwd); _s=$(readlink "$_s"); [[ $_s == /* ]] || _s=$_d/$_s; done
# shellcheck source=../env.sh
source "$(cd "$(dirname "$_s")/.." && pwd)/env.sh"

GLOBUS=${GLOBUS:-globus}
DRY_RUN=0
LABEL=
WAIT_S=3600

die() { echo "chpc-globus: $*" >&2; exit 1; }

# Run a command, or print it. Printed form is shell-quoted so a dry run is
# something you can paste, not a description of something you could paste.
run() {
  if [ "$DRY_RUN" = 1 ]; then
    printf 'RUN'; printf ' %q' "$@"; printf '\n'
    return 0
  fi
  "$@"
}

# Same, over the primed SSH session. One argument: a command line for the
# remote shell, already quoted for it.
run_remote() {
  if [ "$DRY_RUN" = 1 ]; then
    printf 'SSH %s\n' "$1"
    return 0
  fi
  ssh -O check "$CHPC_HOST" >/dev/null 2>&1 || "$CHPC_REPO/scripts/chpc-prime.sh"
  ssh "$CHPC_HOST" "$1"
}

# --- path arithmetic ---------------------------------------------------------
# A collection path is a POSIX path with the collection's root removed. Both
# roots are declared (lab/chpc.env for the cluster, chpc.env.local for here),
# and a path outside its root is REFUSED rather than passed through: Globus
# would accept it, transfer successfully, and land the data somewhere nobody
# asked for, with nothing downstream able to tell.
collection_path() {
  local root=$1 path=$2 what=$3
  [ "${path#/}" != "$path" ] || die "$what must be an absolute path, got '$path'"
  root=${root%/}
  if [ -z "$root" ]; then printf '%s\n' "$path"; return; fi
  case $path in
    "$root") printf '/\n' ;;
    "$root"/*) printf '%s\n' "${path#"$root"}" ;;
    *) die "$what '$path' is not under the collection root '$root', so it has no
       path inside that collection. Either move it, or correct the root -- see
       'chpc-globus.sh env'." ;;
  esac
}

require_local_setup() {
  command -v "$GLOBUS" >/dev/null || die "the globus CLI is not on PATH. On the cluster:
  module load globus-cli. On a workstation: https://docs.globus.org/cli/install/"
  if [ -z "${CHPC_GLOBUS_LOCAL_COLLECTION:-}" ]; then
    CHPC_GLOBUS_LOCAL_COLLECTION=$("$GLOBUS" endpoint local-id 2>/dev/null || true)
    [ -n "$CHPC_GLOBUS_LOCAL_COLLECTION" ] || die "no local Globus collection. Install
  Globus Connect Personal and start it, or set CHPC_GLOBUS_LOCAL_COLLECTION in
  chpc.env.local -- see chpc.env.local.example."
  fi
  CHPC_GLOBUS_LOCAL_ROOT=${CHPC_GLOBUS_LOCAL_ROOT:-/}
  [ -n "${CHPC_GLOBUS_STAGING_LOCAL:-}" ] || die "CHPC_GLOBUS_STAGING_LOCAL is unset.
  It is the directory on THIS machine that Globus may write, and it has no
  default because a guessed one fails at the end of a transfer rather than at
  the start. Set it in chpc.env.local -- see chpc.env.local.example."
}

# --- the Globus leg ----------------------------------------------------------
# --notify off because a round's transfers are not correspondence, and
# --format json so the task id is read from a field rather than matched out of
# a sentence.
transfer() {
  local src=$1 src_path=$2 dst=$3 dst_path=$4 recursive=$5
  # --jmespath with -F unix so the task id is read from a named field as a bare
  # string, rather than matched out of a sentence -- the same reason a
  # submission passes --parsable to sbatch. It also means this script needs no
  # JSON parser of its own.
  local -a argv=("$GLOBUS" transfer "$src:$src_path" "$dst:$dst_path"
                 --label "$LABEL" --notify off --jmespath task_id -F unix)
  [ "$recursive" = 1 ] && argv+=(--recursive)
  if [ "$DRY_RUN" = 1 ]; then
    run "${argv[@]}"
    printf 'RUN %s task wait <the-id-that-printed> --timeout %s\n' "$GLOBUS" "$WAIT_S"
    return 0
  fi
  local task
  task=$("${argv[@]}")
  [ -n "$task" ] || die "the transfer was queued but its task id could not be read;
  find it with: globus task list"
  echo "task $task queued: $src:$src_path -> $dst:$dst_path" >&2
  if [ "$WAIT_S" = 0 ]; then printf '%s\n' "$task"; return 0; fi
  # A timeout is not a failure here. The task is still running and nothing has
  # been lost, which is a different thing to say than "the transfer failed".
  "$GLOBUS" task wait "$task" --timeout "$WAIT_S" || die "task $task has not finished
  after ${WAIT_S}s. It is still running and nothing has been lost. Watch it with:
  globus task show $task"
  local status
  status=$("$GLOBUS" task show "$task" --jmespath status -F unix)
  [ "$status" = SUCCEEDED ] || die "task $task ended $status. globus task show $task"
  printf '%s\n' "$task"
}

# --- verbs -------------------------------------------------------------------
cmd_env() {
  local local_id=${CHPC_GLOBUS_LOCAL_COLLECTION:-}
  if [ -z "$local_id" ] && command -v "$GLOBUS" >/dev/null; then
    local_id=$("$GLOBUS" endpoint local-id 2>/dev/null || true)
  fi
  cat <<EOF
CHPC_USER=$CHPC_USER
CHPC_GLOBUS_SCRATCH_COLLECTION=$CHPC_GLOBUS_SCRATCH_COLLECTION
CHPC_GLOBUS_SCRATCH_ROOT=$CHPC_GLOBUS_SCRATCH_ROOT
CHPC_GLOBUS_STAGING=$CHPC_GLOBUS_STAGING
CHPC_GLOBUS_LOCAL_COLLECTION=${local_id:-<unset, and no local collection detected>}
CHPC_GLOBUS_LOCAL_ROOT=${CHPC_GLOBUS_LOCAL_ROOT:-/}
CHPC_GLOBUS_STAGING_LOCAL=${CHPC_GLOBUS_STAGING_LOCAL:-<unset>}
EOF
}

# Every question this script's failure modes turn on, asked in the order that
# costs least, and each one answered from an observation rather than a setting.
cmd_doctor() {
  local worst=0
  say() { printf '%-22s %-5s %s\n' "$1" "$2" "$3"; [ "$2" = fail ] && worst=1; return 0; }

  if ! command -v "$GLOBUS" >/dev/null; then
    say globus_cli fail "not on PATH. Install: https://docs.globus.org/cli/install/"
    return 1
  fi
  say globus_cli ok "$(command -v "$GLOBUS")"

  local who
  if who=$("$GLOBUS" whoami 2>/dev/null); then
    say identity ok "$who"
  else
    say identity fail "not logged in. Run: globus login"
    return 1
  fi

  local local_id=${CHPC_GLOBUS_LOCAL_COLLECTION:-}
  local detected
  detected=$("$GLOBUS" endpoint local-id 2>/dev/null || true)
  if [ -n "$local_id" ] && [ -n "$detected" ] && [ "$local_id" != "$detected" ]; then
    say local_collection warn "declared $local_id, but the collection running here is
                       $detected. The declaration wins; unset
                       CHPC_GLOBUS_LOCAL_COLLECTION to use this machine's own."
  elif [ -n "$local_id$detected" ]; then
    say local_collection ok "${local_id:-$detected}${local_id:+ (declared)}"
    local_id=${local_id:-$detected}
  else
    say local_collection fail "no collection on this machine and none declared. Install
                       Globus Connect Personal, start it, then re-run."
    return 1
  fi

  # The mapping check. This is the one that cannot be done by reading settings:
  # it resolves the declared staging directory through the declared root and
  # asks the collection to list it. A wrong root does not fail a transfer, it
  # relocates one.
  if [ -z "${CHPC_GLOBUS_STAGING_LOCAL:-}" ]; then
    say local_staging fail "CHPC_GLOBUS_STAGING_LOCAL is unset; set it in chpc.env.local"
  elif [ ! -d "$CHPC_GLOBUS_STAGING_LOCAL" ]; then
    say local_staging fail "$CHPC_GLOBUS_STAGING_LOCAL does not exist. mkdir -p it, and
                       add it to Globus Connect Personal's writable paths."
  elif [ ! -w "$CHPC_GLOBUS_STAGING_LOCAL" ]; then
    say local_staging fail "$CHPC_GLOBUS_STAGING_LOCAL is not writable by you"
  else
    local rel
    rel=$(collection_path "${CHPC_GLOBUS_LOCAL_ROOT:-/}" "$CHPC_GLOBUS_STAGING_LOCAL" \
          CHPC_GLOBUS_STAGING_LOCAL) || return 1
    if "$GLOBUS" ls "$local_id:$rel" >/dev/null 2>&1; then
      say local_staging ok "$CHPC_GLOBUS_STAGING_LOCAL is '$rel' in the collection, and lists"
    else
      say local_staging fail "$CHPC_GLOBUS_STAGING_LOCAL resolves to '$rel' under root
                       '${CHPC_GLOBUS_LOCAL_ROOT:-/}', and the collection cannot list that.
                       Either the root is wrong (see chpc.env.local.example) or the
                       directory is not in Globus Connect Personal's config."
    fi
  fi

  if "$GLOBUS" ls "$CHPC_GLOBUS_SCRATCH_COLLECTION:/" >/dev/null 2>&1; then
    say cluster_collection ok "User Scratch lists; '/' there is $CHPC_GLOBUS_SCRATCH_ROOT"
  else
    say cluster_collection fail "cannot list $CHPC_GLOBUS_SCRATCH_COLLECTION. Consent once:
                       globus login --gcs $CHPC_GLOBUS_SCRATCH_COLLECTION"
  fi

  # Only meaningful off-cluster, and only for the FAC leg.
  if [ "$CHPC_ON_CLUSTER" = 1 ]; then
    say ssh_session info "already on the cluster; the second leg is a local cp"
  elif ssh -O check "$CHPC_HOST" >/dev/null 2>&1; then
    say ssh_session ok "master session to $CHPC_HOST is open (needed for the FAC leg)"
  else
    say ssh_session warn "no master session to $CHPC_HOST. A transfer to or from FAC
                       needs one for its second leg: chpc-prime.sh"
  fi
  return "$worst"
}

# Every collection path is computed into a VARIABLE before it is used, never
# inline in an argument list. That is not style: `cmd "$(fn)"` discards the
# substitution's exit status, so a refusal inside `collection_path` printed its
# message and the transfer still ran -- with an EMPTY path, which Globus reads as
# the collection root and would have written a whole bundle to. An assignment,
# under `set -e`, aborts.
cmd_push() {
  local src=$1 dst=$2
  require_local_setup
  [ -e "$src" ] || die "'$src' does not exist here"
  case $src in /*) ;; *) src=$(cd "$(dirname "$src")" && pwd)/$(basename "$src") ;; esac
  local recursive=0; [ -d "$src" ] && recursive=1
  local src_rel dst_rel buffer
  src_rel=$(collection_path "$CHPC_GLOBUS_LOCAL_ROOT" "$src" "source")

  case $dst in
    "$CHPC_GLOBUS_SCRATCH_ROOT"|"$CHPC_GLOBUS_SCRATCH_ROOT"/*)
      echo "one leg: '$dst' is inside the scratch collection" >&2
      dst_rel=$(collection_path "$CHPC_GLOBUS_SCRATCH_ROOT" "$dst" destination)
      transfer "$CHPC_GLOBUS_LOCAL_COLLECTION" "$src_rel" \
               "$CHPC_GLOBUS_SCRATCH_COLLECTION" "$dst_rel" "$recursive"
      ;;
    *)
      buffer="$CHPC_GLOBUS_STAGING/$(basename "$dst")"
      echo "two legs: no Globus collection covers '$dst', so it goes via $buffer" >&2
      dst_rel=$(collection_path "$CHPC_GLOBUS_SCRATCH_ROOT" "$buffer" staging)
      transfer "$CHPC_GLOBUS_LOCAL_COLLECTION" "$src_rel" \
               "$CHPC_GLOBUS_SCRATCH_COLLECTION" "$dst_rel" "$recursive"
      run_remote "$(printf 'set -e; mkdir -p %q; cp -a %q %q; command -v chpc-fac-fixacl >/dev/null && chpc-fac-fixacl %q || echo "chpc-fac-fixacl not on PATH; %q may be unreadable by its own owner" >&2' \
                    "$(dirname "$dst")" "$buffer" "$dst" "$dst" "$dst")"
      echo "landed at $dst; the copy in $buffer is a buffer and scratch is purged at 30 days" >&2
      ;;
  esac
}

cmd_pull() {
  local src=$1 dst=$2
  require_local_setup
  case $dst in /*) ;; *) dst=$(pwd)/$dst ;; esac
  local dst_rel src_rel buffer recursive=1
  dst_rel=$(collection_path "$CHPC_GLOBUS_LOCAL_ROOT" "$dst" destination)

  case $src in
    "$CHPC_GLOBUS_SCRATCH_ROOT"|"$CHPC_GLOBUS_SCRATCH_ROOT"/*)
      echo "one leg: '$src' is inside the scratch collection" >&2
      src_rel=$(collection_path "$CHPC_GLOBUS_SCRATCH_ROOT" "$src" source)
      if [ "$DRY_RUN" != 1 ]; then
        run_remote "test -d $(printf '%q' "$src")" || recursive=0
      fi
      transfer "$CHPC_GLOBUS_SCRATCH_COLLECTION" "$src_rel" \
               "$CHPC_GLOBUS_LOCAL_COLLECTION" "$dst_rel" "$recursive"
      ;;
    *)
      buffer="$CHPC_GLOBUS_STAGING/$(basename "$src")"
      echo "two legs: no Globus collection covers '$src', so it goes via $buffer" >&2
      # Refuse before the copy, not after it: a buffer filled outside the
      # collection is work done for a transfer that cannot read it.
      src_rel=$(collection_path "$CHPC_GLOBUS_SCRATCH_ROOT" "$buffer" staging)
      run_remote "$(printf 'set -e; mkdir -p %q; cp -a %q %q' \
                    "$CHPC_GLOBUS_STAGING" "$src" "$buffer")"
      if [ "$DRY_RUN" != 1 ]; then
        run_remote "test -d $(printf '%q' "$buffer")" || recursive=0
      fi
      transfer "$CHPC_GLOBUS_SCRATCH_COLLECTION" "$src_rel" \
               "$CHPC_GLOBUS_LOCAL_COLLECTION" "$dst_rel" "$recursive"
      ;;
  esac
}

# --- argument handling -------------------------------------------------------
verb=${1:-}; [ $# -ge 1 ] && shift
args=()
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY_RUN=1 ;;
    --label) LABEL=$2; shift ;;
    --wait) WAIT_S=$2; shift ;;
    -h|--help) sed -n '2,33p' "$_s"; exit 0 ;;
    -*) die "unknown option '$1'" ;;
    *) args+=("$1") ;;
  esac
  shift
done
: "${LABEL:=chpc-${verb:-globus}-$(date +%Y%m%d-%H%M%S)}"

case $verb in
  env)    cmd_env ;;
  doctor) cmd_doctor ;;
  push)   [ ${#args[@]} -eq 2 ] || die "usage: chpc-globus.sh push <local> <cluster>"
          cmd_push "${args[0]}" "${args[1]}" ;;
  pull)   [ ${#args[@]} -eq 2 ] || die "usage: chpc-globus.sh pull <cluster> <local>"
          cmd_pull "${args[0]}" "${args[1]}" ;;
  ""|-h|--help) sed -n '2,33p' "$_s"; exit 0 ;;
  *)      die "unknown verb '$verb'. One of: doctor env push pull" ;;
esac
