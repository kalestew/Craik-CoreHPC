# RFdiffusion (v1)

| | |
|---|---|
| Status | verified — `chpc-tool test rfdiffusion` passes (a 20-residue backbone, CA–CA spacing in range). The entry records no date, GPU model or job id for that run; add them at the next one. |
| Image | `rfdiffusion_1.1.sif`, 4.19 GB — no weights; recipe [`rfdiffusion_1.1.def`](rfdiffusion_1.1.def) |
| GPU | `--gres=gpu:nvidia_l40s:1` (or `nvidia_h100_nvl:1`), never a bare `gpu:1` — `GPU_MAX_CC=9.0`: the image is cu121 and emits no `sm_120`, so a Blackwell node dies at the first kernel launch ([`../README.md`](../README.md#which-gpu)) |
| Weights | 3.7 GiB over 9 files at `$RFDIFFUSION_MODELS` (`$CHPC_LAB/data/rfdiffusion/models`), fetched by [`fetch-weights.sh`](fetch-weights.sh) |
| Schedules | writable IGSO3 cache at `$RFDIFFUSION_SCHEDULES` (`$CHPC_LAB/data/rfdiffusion/schedules`) — see "Do not miss" |
| Base | `pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime` |
| Licence | BSD-3-Clause — source **and** weights |
| Upstream | `RosettaCommons/RFdiffusion` @ `86507b65` |

This is v1, deliberately kept alongside `rfdiffusion3`: different weights,
different CLI, different licence lineage, and the round-0 exosite track is
written against v1's hydra config.

## Run it

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/rfdiffusion/run1 && cd "$_"   # hydra writes outputs/ into the cwd, so be in one you own
eval "$(chpc-tool export rfdiffusion)"                         # RFDIFFUSION_MODELS, RFDIFFUSION_SCHEDULES in THIS shell
chpc-tool exec rfdiffusion -- python /opt/RFdiffusion/scripts/run_inference.py \
    "inference.model_directory_path=$RFDIFFUSION_MODELS" \
    "inference.schedule_directory_path=$RFDIFFUSION_SCHEDULES" \
    inference.output_prefix=out/design \
    inference.num_designs=10 \
    'contigmap.contigs=[100-100]'
```

Quote the contigs: unquoted, the shell eats the brackets. `python` is spelled
out because the entry's `ENTRY` is not prepended in front of a bare script
path. `inference.num_designs=10` and the 100-residue contig are a plausible
first run **(untested)** — the self-test makes one 20-residue backbone. Leave
`diffuser.T` alone: the self-test sets it to 15, the floor, purely for speed;
the default is 50 and that is what a real design wants.

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines to
the values above. The method, the `eval` idiom and which GPU to ask for:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

The input is the contig string, not a file: `contigmap.contigs=[100-100]` is
one unconditional chain of 100 residues (the self-test's `[20-20]` produced
exactly 20 CA atoms). Motif scaffolding adds `inference.input_pdb=motif.pdb`
and a contig that names the motif's segments **(untested here)**.

Output goes where `inference.output_prefix` points:
`out/design_0.pdb` … `out/design_9.pdb`, plus a `.trb` per design
**(untested — the self-test asserts only the PDB)**. The designs are
independent draws numbered in generation order; nothing in the output ranks
them, and RFdiffusion writes backbones only — no sequence, no side chains.

Before trusting one: RFdiffusion can write a file of NaN coordinates and exit
0 when the checkpoint half-loads, which is why `test.sh` checks the coordinate
columns and the consecutive CA–CA distance (3.0–4.6 Å) rather than the exit
status. Do the same to anything you keep.

## Do not miss

- **`inference.schedule_directory_path` is not optional.** RFdiffusion
  defaults it to a `schedules/` directory *inside the installed package*,
  which it mkdirs and writes IGSO3 tables into on first run — and the package
  lives in a read-only squashfs, so the default fails with a permission error
  that looks nothing like a config problem. Point it at the writable FAC
  directory the registry exports and the tables compute once.
- **It is a hydra app: it creates `outputs/<date>/<time>/` in the current
  working directory** whether you asked for it or not. `cd` into a scratch
  directory first.
- **Spell out `python`.** `ENTRY` is not prepended in front of a bare script
  path, so the program after `--` has to be `python` and the script its first
  argument, exactly as the block above has it.
- **L40S or H100 only.** `GPU_MAX_CC=9.0` makes `chpc-tool` refuse a Blackwell
  node up front; `jobs/rfdiff_exosite.sbatch` is pinned to
  `--gres=gpu:nvidia_l40s:1` for the same reason.

---

## Provenance

Built 2026-09-19 by kanderson6 on the CoreHPC login node, 1686 s, 4.19 GB.
Measured in the built image: torch 2.3.1, cuda 12.1, and
`torch._C._cuda_getArchFlags()` → `sm_50 sm_60 sm_61 sm_70 sm_75 sm_80 sm_86
sm_90` — no `sm_120`, which is where `GPU_MAX_CC=9.0` comes from.

`chpc-tool test rfdiffusion` generates one 20-residue unconditional backbone
(`diffuser.T=15`, the floor) and asserts 20 CA atoms, finite coordinates in
the x/y/z columns and CA–CA spacing in range — the difference between "wrote a
PDB" and "diffused a protein". It proves the whole path: hydra config,
checkpoint load, the SE3Transformer forward, PDB output. The date and GPU
model of the passing run were not recorded; the test refuses to be meaningful
anywhere but an L40S or H100/H200.

## Build notes

### Not built from upstream's env/SE3nv.yml

That file asks for python 3.9, pytorch 1.9 and cudatoolkit 11.1, and CUDA
11.1 emits kernels for **none** of this cluster's GPUs. An image built to
upstream's spec would import cleanly, allocate cleanly, and die on the first
forward pass. Upstream's README says to edit the file for your GPU; this
recipe is that edit, written down.

The replacement is torch 2.3.1 + cu121 + DGL, chosen because DGL is the
binding constraint — it publishes no wheels past torch 2.4, and the
SE3Transformer RFdiffusion vendors is a DGL program. `tools/placer` uses the
same stack for the same reason.

### Pins and downloads

- **e3nn 0.5.4 does not exist on PyPI.** PLACER's lockfile names it and it is
  real on conda-forge, but the PyPI index goes 0.5.3 → 0.5.5. This recipe
  pins **0.5.5**; going through conda to get the exact version would let
  conda resolve pytorch from conda-forge and replace the cu121 torch the
  whole stack depends on, which is a far worse failure than a patch version's
  drift. Verified: 0.5.5 resolves against dgl 2.4.0+cu121 and torch 2.3.1.
- **The weights' download URLs are not checksums.** The path component of
  each `files.ipd.uw.edu` URL looks like a content hash and is not —
  `f572d396fae9206628714fb2ce00f72e` is md5 of `"hello\n"`. `fetch-weights.sh`
  carries a locally-measured md5 manifest *and* verifies each file as a zip
  archive with per-member CRC32, which needs no manifest to be right.
- The recipe installs the vendored SE3Transformer and rfdiffusion with
  `--no-deps`: `env/SE3Transformer/requirements.txt` pins e3nn 0.3.3, wandb
  0.12.0 and decorator 5.1.0, a 2021 set pip would install straight over the
  stack above. Those pins are upstream's snapshot, not requirements.
