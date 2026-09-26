# PyMOL (open source)

| | |
|---|---|
| Status | verified (`chpc-tool test pymol`: a headless render writes a non-empty PNG; CPU, date not recorded) |
| Image | `pymol_opensource.sif`, 177 MB; recipe [`pymol_opensource.def`](pymol_opensource.def) |
| GPU | CPU (`-p cpu`) |
| Weights | none |
| Licence | BSD-like (open-source PyMOL, **not** the Schrödinger incentive build) |
| Upstream | Debian bookworm `pymol` package (2.5.0) = the open-source build |
| Base | `debian:12-slim` |
| Built | 2026-09-17, kanderson6, CoreHPC login node (267 s) |

## Run it

```bash
salloc -p cpu -c 8 --mem 16G -t 2:00:00
mkdir -p /mnt/scratch/user/$USER/pymol/run1 && cd "$_"   # in.pdb here; the same path is valid inside the container
chpc-tool exec pymol -- pymol -cq in.pdb -d "hide everything; show cartoon; png out.png, width=1200, height=900, dpi=300, ray=1"
```

`-cq` is command-line, quiet: no GUI. The `-d` string is any sequence of
PyMOL commands; `width=1200, height=900, dpi=300, ray=1` are figure settings
(untested: the self-test renders 200×200 at `dpi=72, ray=0`). For more than
one line, put the commands in a `.pml` and name it after the structure,
`chpc-tool exec pymol -- pymol -cq in.pdb figure.pml` (untested). No `eval`
is needed; the entry exports only the image path.

As a job: copy `templates/slurm/tool-gpu.sbatch` with `--partition=cpu` and no
`--gres` (drop its `nvidia-smi` line too), and set the other EDIT lines to the
values above. The method and the `eval` idiom:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

A structure file named on the command line, loaded before `-d` runs; the
self-test's is a generated 20-residue backbone PDB (`_template/make_test_pdb.sh`),
and PyMOL's other formats such as mmCIF load the same way (untested). Output
is whatever the commands write, here `out.png` in the working directory.
Nothing is ranked. Check the file, not the exit status: PyMOL exits 0 having
drawn nothing when the display path is wrong, and `test -s out.png` is the
self-test's whole assertion.

## Do not miss

- **Always pass `-cq`.** There is no display on a compute node; without it
  PyMOL waits for a GUI that never arrives and the job burns its walltime.
- **The PNG is the check, not the exit code.** `test -s out.png` after every
  render.
- **Open-source build only.** The Schrödinger distribution is separately
  licensed and must never go on the share; this image is Debian's `pymol`
  package, which is the open-source build (Build notes).

---

## Provenance

Built 2026-09-17 by kanderson6 on the CoreHPC login node (267 s), from
Debian bookworm's `pymol` package.

`chpc-tool test pymol`: loads a generated structure headless and renders a PNG,
asserting the **file exists and is non-empty**. That is the check that matters —
PyMOL exits 0 having drawn nothing when the display path is wrong, so an exit
status proves nothing about rendering.

## Build notes

- Deliberately the distro build. The Schrödinger distribution is separately
  licensed and must not be placed on a shared share.

## Traps

- **Always pass `-cq`** (command line, quiet). There is no display on a compute
  node; without it PyMOL waits for a GUI that never arrives and the job burns its
  walltime.
