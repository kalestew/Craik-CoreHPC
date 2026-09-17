#!/usr/bin/env bash
# Open (or verify) the Duo-authenticated master SSH sessions to CoreHPC.
# Usage: scripts/chpc-prime.sh [--reset]
set -euo pipefail
if [[ "${1:-}" == "--reset" ]]; then
  ssh -O exit chpc 2>/dev/null || true
  ssh -O exit chpc-bastion 2>/dev/null || true
  rm -f ~/.ssh/cm-*@chpc-* 2>/dev/null || true
fi
if ssh -O check chpc >/dev/null 2>&1; then
  echo "master session to chpc already open"
else
  echo "priming: answer the Duo prompt if asked"
  ssh chpc hostname
fi
