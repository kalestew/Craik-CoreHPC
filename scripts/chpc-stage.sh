#!/usr/bin/env bash
# rsync a local path to CoreHPC through the primed "chpc" SSH alias.
# Usage: scripts/chpc-stage.sh <local-path> <remote-path> [extra rsync args]
# Example: scripts/chpc-stage.sh ./inputs/ /mnt/scratch/group/CX000123_DS1/proj/inputs/
set -euo pipefail
[[ $# -ge 2 ]] || { echo "usage: $0 <local-path> <remote-path> [rsync args]"; exit 1; }
src=$1; dst=$2; shift 2
ssh -O check chpc >/dev/null 2>&1 || "$(dirname "$0")/chpc-prime.sh"
exec rsync -avP --partial --no-perms --omit-dir-times "$@" "$src" "chpc:$dst"
