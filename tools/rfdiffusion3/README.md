# RFdiffusion3 (rc-foundry)

| | |
|---|---|
| Built | 2026-09-18, kanderson6, CoreHPC login node (1172 s) |
| Image | `rfdiffusion3_0.2.0.sif`, 3.65 GB — no weights |
| Recipe | [`rfdiffusion3_0.2.0.def`](rfdiffusion3_0.2.0.def) |
| Upstream | `rosettacommons/foundry:0.2.0-slim`, `rc-foundry==0.2.0` |
| Weights | 5.7 GB on FAC (`rfd3` + `rf3`), via [`fetch-weights.sh`](fetch-weights.sh) |
| Base | upstream's own slim image (python 3.12, torch 2.7.1+cu126) |
| Licence | BSD-3-Clause |
| GPU | yes — **not on Blackwell**, see below |

## This is not RFdiffusion, and not RFdiffusion2

Three separate registry entries on purpose. RFdiffusion3 has no repository of
its own: it ships as the `rfd3` model inside `RosettaCommons/foundry`, with a
different CLI, different weights and a different licence lineage from v1. v1
stays because the round-0 exosite track is written against its hydra config.

## Hardware: it cannot use the Blackwell nodes

Measured inside the image, not inferred from the tag:

```
torch 2.7.1+cu126
torch._C._cuda_getArchFlags() -> sm_50 sm_60 sm_70 sm_75 sm_80 sm_86 sm_90
```

No `sm_120`. The newest tool in the registry, on the newest CUDA base of any
GPU tool here, still cannot run on `ggpu1-[13-19]` — CUDA 12.6 predates
Blackwell, and "recent tool" is not "recent enough CUDA". Use
`--gres=gpu:nvidia_l40s:1` or an H100, never a bare `--gres=gpu:1`.

## Weights

```bash
tools/rfdiffusion3/fetch-weights.sh              # rfd3 + rf3, 5.7 GB
tools/rfdiffusion3/fetch-weights.sh rfd3na       # add the nucleic-acid model
```

Default is `rfd3 rf3`, **not `all`**. `all` is ~14.6 GB and also pulls
foundry's own ProteinMPNN, LigandMPNN and SolubleMPNN — which this registry
already carries as separate entries with their own pinned commits. Two copies
of the same weights under different provenance is how a result stops being
reproducible.

Valid names, from `foundry list-available`: `rfd3` `rfd3na` `rf3`
`proteinmpnn` `ligandmpnn` `solublempnn` `rf3_preprint_921`
`rf3_preprint_124` `all`. **There is no `base-models` target**, despite being
the obvious guess — this entry's `tool_doctor` used to recommend exactly
that.

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
- **`APPDIR` is `/app/foundry`, not `/opt/foundry`.** It is upstream's `uv`
  project root, with the real environment under `.venv/`.
- `--checkpoint-dir` is passed explicitly by the fetch script.
  `FOUNDRY_CHECKPOINT_DIRS` is a *search* path for reading; `install` on its
  own still defaults to `~/.foundry/checkpoints`, and home is 20 GiB here.
