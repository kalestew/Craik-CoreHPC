# RFdiffusion3 (rc-foundry)

| | |
|---|---|
| Status | built 2026-09-18 — `chpc-tool test rfdiffusion3` proves the image runs and both checkpoints deserialise; **no design has been run here**, so there is no known-good command yet |
| Image | `rfdiffusion3_0.2.0.sif`, 3.65 GB, no weights inside; recipe [`rfdiffusion3_0.2.0.def`](rfdiffusion3_0.2.0.def) |
| GPU | `--gres=gpu:nvidia_l40s:1` or `--gres=gpu:nvidia_h100_nvl:1` (`GPU_MAX_CC=9.0`). Never a bare `--gres=gpu:1` |
| Weights | 5.7 GB at `$FOUNDRY_CHECKPOINT_DIRS` (`$CHPC_LAB/data/rfdiffusion3`) for the default `rfd3 rf3`; 14.6 GB if you ask for `all`. Fetched by [`fetch-weights.sh`](fetch-weights.sh) on the login node |
| Licence | BSD-3-Clause, code and weights; commercial use permitted |
| Upstream | `rosettacommons/foundry:0.2.0-slim`, `rc-foundry==0.2.0` |

## Run it

**There is no known-good command for this entry yet, and nothing below has
produced a backbone.** What is proven is narrower than the `built` status
suggests: `chpc-tool test rfdiffusion3` loads the image, resolves both
checkpoints through the registry the inference engines themselves call, and
asserts a parameter count on each ([`test.sh`](test.sh):5-10, :22-29). The
image and the weights are sound; the science path is not.

The gap is deliberate rather than lazy. `rfd3` is a typer wrapper over a hydra
app whose `--help` documents no config keys at all, and upstream ships its
examples as notebooks rather than commands, so a minimal end-to-end invocation
is not something to guess at.

