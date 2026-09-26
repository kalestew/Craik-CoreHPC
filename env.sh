# shellcheck shell=bash
# Craik-CoreHPC entry point. Source it from bash or zsh, at any path, on a
# laptop or on the cluster, from a standalone checkout or a git submodule:
#
#     source path/to/corehpc/env.sh
#
# Exports
#   CHPC_REPO      absolute path of this checkout (symlinks resolved)
#   CHPC_PROJECT   the repo that embeds this one as a submodule, else CHPC_REPO
#   CHPC_HOST      SSH alias of the login node                default: chpc
#   CHPC_BASTION   SSH alias of the bastion                   default: $CHPC_HOST-bastion
#   CHPC_USER      campus username: `ssh -G $CHPC_HOST` off-cluster, $USER on it
#   CHPC_ENV       path of lab/chpc.env in this checkout. sbatch's default
#                  --export=ALL carries it into jobs; the templates source it.
#   CHPC_TOOLS     path of tools/ in this checkout: the tool registry that
#                  chpc-tool and chpc-assets read.
#   CHPC_*         cluster paths from lab/chpc.env
#   PATH           += $CHPC_REPO/scripts and $CHPC_REPO/lab/bin
#
# Overrides: the first existing file of $CHPC_ENV_LOCAL,
# $CHPC_PROJECT/chpc.env.local, $CHPC_REPO/lab/chpc.env.local is sourced
# before lab/chpc.env. Set inputs there (FAC_SHARE, CHPC_HOST, CHPC_USER),
# not derived paths.
#
# That file is sourced as-is, so a plain `CHPC_USER=jdoe` in it BEATS a value
# you exported in the shell. Write `CHPC_USER="${CHPC_USER:-jdoe}"` if you want
# the environment to win -- see chpc.env.local.example, which uses that form
# throughout. (This comment used to claim the environment always won. It does
# not, and nothing enforced it.)

# --- locate this file, through symlinks, in bash or zsh ----------------------
if [ -n "${ZSH_VERSION:-}" ]; then
  _chpc_src=${(%):-%x}
else
  _chpc_src=${BASH_SOURCE[0]}
fi
while [ -L "$_chpc_src" ]; do
  _chpc_dir=$(cd "$(dirname "$_chpc_src")" && pwd)
  _chpc_src=$(readlink "$_chpc_src")
  case $_chpc_src in /*) ;; *) _chpc_src=$_chpc_dir/$_chpc_src ;; esac
done
CHPC_REPO=$(cd "$(dirname "$_chpc_src")" && pwd -P)
export CHPC_REPO

# --- the project that embeds us (git superproject), else ourselves -----------
_chpc_super=$(git -C "$CHPC_REPO" rev-parse --show-superproject-working-tree 2>/dev/null || true)
CHPC_PROJECT=${_chpc_super:-$CHPC_REPO}
export CHPC_PROJECT

# --- per-project overrides ---------------------------------------------------
for _chpc_f in "${CHPC_ENV_LOCAL:-}" "$CHPC_PROJECT/chpc.env.local" "$CHPC_REPO/lab/chpc.env.local"; do
  if [ -n "$_chpc_f" ] && [ -f "$_chpc_f" ]; then
    # shellcheck disable=SC1090
    source "$_chpc_f"
    CHPC_ENV_LOCAL=$_chpc_f
    export CHPC_ENV_LOCAL
    break
  fi
done

# --- SSH aliases and campus username -----------------------------------------
export CHPC_HOST="${CHPC_HOST:-chpc}"
export CHPC_BASTION="${CHPC_BASTION:-${CHPC_HOST}-bastion}"
if [ -z "${CHPC_USER:-}" ]; then
  if [ -d /mnt/scratch/user ]; then
    CHPC_USER=${USER:-$(id -un)}
  else
    CHPC_USER=$(ssh -G "$CHPC_HOST" 2>/dev/null | awk '/^user /{print $2; exit}' || true)
    case $CHPC_USER in ''|*'<'*) CHPC_USER=${USER:-$(id -un)} ;; esac   # no config yet, or placeholder
  fi
fi
export CHPC_USER

# --- lab environment ---------------------------------------------------------
CHPC_ENV=$CHPC_REPO/lab/chpc.env
export CHPC_ENV
# The tool registry, from THIS checkout rather than the copy on the share, so a
# project pinned to a commit gets the tool definitions that commit describes.
# Set before chpc.env is sourced, which only supplies a fallback.
CHPC_TOOLS=$CHPC_REPO/tools
export CHPC_TOOLS
# shellcheck source=lab/chpc.env
source "$CHPC_ENV"

# --- PATH --------------------------------------------------------------------
for _chpc_d in "$CHPC_REPO/lab/bin" "$CHPC_REPO/scripts"; do
  case ":$PATH:" in *":$_chpc_d:"*) ;; *) PATH=$_chpc_d:$PATH ;; esac
done
export PATH

# --- tab completion, interactive shells only ---------------------------------
case $- in *i*) [ -r "$CHPC_REPO/lab/bin/chpc-completion.bash" ] && . "$CHPC_REPO/lab/bin/chpc-completion.bash" ;; esac

unset _chpc_src _chpc_dir _chpc_super _chpc_f _chpc_d
