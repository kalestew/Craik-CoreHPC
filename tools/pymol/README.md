# PyMOL (open source)

| | |
|---|---|
| Built | 2026-09-17, kanderson6, CoreHPC login node (267 s) |
| Image | `pymol_opensource.sif`, 177 MB |
| Recipe | [`pymol_opensource.def`](pymol_opensource.def) |
| Upstream | Debian bookworm `pymol` package = the open-source build |
| Base | `debian:12-slim` |
| Licence | BSD-like (open-source PyMOL, **not** the Schrödinger incentive build) |
| GPU | no |

## What the test proves

`chpc-tool test pymol`: loads a generated structure headless and renders a PNG,
asserting the **file exists and is non-empty**. That is the check that matters —
PyMOL exits 0 having drawn nothing when the display path is wrong, so an exit
status proves nothing about rendering.

## Traps

- **Always pass `-cq`** (command line, quiet). There is no display on a compute
  node; without it PyMOL waits for a GUI that never arrives and the job burns its
  walltime.
- Deliberately the distro build. The Schrödinger distribution is separately
  licensed and must not be placed on a shared share.
