# RFdiffusion (v1)

| | |
|---|---|
| Built | 2026-09-19, kanderson6, CoreHPC login node (1686 s) |
| Image | `rfdiffusion_1.1.sif`, 4.19 GB — no weights |
| Recipe | [`rfdiffusion_1.1.def`](rfdiffusion_1.1.def) |
| Upstream | `RosettaCommons/RFdiffusion` @ `86507b65` |
| Weights | 3.7 GiB on FAC (9 files), via [`fetch-weights.sh`](fetch-weights.sh) |
| Base | `pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime` |
| Licence | BSD-3-Clause — source **and** weights |
| GPU | yes — **not on Blackwell**, see below |

This is v1, deliberately kept alongside `rfdiffusion3`: different weights,
different CLI, different licence lineage, and the round-0 exosite track is
written against v1's hydra config.

## Not built from upstream's env/SE3nv.yml

That file asks for python 3.9, pytorch 1.9 and cudatoolkit 11.1, and CUDA
11.1 emits kernels for **none** of this cluster's GPUs. An image built to
upstream's spec would import cleanly, allocate cleanly, and die on the first
forward pass. Upstream's README says to edit the file for your GPU; this
recipe is that edit, written down.

The replacement is torch 2.3.1 + cu121 + DGL, chosen because DGL is the
binding constraint — it publishes no wheels past torch 2.4, and the
SE3Transformer RFdiffusion vendors is a DGL program. `tools/placer` uses the
same stack for the same reason.

## Hardware: it cannot use the Blackwell nodes

Measured in the built image:

```
torch 2.3.1, cuda 12.1
torch._C._cuda_getArchFlags()
  -> sm_50 sm_60 sm_61 sm_70 sm_75 sm_80 sm_86 sm_90
```

No `sm_120`. `jobs/rfdiff_exosite.sbatch` is pinned to
`--gres=gpu:nvidia_l40s:1` for exactly this reason.

## Traps

- **`inference.schedule_directory_path` is not optional.** RFdiffusion
  defaults it to a `schedules/` directory *inside the installed package*,
  which it mkdirs and writes IGSO3 tables into on first run — and the package
  lives in a read-only squashfs. Point it at the writable FAC directory the
  registry exports; the tables then compute once and are reused instead of
  every job paying the "Calculating IGSO3" cost.
- **RFdiffusion is a hydra app: it creates `outputs/<date>/<time>/` in the
  current working directory** whether you asked for it or not. `cd` into the
  output directory first.
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
