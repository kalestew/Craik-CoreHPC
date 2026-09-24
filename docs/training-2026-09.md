# CoreHPC training, September 2026 — what it changed here

Two recorded sessions, *Introduction to CoreHPC* Parts 1 and 2, held jointly for
UCSF and Gladstone on 2026-09-10 and 2026-09-11, about 1 h 55 m each. Reviewed in
full on 2026-09-24 against every doc, template and script in this repo.

Materials: the Gladstone Bioinformatics-Workshops wiki
(<https://github.com/gladstone-institutes/Bioinformatics-Workshops/wiki/Introduction-to-CoreHPC>),
slides at `gladstone-institutes.github.io/Bioinformatics-Workshops/Intro_to_CoreHPC/`,
and a separate container guide (`Containers_on_CoreHPC.html`).

## How much authority to give it

Less than you would expect, on UCSF specifics. The presenter is a bioinformatician
in the Gladstone Bioinformatics Corps; the only IT staff on either call is from
Gladstone. UCSF-half questions were repeatedly and explicitly deferred:

- on partitions — "look at the UCSF documentation ... that'll give you the most
  up-to-date information"
- on FAC — "I don't know the path to the FAC storage"
- on getting data onto FAC — "I would contact UCSF IT ... exactly how they want
  you to get things onto the FAC share"
- on the wiki generally — "the wiki is maintained by UCSF ... a lot of these
  details are very specific to y'all"

It was also the first delivery of the workshop; three slide errors were corrected
live and the slides were to be revised afterwards. Treat it as authoritative on
**policy and intent**, and as hearsay on **numbers**. Where it disagrees with
`docs/cluster-facts.md` — which is `sinfo`/`scontrol`/`sacctmgr` output captured
from the live cluster — the captured output wins.

## Where the training is wrong for UCSF

| Training said | Cluster actually | Evidence |
|---|---|---|
| UCSF max walltime "48 hours or 2 days" (hedged) | `cpu` and `gpu` are **4 days**, `community` **14 days**, `large_gpu` 1 day | `cluster-facts.md` § Partitions |
| Omitting `--time` reserves the partition maximum, so you queue longer | `DefaultTime=01:00:00` on **every** partition. Omitting `--time` gets you one hour and your job is **killed**, not delayed. The failure mode is worse than described. | `cluster-facts.md` § Partition config |
| A long-running driver cannot be kept alive on the login node — "it won't allow for a tmux or a screen session" | `tmux`/`screen` do work, and `systemd-run --scope --user tmux` survives logout for up to 24 h. The real limits are that 24 h ceiling and the user slice's 8 GiB soft / 16 GiB hard memory cap. | docs 01, 03, 10 |
| Persistent storage is the slowest tier; "especially the FAC will be the slowest" | For CAS-shaped writes (64 KiB, fsync, rename) **FAC is 5.6x faster than group scratch**: /tmp ~3000 files/s, FAC ~1350, group scratch ~238. They are different appliances — scratch is NFSv3 on VAST, FAC is NFSv4.2 on `fac-ha`. | Hap108or ADR 0004; `cluster-facts.md` § Storage: mounts |

The storage one needs care rather than dismissal. The measurement is single-writer
throughput on one day; the trainers' concern is **aggregate metadata load on shared
storage**, which a one-writer benchmark cannot see, and which is exactly what a
content-addressed store generates. The benchmark also used *group* scratch, while
the guidance names *user* scratch. Open question below.

## Where it confirms what we already had

`--fakeroot` unavailable (`subuid entry: 0`); Apptainer present at
`/usr/bin/apptainer` with no module to load; builds and pulls on the login node
only; compute nodes have no internet; login node egress via a proxy; `--nv`
required for GPU visibility inside a container; Apptainer auto-binds only the
working directory and home; `module load CBI miniforge3` as two tokens; conda
envs and package caches redirected to scratch with `environment.yml` kept as the
recipe; 20 GiB home, 50 TiB scratch; `--mem` is a per-node total, not per-CPU;
`gpu` capped at 8 GPUs and 21 jobs per user.

One live retraction is worth recording because it matches our own capture: the
slide claiming per-user caps on running jobs was withdrawn mid-session — "there
is a per-user cap on the GPU jobs specifically, but the CPU jobs, there's no
[cap] currently." `sacctmgr` agrees: QoS `gpu` has `MaxJobsPU=21`, QoS `cpu` has
`MaxJobsPU` empty and only a `cpu=2048,node=8` TRES ceiling.

## What changed in this repo as a result

- **doc 02, doc 01** — `scp`/`rsync` over the SSH alias is no longer offered as a
  laptop-to-cluster transfer path. The AUP names three (Globus, the FAC share,
  Open OnDemand) and doc 02 already said so 23 lines below where it recommended
  `scp`. The training resolves the contradiction: transfer through the bastion is
  not permitted, and an attendee's `scp` failed live.
- **`scripts/chpc-stage.sh`** — carries a policy warning. Behaviour unchanged;
  retiring it is an owner decision.
- **doc 02** — records that *which* timestamp starts the 30-day purge is
  undocumented and was not settled on the call.
- **doc 04** — `seff` added to the monitoring table; a note that fair-share counts
  array *tasks*, so batching work per task preserves future priority.
- **`templates/slurm/gpu.sbatch`** — local `nvidia-smi` utilisation trace, since
  no compute node can reach a hosted dashboard.

Reviewing the training also meant re-reading every doc against
`cluster-facts.md`, which turned up errors the training had nothing to do with.
Fixed in the same pass:

- **doc 05** — the `pod` nodes were given as `gcpu3-[07-16]`; they are
  `ggpu3-[09-16]` (wrong prefix, and a ten-node range labelled as eight).
- **doc 02** — the login node was described as "32 cores, 125 GB, no ulimits".
  The user slice is capped at **4 CPUs, 8 GiB soft / 16 GiB hard**; `ulimit`
  shows nothing because those are cgroup limits. This is the doc most likely to
  send someone to run a build or a pipeline driver there.
- **doc 02** — "only ours mounts on access" was wrong: 387 FAC shares were
  mounted at capture. Only ours is *readable*.
- **doc 02** — the tier table's bare "slow" for FAC now carries the measured
  small-file numbers and the two caveats that stop them being over-generalised.
- **doc 04** — `nvhpc-hpcx/25.5` does not exist here (25.1 and 26.5 only).
- **doc 05** — gpu-node RAM is 386 GB on the L40S and H100 nodes, 380 GB on the
  RTX PRO 6000 nodes, not "~380 GB" for all three; `DefCpuPerGPU` is 25 on
  `large_gpu`, not 32 everywhere; queue figures at capture corrected.
- **README, doc 06** — `cluster-facts.md` was captured 2026-09-18, not 09-17.

## Open questions for UCSF CoreHPC support

1. Does the 30-day scratch purge key on creation, `mtime` or `atime`?
2. Is a content-addressed store doing sustained small-file `fsync` writes on a FAC
   share acceptable, given the "many small files degrade networked storage"
   guidance? If not, what is the sanctioned home for one?
3. Is user scratch (`/mnt/scratch/user/`) backed differently from group scratch
   (`/mnt/scratch/group/`)? The measured 5.6x gap between FAC and *group* scratch
   is large enough to suspect they are not the same service.
4. Does `--mail-user` work, given compute nodes have no egress? Unresolved on the
   call.
5. What is the current route to `pod` access, and is `large_gpu` still condo-only?
