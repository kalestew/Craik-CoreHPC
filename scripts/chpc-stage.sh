#!/usr/bin/env bash
# rsync a local path to CoreHPC through the primed SSH master session.
#
# ---------------------------------------------------------------------------
# POLICY WARNING (added 2026-09-24, after reviewing the CoreHPC training)
#
# This is NOT an approved transfer path. The AUP lists three -- Globus, the FAC
# share, and Open OnDemand -- and the 2026-09-11 CoreHPC session stated that
# transferring files through the bastion is not permitted, for security and
# PHI-compliance reasons; an attendee's scp to the UCSF bastion failed live.
#
# This script predates that finding and is kept because retiring it is the
# owner's call, not a doc edit's.
#
# USE scripts/chpc-globus.sh INSTEAD. As of 2026-09-26 the approved path is
# scripted and first-party: it takes the same two arguments, works out whether
# the destination needs one leg or two, repairs the FAC ACL on what it lands,
# and has a --dry-run that prints the route. Nothing should depend on this file.
# ---------------------------------------------------------------------------
# Usage:   chpc-stage.sh <local-path> <remote-path> [extra rsync args]
# Example: chpc-stage.sh ./inputs/ "$CHPC_GROUP_SCRATCH/proj/inputs/"
# Host alias comes from env.sh: $CHPC_HOST (default chpc).
set -euo pipefail
_s=${BASH_SOURCE[0]}; while [ -L "$_s" ]; do _d=$(cd "$(dirname "$_s")" && pwd); _s=$(readlink "$_s"); [[ $_s == /* ]] || _s=$_d/$_s; done
# shellcheck source=../env.sh
source "$(cd "$(dirname "$_s")/.." && pwd)/env.sh"

[[ $# -ge 2 ]] || { echo "usage: $(basename "$0") <local-path> <remote-path> [rsync args]" >&2; exit 1; }
src=$1; dst=$2; shift 2
ssh -O check "$CHPC_HOST" >/dev/null 2>&1 || "$CHPC_REPO/scripts/chpc-prime.sh"
exec rsync -avP --partial --no-perms --omit-dir-times "$@" "$src" "$CHPC_HOST:$dst"
