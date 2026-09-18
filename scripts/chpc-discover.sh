#!/usr/bin/env bash
# Capture live CoreHPC facts as Markdown.
# From a laptop, through the primed SSH alias ($CHPC_HOST, default chpc):
#   chpc-discover.sh                  # writes $CHPC_REPO/docs/cluster-facts.md
#   chpc-discover.sh --out FILE       # write elsewhere, e.g. into the project
#                                     # that embeds this repo; "-" = stdout
#   CHPC_FACTS_OUT=FILE chpc-discover.sh     # same, via the environment
#   chpc-discover.sh --gpu            # also capture nvidia-smi from a REAL gpu
#                                     # job; queues briefly, so it is opt-in
# On the login node:
#   bash chpc-discover.sh --local > cluster-facts.md
set -uo pipefail

remote_script() {
# Injected, because the heredoc below is quoted and expands nothing.
printf 'WANT_GPU=%s\n' "${want_gpu:-0}"
cat <<'REMOTE'
set -uo pipefail
section() { printf '\n## %s\n\n' "$1"; }
code() { printf '```\n'; "$@" 2>&1 | tr -d '\r' | head -n "${LINES_MAX:-400}"; printf '```\n'; }
LINES_MAX=400
echo "# CoreHPC live facts"
echo
echo "Captured $(date -u '+%Y-%m-%d %H:%M UTC') on $(hostname) by $USER with scripts/chpc-discover.sh."
section "Identity and groups"; code id
section "OS / kernel"; code sh -c 'cat /etc/os-release | head -4; uname -r'
section "SLURM version"; code sinfo --version
section "Partitions (sinfo)"; code sinfo -o "%P %a %l %D %c %m %G %N"
section "Node summary"; code sinfo -o "%P %n %e %m %a %c %C %G" 
section "Partition config (scontrol)"; code scontrol show partition
section "QoS"; code sacctmgr show qos format=Name,Priority,MaxWall,MaxTRESPU%40,MaxJobsPU,MaxSubmitPU,GrpTRES%30 -P
section "My associations (accounts/QoS I can use)"; code sacctmgr show assoc user="$USER" format=Cluster,Account,Partition,QOS%40,MaxJobs,MaxSubmit -P
section "GRES types"; code sh -c 'sinfo -o "%G" | sort -u'
# Everything else here runs on the LOGIN NODE, which has no GPU and no
# nvidia-smi -- so every capture before this recorded the GRES name and no
# driver or CUDA version at all. An image built against a newer CUDA than the
# node driver supports fails at run time, which made that omission expensive.
# This is the only section that queues a job, so it is opt-in via --gpu.
# The account is read back from the user's own associations rather than
# hardcoded, so this works for any lab on the cluster.
if [ "${WANT_GPU:-0}" = 1 ]; then
section "GPU detail (from a real gpu job, not the login node)"
# `< /dev/null` is load-bearing. This whole script is fed to `bash -l -s` over
# ssh, so the script itself IS stdin -- and srun reads stdin to forward it to
# the task. Without the redirect srun swallows every remaining line and the
# capture just stops here: measured, it silently truncated 27 sections to 10,
# losing storage, modules, Apptainer and the proxy, while still exiting 0.
code sh -c '_a=$(sacctmgr -nP show assoc user="$USER" format=Account | head -1); srun -p gpu --gres=gpu:1 -t 00:05:00 ${_a:+-A "$_a"} nvidia-smi < /dev/null'
fi
section "Storage: mounts"; code sh -c 'df -hT /home/remote 2>/dev/null; df -hT /mnt/scratch 2>/dev/null; df -hT /mnt/fac 2>/dev/null; mount | grep -E "vast|/mnt/fac|/mnt/scratch" '
section "Storage: my quota (userquota)"; code sh -c 'userquota 2>/dev/null || /usr/local/bin/userquota'
section "Storage: FAC shares I belong to"; code sh -c 'ls -la /mnt/fac/ | grep -E "^total|$(id -Gn | tr " " "|")"'
section "Storage: group scratch dirs I belong to"; code sh -c 'ls -la /mnt/scratch/group/ | grep -E "^total|$(id -Gn | tr " " "|")"'
section "Storage: my scratch"; code ls -la "/mnt/scratch/user/$USER"
section "Modules: default loaded"; code sh -c 'module list 2>&1'
section "Modules: top level"; code sh -c 'module avail 2>&1'
section "Modules: CBI collection"; code sh -c 'module load CBI 2>&1; module avail 2>&1'
section "Modules: Sali collection"; code sh -c 'module purge; module load Sali 2>&1; module avail 2>&1'
section "Modules: RAD collection"; code sh -c 'module purge; module load RAD 2>&1; module avail 2>&1'
section "Modules: nvidia-hpc collection"; code sh -c 'module purge; module load nvidia-hpc 2>&1; module avail 2>&1'
section "Apptainer"; code sh -c 'which apptainer; apptainer --version; apptainer buildcfg 2>/dev/null | grep -Ei "^(BIND PATH|ALLOW SETUID|MOUNT HOME|USER NAMESPACE|ENABLE FUSEMOUNT|ENABLE OVERLAY|NVIDIA)" ; echo "subuid entry: $(grep -c "^$USER:" /etc/subuid 2>/dev/null) (1 = --fakeroot allowed)"'
section "Apptainer site config (bind paths)"; code sh -c 'grep -vE "^\s*#|^\s*$" /etc/apptainer/apptainer.conf 2>/dev/null | grep -iE "bind|mount|user|nvidia" '
section "Internet proxy on login node"; code sh -c 'env | grep -i proxy; curl -sI --max-time 10 https://github.com | head -1'
section "Python / conda"; code sh -c 'module purge; module load CBI miniforge3 2>&1; which conda mamba python; conda --version; echo _CONDA_ROOT=$_CONDA_ROOT'
section "Misc tools"; code sh -c 'for t in tmux screen git rsync globus nvidia-smi jupyter singularity; do printf "%-12s %s\n" "$t" "$(command -v $t || echo -)"; done'
section "Current queue (all users, summary)"; code sh -c 'squeue -o "%P %T" -h | sort | uniq -c'
section "My recent jobs (7 days)"; code sacct -u "$USER" -S "$(date -d '7 days ago' +%F 2>/dev/null || date -v-7d +%F)" --format=JobID,JobName%20,Partition,State,Elapsed,MaxRSS,AllocTRES%40 -P
REMOTE
}

