#!/usr/bin/env bash
# Retired SSH/rsync transfer entry point. Keep the filename so older callers
# get an actionable error instead of silently using the wrong transport.
set -eu
cat >&2 <<'MESSAGE'
chpc-stage.sh is retired. Use Globus for laptop/cluster file transfers:

  chpc-globus.sh doctor ./inputs
  chpc-globus.sh push ./inputs "$CHPC_USER_SCRATCH/myproject/inputs"

To transfer a self-contained job folder and submit its batch script:

  chpc-submit.sh ./job-folder job.sbatch --dry-run

See docs/02-storage-and-data.md. No files were transferred.
MESSAGE
case ${1:-} in -h|--help) exit 0 ;; *) exit 2 ;; esac
