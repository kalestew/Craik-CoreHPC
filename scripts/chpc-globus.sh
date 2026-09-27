#!/usr/bin/env bash
# Move data between this machine and CoreHPC over Globus, the approved path.
#
# The AUP names three transfer paths -- Globus, the FAC share, and Open
# OnDemand -- and the bastion is not one of them. The old SSH transfer entry
# point now redirects users here; this is what pipelines should depend on.
# See docs/02-storage-and-data.md.
#
# Usage:
#   chpc-globus.sh doctor [local-path]          check project access (default: CHPC_PROJECT)
#   chpc-globus.sh env                          the resolved settings, one per line
#   chpc-globus.sh push <local> <cluster>       this machine -> the cluster
#   chpc-globus.sh pull <cluster> <local>       the cluster -> this machine
#
# Options:  --dry-run   print every command instead of running it
#           --label S   name the Globus task (default: chpc-<verb>-<timestamp>)
#           --wait S    seconds to wait for the transfer (default 3600; 0 = queue
#                       and return the task id; disallowed for a FAC push)
#           --exclude P  omit matching file names (repeatable; recursive only)
#           --exclude-dir P  omit matching directories and contents (requires python3)
#           --sync-level LEVEL  exists|size|mtime|checksum; copy changed files
#           --type TYPE  file|directory for pull (otherwise Globus detects it)
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
# by the person who just wrote it. A destination directory that does not exist
# yet is created and repaired before the copy, for the same reason: the copy
# into an unrepaired one fails. A pull from FAC is the same trip backwards.
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
SYNC_LEVEL=
PATH_TYPE=
EXCLUDES=()
EXCLUDE_DIRS=()

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
  if [ "$CHPC_ON_CLUSTER" = 1 ]; then
    bash -c "$1" >&2
  else
    ssh -O check "$CHPC_HOST" >/dev/null 2>&1 || "$CHPC_REPO/scripts/chpc-prime.sh"
    ssh "$CHPC_HOST" "$1" >&2
  fi
}

# --- path arithmetic ---------------------------------------------------------
# A collection path is a POSIX path with the collection's root removed. Both
# roots are declared (lab/chpc.env for the cluster, chpc.env.local for here),
# and a path outside its root is REFUSED rather than passed through: Globus
# would accept it, transfer successfully, and land the data somewhere nobody
# asked for, with nothing downstream able to tell.
# Normalize redundant separators and /./ before comparing collection roots.
# Refuse /../: lexical collapse can change the source when a parent is a symlink.
absolute_path() {
  local path=$1 rest part normalized=
  case $path in /*) ;; *) path=$PWD/$path ;; esac
  rest=${path#/}
  while [ -n "$rest" ]; do
    part=${rest%%/*}
    case $rest in */*) rest=${rest#*/} ;; *) rest= ;; esac
    case $part in
      ''|.) ;;
      ..) die "parent (..) path components are ambiguous across symlinks: '$path'. Use a resolved absolute path without .. (cd to the directory, then pwd -P)." ;;
      *) normalized=$normalized/$part ;;
    esac
  done
  printf '%s\n' "${normalized:-/}"
}