run_local=0; want_gpu=0; out=${CHPC_FACTS_OUT:-}
while [[ $# -gt 0 ]]; do
  case $1 in
    --local) run_local=1 ;;
    --gpu) want_gpu=1 ;;
    --out) out=${2:?--out needs a path}; shift ;;
    --out=*) out=${1#--out=} ;;
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ $run_local == 1 ]]; then
  bash -l -c "$(remote_script)"
  exit
fi

_s=${BASH_SOURCE[0]}; while [ -L "$_s" ]; do _d=$(cd "$(dirname "$_s")" && pwd); _s=$(readlink "$_s"); [[ $_s == /* ]] || _s=$_d/$_s; done
# shellcheck source=../env.sh
source "$(cd "$(dirname "$_s")/.." && pwd)/env.sh"
: "${out:=$CHPC_REPO/docs/cluster-facts.md}"

ssh -O check "$CHPC_HOST" >/dev/null 2>&1 || "$CHPC_REPO/scripts/chpc-prime.sh"
if [[ $out == - ]]; then
  exec ssh "$CHPC_HOST" 'bash -l -s' <<<"$(remote_script)"
fi
mkdir -p "$(dirname "$out")"
ssh "$CHPC_HOST" 'bash -l -s' <<<"$(remote_script)" > "$out.tmp" && mv "$out.tmp" "$out"
echo "wrote $out"