The shape, taken from the recipe's `%help` and **untested**:

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/rfdiffusion3/run1 && cd "$_"
chpc-tool exec rfdiffusion3 -- rfd3 design out_dir=out inputs=spec.json   # (untested)
```

`exec` exports `FOUNDRY_CHECKPOINT_DIRS` inside the container, so that line
needs no `eval`. The checkpoints themselves are installed once, on the login
node, by [`fetch-weights.sh`](fetch-weights.sh).

**Use [`../rfdiffusion`](../rfdiffusion) (v1) meanwhile.** It is verified, it
has a working command in its README, and the round-0 exosite track is written
against its hydra config anyway.

Whoever gets the first invocation to produce a design: put it here with the
production defaults it used, add it to [`test.sh`](test.sh) as a real case, and
set `STATUS=verified` in `tool.conf` with the date and the GPU model. A job
script is then `templates/slurm/tool-gpu.sbatch` with its four EDIT lines set
to the values above ([`../README.md`](../README.md#run-a-tool-on-your-inputs)).

## Inputs and outputs

Unknown, and that is the honest answer. `inputs=spec.json` in the recipe's
`%help` is the only public hint at the input format, and the output layout has
not been seen here. Hydra apps write relative to the working directory, and v1
drops an `outputs/` tree into the current directory, so `cd` into a scratch
directory before running anything (untested for v3).

**This is not RFdiffusion, and not RFdiffusion2.** Three separate registry
entries on purpose. RFdiffusion3 has no repository of its own: it ships as the
`rfd3` model inside `RosettaCommons/foundry`, with a different CLI, different
weights and a different licence lineage from v1. v1 stays because the round-0
exosite track is written against its hydra config — and, today, because it is
the entry with a command that works.

foundry also provides `rf3` (structure prediction) and `mpnn`. This entry
exposes `rfd3`; the others would be separate entries, each with its own status
and doctor check.

## Do not miss

- **`WRITABLE_TMPFS=1` is already set in `tool.conf`, and it is required.**
  Without it foundry dies mid-download with `OSError: [Errno 30] Read-only file
  system: '/app/foundry/.tmp_jyowbq10'` — an error that names neither `.env`
  nor dotenv nor configuration. The full story is in Traps; the thing to know
  is that a published `$CHPC_LAB/bin/rfdiffusion3` wrapper does not set the
  overlay, so use `chpc-tool exec`.
- **`foundry list-installed` reports nothing even when resolution works.** It
  printed "No checkpoint files found in any checkpoint directory" on
  2026-09-18 with `FOUNDRY_CHECKPOINT_DIRS` set correctly and the files visible
  inside the container ([`test.sh`](test.sh):22-29). Do not read it as an
  installation failure, and never assert on it.
- **Pass `--checkpoint-dir` explicitly to `foundry install`.**
  `FOUNDRY_CHECKPOINT_DIRS` is a *search* path for reading; `install` on its
  own still defaults to `~/.foundry/checkpoints`, and home is 20 GiB here
  against ~14 GB of checkpoints.
- **L40S or H100 only.** torch 2.7.1+cu126 has no `sm_120`, so the Blackwell
  nodes `ggpu1-[13-19]` are out. `chpc-tool exec` refuses them up front; the
  `--gres` line is what decides where the job lands.

---

## Provenance

Built 2026-09-18 by kanderson6 on the CoreHPC login node (1172 s), from
upstream's own `0.2.0-slim` image rather than a pip install into a pytorch base.

`chpc-tool test rfdiffusion3` (CPU is fine) proves three things: both
checkpoint files exist and are non-empty; the resolver the engines call,
`checkpoint_registry.get_default_checkpoint_dirs()`, has
`$FOUNDRY_CHECKPOINT_DIRS` in its search path; and both checkpoints deserialise
with `torch.load` into a `model` dict holding more than 10^7 parameters. A
truncated download is still a file and still passes `test -s`, which is why the
load is part of the test and not just a path check.

It does not prove that a design runs, and no design has been attempted. That is
why this entry is `built` rather than `verified`, and why the Status row names
no job id or GPU model: the test needs neither.

Hardware, measured inside the image rather than inferred from the tag:

```
torch 2.7.1+cu126
torch._C._cuda_getArchFlags() -> sm_50 sm_60 sm_70 sm_75 sm_80 sm_86 sm_90
```

No `sm_120`. The newest tool in the registry, on the newest CUDA base of any
GPU tool here, still cannot run on `ggpu1-[13-19]` — CUDA 12.6 predates
Blackwell, and "recent tool" is not "recent enough CUDA".

Taken on trust: that what `foundry install` downloads is what upstream intends.
The fetch asserts on the artefacts — at least two checkpoint files, none empty
— because upstream publishes no checksums to assert against.

## Build notes

Built on upstream's own slim image rather than pip-installing `rc-foundry` into
a pytorch base. Two reasons: foundry pins python >=3.12,<3.13 together with
cuequivariance CUDA-12 wheels, a combination that is fiddly to reproduce and
that upstream has already solved; and `slim` (3.47 GB) is the variant *without*
checkpoints, which is what we want — the weights belong on FAC, where
refreshing them does not mean rebuilding an 18 GB image. `%post` therefore
asserts what we depend on (the four console scripts, python 3.12) instead of
reinstalling it, so a future tag that moves them fails the build rather than a
design job.

### Weights

```bash
tools/rfdiffusion3/fetch-weights.sh              # rfd3 + rf3, 5.7 GB
tools/rfdiffusion3/fetch-weights.sh rfd3na       # add the nucleic-acid model
```

Default is `rfd3 rf3`, **not `all`**. `all` is 14.6 GB and also pulls foundry's
own ProteinMPNN, LigandMPNN and SolubleMPNN — which this registry already
carries as separate entries with their own pinned commits. Two copies of the
same weights under different provenance is how a result stops being
reproducible.

Valid names, from `foundry list-available`: `rfd3` `rfd3na` `rf3`
`proteinmpnn` `ligandmpnn` `solublempnn` `rf3_preprint_921`
`rf3_preprint_124` `all`.

`base-models` is valid too — it is what upstream's README recommends — but it
appears in **neither** `foundry install --help` nor `list-available`, so the
CLI gives no sign it exists. `download_checkpoints.py:175` expands it to
`rfd3 rfd3na proteinmpnn ligandmpnn rf3`. I initially concluded from the CLI
that it was not a real target; it is, and the documentation was right where the
tool's own help was silent.

## Traps

- **`WRITABLE_TMPFS=1` is required, and the error that proves it names
  nothing useful.** `foundry` persists its checkpoint directory by calling
  `dotenv.set_key()` on `/app/foundry/.env`, inside the read-only image.
  python-dotenv rewrites atomically, so it creates a sibling temp file and
  you get

  ```
  OSError: [Errno 30] Read-only file system: '/app/foundry/.tmp_jyowbq10'
  ```

  mid-download, with no mention of `.env`, dotenv, or configuration. Two
  plausible fixes do **not** work: changing the working directory (apptainer
  does inherit the host's, and `find_dotenv()` walks up from the calling
  module's path, not cwd), and binding a writable `.env` over the file (the
  temp file is a *sibling*, so the directory must be writable, not the file).
  The overlay is in memory and discarded at exit, which is correct here: the
  write is 2.5 KB of config nobody needs to keep.
- **`foundry list-installed` is a reporting command, not evidence.** Observed
  2026-09-18: it reports no checkpoints on an installation that inference
  resolves perfectly well. It appears to resolve by some other route, probably
  the `.env` the tmpfs overlay discards.
- **`APPDIR` is `/app/foundry`, not `/opt/foundry`.** It is upstream's `uv`
  project root, with the real environment under `.venv/`.
- `--checkpoint-dir` is passed explicitly by the fetch script.
  `FOUNDRY_CHECKPOINT_DIRS` is a *search* path for reading; `install` on its
  own still defaults to `~/.foundry/checkpoints`, and home is 20 GiB here.