collection_path() {
  local root=$1 path=$2 what=$3
  case $path in /*) ;; *) die "$what must be an absolute path, got '$path'" ;; esac
  case $root in /*) ;; *) die "collection root must be absolute, got '$root'" ;; esac
  root=$(absolute_path "$root")
  path=$(absolute_path "$path")
  if [ "$root" = / ]; then printf '%s\n' "$path"; return; fi
  case $path in
    "$root") printf '/\n' ;;
    "$root"/*) printf '%s\n' "${path#"$root"}" ;;
    *) die "$what '$path' is not under the collection root '$root', so it has no
       path inside that collection. Correct CHPC_GLOBUS_LOCAL_ROOT if necessary;
       adding an accessible folder in Globus Connect Personal does not change
       the collection root (normally /). See 'chpc-globus.sh env'." ;;
  esac
}

# A source file is checked through its parent. For a new download directory,
# walk to the nearest existing parent: Globus creates the missing directories.
local_access_directory() {
  local path=$1 mode=$2
  if [ "$mode" = source ] && [ ! -e "$path" ]; then
    die "'$path' does not exist here"
  fi
  if [ -e "$path" ] && [ ! -d "$path" ]; then path=$(dirname "$path"); fi
  while [ ! -d "$path" ] && [ "$path" != / ]; do path=$(dirname "$path"); done
  printf '%s\n' "$path"
}

# Keep the service's original error: a stopped endpoint, expired consent and
# an inaccessible folder need different remedies, not a staging-folder guess.
check_local_access() {
  local path=$1 mode=$2 directory rel message
  directory=$(local_access_directory "$path" "$mode") || return 1
  rel=$(collection_path "$CHPC_GLOBUS_LOCAL_ROOT" "$directory" "local access check") || return 1
  if [ "$DRY_RUN" = 1 ]; then
    echo "access check skipped (--dry-run, offline): $CHPC_GLOBUS_LOCAL_COLLECTION:$rel" >&2
    return 0
  fi
  if message=$("$GLOBUS" ls "$CHPC_GLOBUS_LOCAL_COLLECTION:$rel" 2>&1); then
    echo "local access ok: '$directory' lists through Globus" >&2
    if [ "$mode" = destination ] && [ ! -w "$directory" ]; then
      echo "chpc-globus: '$directory' is not writable by this local user" >&2
      return 1
    fi
    return 0
  fi
  printf '%s\n' "$message" >&2
  echo "chpc-globus: cannot list '$directory' as '$rel' in the local collection." >&2
  case $message in
    *[Pp]ath\ not\ allowed*|*[Pp]ermission\ denied*)
      echo "In Globus Connect Personal: Settings/Preferences > Access, add '$directory' or its projects parent; allow Write for downloads. On macOS, also grant Files and Folders/removable-volume access if prompted." >&2 ;;
    *)
      echo "Check the error above, keep Globus Connect Personal running, and verify its accessible folders and CHPC_GLOBUS_LOCAL_ROOT (normally /). Run globus login if consent or authentication expired." >&2 ;;
  esac
  return 1
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
  if [ "$recursive" = 1 ]; then
    argv+=(--recursive)
  else
    argv+=(--no-recursive)
    [ ${#EXCLUDES[@]} -eq 0 ] && [ ${#EXCLUDE_DIRS[@]} -eq 0 ] || die "--exclude and --exclude-dir apply only to directory transfers"
  fi
  local pattern
  for pattern in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do argv+=(--exclude "$pattern"); done
  [ -z "$SYNC_LEVEL" ] || argv+=(--sync-level "$SYNC_LEVEL")
  local task submission request
  if [ ${#EXCLUDE_DIRS[@]} -gt 0 ]; then
    command -v python3 >/dev/null || die "--exclude-dir needs python3 to build the Globus Transfer API request"
    if [ "$DRY_RUN" = 1 ]; then
      submission='<submission-id>'
      echo "directory filters use Globus Transfer API type=dir (skip entire matching subtrees)" >&2
      run "$GLOBUS" task generate-submission-id --jmespath value -F unix
    else
      submission=$("$GLOBUS" task generate-submission-id --jmespath value -F unix)
      [ -n "$submission" ] || die "could not obtain a Globus submission id"
    fi
    local -a request_args=(python3 "$CHPC_REPO/scripts/lib/globus_transfer_request.py"
      --source-collection "$src" --source-path "$src_path"
      --destination-collection "$dst" --destination-path "$dst_path"
      "--label=$LABEL" --submission-id "$submission")
    [ -z "$SYNC_LEVEL" ] || request_args+=(--sync-level "$SYNC_LEVEL")
    for pattern in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do request_args+=("--exclude=$pattern"); done
    for pattern in "${EXCLUDE_DIRS[@]+"${EXCLUDE_DIRS[@]}"}"; do request_args+=("--exclude-dir=$pattern"); done
    request=$("${request_args[@]}")
    argv=("$GLOBUS" api transfer post /transfer --body "$request" --jmespath task_id -F unix)
  fi
  if [ "$DRY_RUN" = 1 ]; then
    run "${argv[@]}"
    [ "$WAIT_S" = 0 ] || printf 'RUN %s task wait <the-id-that-printed> --timeout %s\n' "$GLOBUS" "$WAIT_S"
    return 0
  fi
  task=$("${argv[@]}")
  [ -n "$task" ] || die "the transfer was queued but its task id could not be read;
  find it with: globus task list"
  echo "task $task queued: $src:$src_path -> $dst:$dst_path" >&2
  if [ "$WAIT_S" = 0 ]; then printf '%s\n' "$task"; return 0; fi
  # A timeout may leave the task running; inspect its status before retrying.
  "$GLOBUS" task wait "$task" --timeout "$WAIT_S" >&2 || die "task $task did not complete successfully within ${WAIT_S}s. No further commands were run.
  Inspect its status and errors before retrying: globus task show $task"
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
CHPC_PROJECT=$CHPC_PROJECT
CHPC_GLOBUS_SCRATCH_COLLECTION=$CHPC_GLOBUS_SCRATCH_COLLECTION
CHPC_GLOBUS_SCRATCH_ROOT=$CHPC_GLOBUS_SCRATCH_ROOT
CHPC_GLOBUS_STAGING=$CHPC_GLOBUS_STAGING
CHPC_GLOBUS_LOCAL_COLLECTION=${local_id:-<unset, and no local collection detected>}
CHPC_GLOBUS_LOCAL_ROOT=${CHPC_GLOBUS_LOCAL_ROOT:-/}
CHPC_GLOBUS_STAGING_LOCAL=${CHPC_GLOBUS_STAGING_LOCAL:-<unset; optional>}
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

  CHPC_GLOBUS_LOCAL_COLLECTION=$local_id
  CHPC_GLOBUS_LOCAL_ROOT=${CHPC_GLOBUS_LOCAL_ROOT:-/}
  local selected
  selected=$(absolute_path "${1:-$CHPC_PROJECT}")
  if check_local_access "$selected" source; then
    say local_project ok "$selected is accessible through the collection"
  else
    say local_project fail "$selected is not ready; see the original error and remedy above"
  fi
  if [ -n "${CHPC_GLOBUS_STAGING_LOCAL:-}" ]; then
    say local_staging info "$CHPC_GLOBUS_STAGING_LOCAL (optional fallback; unused for direct project transfers)"
  else
    say local_staging info "unset; direct project transfers do not need a staging folder"
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
  [ -z "$PATH_TYPE" ] || die "--type is only used with pull"
  [ -e "$src" ] || die "'$src' does not exist here"
  src=$(absolute_path "$src")
  case $dst in /*) ;; *) die "cluster destination must be an absolute path" ;; esac
  dst=$(absolute_path "$dst")
  local recursive=0; [ -d "$src" ] && recursive=1
  local src_rel dst_rel buffer
  src_rel=$(collection_path "$CHPC_GLOBUS_LOCAL_ROOT" "$src" "source")
  check_local_access "$src" source

  case $dst in
    "$CHPC_GLOBUS_SCRATCH_ROOT"|"$CHPC_GLOBUS_SCRATCH_ROOT"/*)
      echo "one leg: '$dst' is inside the scratch collection" >&2
      dst_rel=$(collection_path "$CHPC_GLOBUS_SCRATCH_ROOT" "$dst" destination)
      transfer "$CHPC_GLOBUS_LOCAL_COLLECTION" "$src_rel" \
               "$CHPC_GLOBUS_SCRATCH_COLLECTION" "$dst_rel" "$recursive"
      ;;
    *)
      [ "$WAIT_S" != 0 ] || die "--wait 0 is unsafe for a two-leg FAC push: the Globus transfer must finish before the cluster-local copy. Use a positive --wait timeout."
      buffer="$CHPC_GLOBUS_STAGING/transfer-$(date +%s)-$$/$(basename "$dst")"
      echo "two legs: no Globus collection covers '$dst', so it goes via $buffer" >&2
      dst_rel=$(collection_path "$CHPC_GLOBUS_SCRATCH_ROOT" "$buffer" staging)
      transfer "$CHPC_GLOBUS_LOCAL_COLLECTION" "$src_rel" \
               "$CHPC_GLOBUS_SCRATCH_COLLECTION" "$dst_rel" "$recursive"
      # The destination's parent may not exist yet, and a directory created at
      # the share root inherits the owner DENY (docs/02): the mkdir succeeds
      # and the cp into it then fails with "Permission denied" for the very
      # person running it (seen 2026-09-26, creating $CHPC_LAB/lib). So the
      # topmost directory the mkdir creates is repaired BEFORE the copy, and
      # what landed is repaired after it. Repairing only the new directory,
      # not the parent, keeps this off an existing tree's every file.
      #
      # chpc-fac-fixacl is named by path, $CHPC_LAB/bin, with PATH as the
      # fallback: a plain `ssh host cmd` shell has sourced no chpc.env and has
      # no $CHPC_LAB/bin on its PATH (verified 2026-09-26, in a login shell
      # too), and the repair is not optional for a new directory.
      local fix_path="$CHPC_LAB/bin/chpc-fac-fixacl" make_dir copy_src copy_dst
      make_dir=$(dirname "$dst")
      copy_src=$buffer
      copy_dst=$dst
      if [ "$recursive" = 1 ]; then
        make_dir=$dst
        copy_src=$buffer/.
        copy_dst=$dst/
      fi
      run_remote "$(printf 'set -e; fix=%q; [ -x "$fix" ] || fix=$(command -v chpc-fac-fixacl 2>/dev/null || true); d=%q; new=; while [ ! -e "$d" ] && [ "$d" != / ]; do new=$d; d=$(dirname "$d"); done; mkdir -p %q; if [ -n "$fix" ]; then [ -z "$new" ] || "$fix" "$new"; else echo "chpc-fac-fixacl not at %q and not on PATH; %q may be unreadable by its own owner" >&2; fi; if [ %q = 0 ] && [ -d %q ]; then echo "file destination is an existing directory" >&2; exit 1; fi; cp -a %q %q; [ -z "$fix" ] || "$fix" %q' \
                    "$fix_path" "$make_dir" "$make_dir" "$fix_path" "$dst" "$recursive" "$dst" "$copy_src" "$copy_dst" "$dst")"
      echo "landed at $dst; the copy in $buffer is a buffer and scratch is purged at 30 days" >&2
      ;;
  esac
}

pull_recursive() {
  local collection=$1 path=$2 detected
  case $PATH_TYPE in file) echo 0; return ;; directory) echo 1; return ;; esac
  if [ "$DRY_RUN" = 1 ]; then
    echo "source type check skipped (--dry-run): assuming directory; use --type file for a file" >&2
    echo 1
    return
  fi
  detected=$("$GLOBUS" stat "$collection:$path" --jmespath type -F unix) || return 1
  case $detected in
    dir) echo 1 ;;
    file) echo 0 ;;
    *) die "cannot determine source type for '$collection:$path' (got '$detected'); check globus stat before retrying" ;;
  esac
}

cmd_pull() {
  local src=$1 dst=$2
  require_local_setup
  dst=$(absolute_path "$dst")
  case $src in /*) ;; *) die "cluster source must be an absolute path" ;; esac
  src=$(absolute_path "$src")
  local dst_rel src_rel buffer recursive=1
  if [ "$PATH_TYPE" = file ] && { [ ${#EXCLUDES[@]} -gt 0 ] || [ ${#EXCLUDE_DIRS[@]} -gt 0 ]; }; then
    die "--exclude and --exclude-dir apply only to directory transfers"
  fi
  dst_rel=$(collection_path "$CHPC_GLOBUS_LOCAL_ROOT" "$dst" destination)
  check_local_access "$dst" destination

  case $src in
    "$CHPC_GLOBUS_SCRATCH_ROOT"|"$CHPC_GLOBUS_SCRATCH_ROOT"/*)
      echo "one leg: '$src' is inside the scratch collection" >&2
      src_rel=$(collection_path "$CHPC_GLOBUS_SCRATCH_ROOT" "$src" source)
      recursive=$(pull_recursive "$CHPC_GLOBUS_SCRATCH_COLLECTION" "$src_rel")
      transfer "$CHPC_GLOBUS_SCRATCH_COLLECTION" "$src_rel" \
               "$CHPC_GLOBUS_LOCAL_COLLECTION" "$dst_rel" "$recursive"
      ;;
    *)
      buffer="$CHPC_GLOBUS_STAGING/transfer-$(date +%s)-$$/$(basename "$src")"
      echo "two legs: no Globus collection covers '$src', so it goes via $buffer" >&2
      # Refuse before the copy, not after it: a buffer filled outside the
      # collection is work done for a transfer that cannot read it.
      src_rel=$(collection_path "$CHPC_GLOBUS_SCRATCH_ROOT" "$buffer" staging)
      # Verify scratch consent/access before a potentially large local copy.
      [ "$DRY_RUN" = 1 ] || "$GLOBUS" ls "$CHPC_GLOBUS_SCRATCH_COLLECTION:/" >/dev/null
      run_remote "$(printf 'set -e; mkdir -p %q; cp -a %q %q' \
                    "$(dirname "$buffer")" "$src" "$buffer")"
      recursive=$(pull_recursive "$CHPC_GLOBUS_SCRATCH_COLLECTION" "$src_rel")
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
    --label|--wait|--exclude|--exclude-dir|--sync-level|--type)
      [ $# -ge 2 ] || die "$1 needs a value"
      case $1 in
        --label) LABEL=$2 ;;
        --wait) WAIT_S=$2 ;;
        --exclude) EXCLUDES+=("$2") ;;
        --exclude-dir) EXCLUDE_DIRS+=("$2") ;;
        --sync-level) SYNC_LEVEL=$2 ;;
        --type) PATH_TYPE=$2 ;;
      esac
      shift ;;
    --) shift; args+=("$@"); break ;;
    -h|--help) sed -n '2,33p' "$_s"; exit 0 ;;
    -*) die "unknown option '$1'" ;;
    *) args+=("$1") ;;
  esac
  shift
done
case $WAIT_S in ''|*[!0-9]*) die "--wait must be a non-negative integer" ;; esac
case $SYNC_LEVEL in ''|exists|size|mtime|checksum) ;; *) die "--sync-level must be exists, size, mtime, or checksum" ;; esac
case $PATH_TYPE in ''|file|directory) ;; *) die "--type must be file or directory" ;; esac
: "${LABEL:=chpc-${verb:-globus}-$(date +%Y%m%d-%H%M%S)}"

case $verb in
  env)    cmd_env ;;
  doctor) [ ${#args[@]} -le 1 ] || die "usage: chpc-globus.sh doctor [local-path]"
          [ "$DRY_RUN" != 1 ] || die "doctor performs live checks; --dry-run is for push/pull"
          cmd_doctor "${args[0]:-$CHPC_PROJECT}" ;;
  push)   [ ${#args[@]} -eq 2 ] || die "usage: chpc-globus.sh push <local> <cluster>"
          cmd_push "${args[0]}" "${args[1]}" ;;
  pull)   [ ${#args[@]} -eq 2 ] || die "usage: chpc-globus.sh pull <cluster> <local>"
          cmd_pull "${args[0]}" "${args[1]}" ;;
  ""|-h|--help) sed -n '2,33p' "$_s"; exit 0 ;;
  *)      die "unknown verb '$verb'. One of: doctor env push pull" ;;
esac
