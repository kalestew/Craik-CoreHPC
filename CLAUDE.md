# CLAUDE.md

## What this is

`Craik-CoreHPC` is the Craik Lab's **CoreHPC field guide and tool registry** —
the onboarding path for the whole lab, and the thing embedded as a submodule
(`corehpc/` or `submodules/corehpc`) in Hap108or, IgGase_eng and the
usergroup repo. `lab/README.md` is the reference; this file is how to work on
it without rediscovering the constraints.

Migrated from the retired auto-memory store on 2026-10-21. Account access
(`ssh chpc`, VPN, Duo, the login-shell proxy, `srun` stdin) is in
`~/.claude/CLAUDE.md`. Cluster facts belong to whoever measured them, dated.

## The four constraints that shape the whole loop

Learned 2026-09-26/27.

1. **Compute nodes have no internet at all** — not even through
   `chpc-proxy-vm1`. Tested from `ccpu1-01`: `curl` fails with "Could not
   connect to server" both directly and via the proxy. So every container
   build and every download runs on the **login node**, and a CUDA base image
   build is 10 to 15 minutes.
2. **Never wait on a GPU test synchronously, and never use interactive `srun`
   for one** — the job dies with the ssh client. `sbatch`, writing to a log
   under `~/verify/`, then poll.
3. **A batch script that calls `chpc-tool exec` must
   `eval "$(chpc-tool export <tool>)"` itself.** `chpc-tool test` sets the
   entry's variables; `exec` does not. A job passing
   `--model-dir="$INTELLIFOLD_MODEL_DIR"` without the `eval` passes an empty
   string, and the tool then tries to download weights from a node with no
   internet — which reads as a network fault rather than a missing export.
4. **Nothing syncs the checkout to the FAC share.** After changing `tools/`,
   `lab/bin/` or `templates/slurm/`, run the rsync-and-cp block from
   `lab/README.md`, "Keeping the share's copy current", or the share's
   `chpc-tool` keeps reading the old registry.

## The GPU cap is sometimes the bottleneck and sometimes not

Do not plan around it either way without looking. On 2026-09-26 three arrays
of ~270 tasks each held the 8-GPU `QOSMaxGRESPerUser` cap for hours — Kyle's
own jobs. On 2026-09-27 the queue was empty, `ggpu1-[08-11]` and `ggpu4-03`
were idle, and six GPU jobs in a row started within seconds. Check
`squeue -u kanderson6` and `sinfo -p gpu` first.

**Route CPU-only tests to `community` or `community_short`** (the latter needs
`--qos=cmnt_short`). Those partitions are near-idle and run immediately, which
is how several tools got verified while the GPU queue was full. Some GPU tools
run correctly on CPU, just slowly — rfdiffusion3's full four-stage test took
8 m 42 s on 16 cores of `ccpu1-04` — so a CPU partition can verify everything
that is not device-specific.

## `chpc-tool build` only works from a checkout, never from the share

The share carries `bin/`, `lib/`, `tools/` and `slurm/` but **not**
`templates/apptainer/build.sh`, so `chpc-tool build` run via `$CHPC_LAB/bin`
exits immediately with "no build helper at … (is this a full checkout?)". Use
`cd ~/corehpc && ./lab/bin/chpc-tool build <tool>`. **A backgrounded build
that seems to finish in seconds has almost certainly hit this.**

`chpc-tool doctor` from the share takes ~11 minutes (NFS image probes); not
investigated.

## The edit round-trip

Edit on the Mac → commit → `git push` → on the login node
`git -C ~/corehpc fetch && git reset --hard origin/<branch>` → sync the share.

**The login node can pull over HTTPS but cannot push** (port 22 blocked
outbound), so the Mac is always the origin of changes.

## Lab convention and transfer policy

**Convention, set 2026-09-26:** every lab member keeps **one projects folder**
on their Mac, clones this repo into it, and exposes that folder in Globus
Connect Personal's Accessible Folders. There is no staging clone —
`chpc-globus.sh push/pull` and `chpc-submit.sh` read the working copy. Keep
shared docs free of one person's paths; use `~/projects` in examples rather
than anyone's real volume.

**Transfer policy, settled with the cluster admins 2026-09-26:** Globus is the
approved path and `chpc-globus.sh` is the scripted route. A FAC destination is
always **two legs**, via `$CHPC_USER_SCRATCH/globus-staging`, repaired with
`chpc-fac-fixacl` named by path. `chpc-stage.sh` is a **retired stub** that
refuses and prints the Globus equivalent — kept deliberately, with a test.
Laptop side: globus CLI logged in, GCP root `/`, and the gitignored
`lab/chpc.env.local` sets `CHPC_GLOBUS_STAGING_LOCAL`.

## Notes

- **Detached downloads over ssh get refused by the auto-mode classifier.** Hand
  those commands to Kyle rather than retrying them.
- **When a measurement lands, update the README sentence that documents the
  gap**, not just `tool.conf`. The docs say where a gap is; leaving that
  sentence stale is worse than the gap.
- The colabfold README does not mention the 1 TB ColabFold mmseqs set under
  `data/mmseqs2`.
- This repo is **private on GitHub** because it holds the FAC share ID, bastion
  hostnames and Globus collection IDs. Lab members need collaborator access to
  init the submodule. `origin` pushes to both GitLab and GitHub — push via
  `origin`, never commit to the GitHub copy directly.
