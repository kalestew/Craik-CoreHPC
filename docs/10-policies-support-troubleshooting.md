# 10. Policies, support, and troubleshooting

## Acceptable Use Policy essentials (v1.01)

By using CoreHPC you accept the User Agreement. Points that matter daily:

- Personal accounts only, Duo required, no credential or key sharing.
- Access only from UCSF networks/VPN, from endpoints meeting the UCSF
  Minimum Endpoint Security Standard. Everything is logged.
- Data transfers only via Globus, the FAC share, or Open OnDemand. No
  persistent network services or exposure to external networks.
- The environment is built for Level 3/4 (sensitive/restricted, PHI, CUI,
  NIH) data. The PI owns classification, access control (least privilege),
  IRB/DUA compliance, training (HIPAA + security awareness) and lifecycle
  (retention, destruction). Level 4 data stays inside the environment and
  is never copied to unmanaged endpoints.
- No backups are guaranteed by CoreHPC.
- Be considerate: clean up temp files, request realistic time, keep only
  what is needed on scratch, never fake timestamps to dodge the purge.
- No crypto-mining, commercial work or unlicensed software. You are
  responsible for the licences of what you install (containers included).
- Report suspected compromise within one business day to
  CoreHPC@ucsf.edu and ITServiceDesk@ucsf.edu.
- Acknowledge in papers: "This research used the High Performance Computing
  Core Facility (CoreHPC) at the University of California, San Francisco."

## Planned downtimes (quarterly, roughly 7 am day 1 to 6 pm day 2)

- 7–8 October 2026
- 6–7 January 2027
- 7–8 April 2027
- 7–8 July 2027

Scratch is cleared during maintenance windows. Move anything you need to
FAC beforehand. Emergency outages are announced on Slack/email.

## Getting help

| Channel | Use |
|---------|-----|
| Ticket: <https://tiny.ucsf.edu/Gethpc> | accounts, POD access, group scratch creation, bugs, quota, anything official |
| CoreHPC user Slack (link on the wiki home page) | quick questions, outage chatter |
| ARS office hours, Tuesdays 10:10–11:00 (Zoom link on the wiki) | live help, Wynton migration |
| CoreHPC@ucsf.edu | condo purchases, incidents |
| Wynton-Transition@ucsf.edu | migration questions |
| FAC: <https://tiny.ucsf.edu/getfac> | storage share requests, capacity |

## Common problems

| Symptom | Likely cause / fix |
|---------|--------------------|
| `Permission denied (publickey,...)` at the bastion | key not in the bastion's own `~/.ssh/authorized_keys` (its home is separate), or VPN down |
| `ssh chpc` hangs or `Connection closed by UNKNOWN port 65535` | stale ControlMaster after VPN drop: `scripts/chpc-prime.sh --reset` |
| Duo prompt never appears | ControlMaster already open (good) or VS Code swallowed it: prime from a terminal |
| `Disk quota exceeded` in home | 20 GiB limit: move conda (`~/.conda`, `~/.condarc` dirs), `~/.cache`, `~/.apptainer`, `~/.vscode-server` to scratch; `userquota` |
| Files vanished from scratch | >30 days old or maintenance purge; restore from FAC |
| Job PENDING with `(Resources)` / `(Priority)` | normal queueing; `sprio -j`; ask for less, or use `community` |
| `(QOSMaxJobsPerUserLimit)` / `(AssocMaxJobsLimit)` | per-user limits (doc 05) |
| `Invalid account or account/partition combination` / `Invalid qos specification` | you targeted `pod`/`large_gpu`; our account `hpc_core` covers `cpu`, `gpu`, `community`, `community_short` |
| Job killed after exactly 1 hour | you did not pass `--time`; the default is 1 h on every partition |
| Pending forever: `Job's QOS not permitted to use this partition` | `community_short` needs `--qos=cmnt_short`; `squeue -j <id> -o %r` shows the reason |
| `apptainer pull` / `git clone` / `pip` fails only in `ssh chpc 'cmd'` one-liners | non-login shells lack the proxy variables; use `ssh chpc 'bash -lc "cmd"'` |
| `ssh: connect to host git.kalestew.io port 22: Network is unreachable` on the login node | outbound SSH is blocked; use the HTTPS URL with a deploy token |
| Apptainer build: `exec /.singularity.d/libs/fakeroot failed` | Alpine/musl base image; add `--ignore-fakeroot-command` |
| Apptainer build: `--fakeroot` fails | not enabled on CoreHPC; drop it |
| Job killed at exactly the time limit | add `--time`, checkpoint, or use `community` (336 h) |
| `OUT_OF_MEMORY` in `sacct` | raise `--mem`; check `MaxRSS` |
| `module: command not found` in a job | script does not start with `#!/bin/bash` or purges the profile; use `bash -l` or `source /etc/profile.d/lmod.sh` |
| `pip`/`conda`/`apptainer pull` hangs in a job | compute nodes have no internet; do it on the login node |
| Process killed on the login node | it was resource-intensive; run it in `salloc` |
| Container: `CUDA driver version is insufficient` | image built against a newer CUDA than the node driver supports; use an older base image |
| Container cannot see `/mnt/scratch` or `/mnt/fac` | add `--bind /mnt/scratch,/mnt/fac` (see doc 07) |
| GPU not visible in container | forgot `--nv` |
| `Slurmstepd: error: execve(): python: No such file` | conda env not activated inside the job script |

## Wynton transition

Wynton fully retires by February 2027. PI submits one transition request
per lab at <https://tiny.ucsf.edu/transition>; details at
<https://ars.ucsf.edu/wynton-transition-keeping-you-informed>. FAC/CoreHPC
is entirely separate from Wynton: nothing (storage, accounts, backups)
carries over. Move data via Globus (doc 02); translate scripts with doc 09.
