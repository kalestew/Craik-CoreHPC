#!/usr/bin/env bash
# Open (or verify) the Duo-authenticated master SSH sessions to CoreHPC.
# Usage: chpc-prime.sh [--reset]
# Host aliases come from env.sh: $CHPC_HOST (default chpc), $CHPC_BASTION.
set -euo pipefail
_s=${BASH_SOURCE[0]}; while [ -L "$_s" ]; do _d=$(cd "$(dirname "$_s")" && pwd); _s=$(readlink "$_s"); [[ $_s == /* ]] || _s=$_d/$_s; done
# shellcheck source=../env.sh
source "$(cd "$(dirname "$_s")/.." && pwd)/env.sh"

if [[ "${1:-}" == "--reset" ]]; then
  ssh -O exit "$CHPC_HOST" 2>/dev/null || true
  ssh -O exit "$CHPC_BASTION" 2>/dev/null || true
  rm -f ~/.ssh/cm-*@chpc-* 2>/dev/null || true
fi
if ssh -O check "$CHPC_HOST" >/dev/null 2>&1; then
  echo "master session to $CHPC_HOST already open"
else
  echo "priming $CHPC_HOST: answer the Duo prompt if asked"
  ssh "$CHPC_HOST" hostname
fi
