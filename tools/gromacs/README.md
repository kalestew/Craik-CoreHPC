# GROMACS 2026.3

| | |
|---|---|
| Status | planned — recipe, entry and a GPU-node `test.sh` written; not yet built |
| Image to be | `gromacs_2026.3.sif` from [`gromacs_2026.3.def`](gromacs_2026.3.def), compiled from source on `nvidia/cuda:13.2.1-devel-ubuntu24.04` |
| GPU | yes. Compiled for sm_89, sm_90 **and** sm_120, so every GPU model in the partition works; `GPU_MAX_CC` is empty |
| Weights | none. Force fields and `spc216.gro` ship in `share/gromacs/top` |
| Licence | LGPL-2.1 — **nothing to obtain** |
| Upstream | <https://www.gromacs.org/>, `gromacs-2026.3.tar.gz`, md5 `7987af0c6ab939ab6e639f32d0dd260f` |
| Citation | Abraham et al., *SoftwareX* **1**, 2015; and cite the version used |

The third molecular dynamics option, beside [`openmm`](../openmm/README.md) and
the licensed [`amber`](../amber/README.md). Of the three it is the only one with
**neither a licence to chase nor a conda solve to get wrong** — the trade being
that it has to be compiled.

## Not built yet

```bash
chpc-tool build gromacs              # login node; a LONG compile, tens of minutes
chpc-tool publish gromacs
chpc-tool test gromacs               # GPU NODE REQUIRED -- this is what `verified` means
```

The intended commands, from [`test.sh`](test.sh) and **not yet run**:

```bash
salloc -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 16G -t 2:00:00
chpc-tool exec gromacs -- gmx grompp -f md.mdp -c conf.gro -p topol.top -o md.tpr  # (untested)
chpc-tool exec gromacs -- gmx mdrun -deffnm md -nb gpu -pme gpu -bonded gpu        # (untested)
```

Any GPU model works — `nvidia_l40s`, `nvidia_h100_nvl` or `nvidia_rtx_pro_6000`.

Build and publish: [`../README.md`, Add a tool](../README.md#add-a-tool).

## The module check is done, and the answer is no

This entry's note used to say: look in the Sali and CBI collections first, and
if a GPU-enabled `gromacs` module already exists, switch to `KIND=module` and
delete the image. Checked on **2026-09-26**:

```
module -t spider gromacs     ->  Unable to find: "gromacs"
module -t spider amber       ->  Unable to find: "amber"
module -t spider openmm      ->  Unable to find: "openmm"
```

and the same after loading each of `CBI`, `RAD`, `Sali` and `nvidia-hpc` and
searching the resulting `MODULEPATH`. There is no molecular dynamics engine of
any kind in the module collections on this cluster, so the image is owed and
`KIND` stays `container`.

## Why it is compiled rather than pulled

Both official containers are too old to run on this hardware:

| Image | Newest tag | Why not |
|---|---|---|
| `nvcr.io/hpc/gromacs` (NVIDIA NGC) | **2023.2**, pushed 2023-08-18 | its own page lists Pascal, Volta, Ampere and Hopper — **no Ada**, so not the L40S, and no Blackwell |
| `gromacs/gromacs` (Docker Hub) | **2022.2**, CUDA 11.6 | CUDA 11.6 cannot target sm_120 at all |

There is no GROMACS-project-maintained end-user container. A three-year-old
image with no kernels for two of our three GPU models is not a shortcut, so the
recipe builds 2026.3 from the upstream tarball with the md5 checked.

## Do not miss

- **ALWAYS PASS `-nb gpu`.** Left to itself, `mdrun` decides whether to offload
  and **falls back to the CPU silently** when it cannot. That is a correct
  simulation at a fraction of the speed, with nothing in the output saying
  anything is wrong — the single easiest way to waste a week of GPU allocation
  here. With `-nb gpu`, `mdrun` **aborts** instead, with "Nonbonded
  interactions on the GPU were required, but not supported for these simulation
  settings", which is what a job script wants.
- **`gmx --version` saying `GPU support: CUDA` is not evidence a kernel ran.**
  It is a statement about how the binary was compiled. Read `md.log` and look
  for `1 GPU selected for this run.`, `PP tasks will do ... short-ranged ...
  interactions on the GPU`, and `PME tasks will do all aspects on the GPU`.
  Those three lines are what [`test.sh`](test.sh) asserts.
- **`GMX_SIMD` is pinned, and auto-detection is the trap.** cmake detects SIMD
  from the machine doing the configuring, and that is always the login node,
  because it is the only node with internet. On a cluster whose login and
  compute CPUs differ, auto-detection produces a binary that is either slower
  than it should be or **illegal** on the compute nodes — and the symptom of the
  second is `SIGILL` in a job, not an error at build time. Measured here: the
  login node is an AMD EPYC-Genoa and the GPU nodes are AMD EPYC 9354P, also
  Genoa, and both report `avx`, `avx2`, `fma`, `avx512f`, `avx512bw` and
  `avx512vl` — so auto-detection would in fact have been safe **today**. It is
  pinned anyway, because that is a property of this cluster on this date rather
  than something a recipe should depend on silently.
- **`AVX2_256` versus `AVX_512` is unbenchmarked here.** `AVX2_256` is
  GROMACS's long-standing recommendation for AMD Zen and is correct on every
  node we have. Whether `AVX_512` is faster on Zen 4 specifically is worth
  measuring against this image rather than assuming in either direction.
- **`gmx solvate` appends to `topol.top`, it does not create it.** The `[
  molecules ]` section has to exist first, or the `SOL` count goes nowhere and
  `grompp` then fails about a mismatch between coordinates and topology.
- **`mdrun` will take every core on the node**, not the cores Slurm allocated,
  so `%environment` sets `OMP_NUM_THREADS` from `$SLURM_CPUS_PER_TASK`.

---

## Provenance

**Never run.** `STATUS=planned`; the image is not built. Everything below is
what the recipe and test will establish.

### CUDA 13 is the known risk

Support for compiling with the CUDA 13 toolkit landed in GROMACS 2025.3, so
2026.3 accepts it — but upstream's CI covers **CUDA 12.1, 12.5.1 and 12.6
only**. This combination is therefore supported and untested by upstream, and it
is the most likely thing to go wrong in the build.

The base is pinned to `13.2.1` rather than a newer 13.x on purpose: the compute
nodes' driver (595.71.05) reports CUDA **13.2**, and matching it exactly avoids
the class of problem that bit [`openmm`](../openmm/README.md) — a newer CUDA
minor version emitting PTX an older driver cannot load. GROMACS compiles its
kernels ahead of time rather than at run time, so it is less exposed than OpenMM
is, but there is no reason to take the risk for nothing.

### What `test.sh` will prove

The fixture is upstream's own `spc216.gro` and OPLS-AA force field, both of
which ship inside `share/gromacs/top`, so nothing is downloaded.

| # | Asserted |
|---|---|
| 0 | `gmx --version` reports `GPU support: CUDA` |
| 1 | `gmx solvate` places **more than 200** SPC waters in a 2.5 nm box, and appends a `SOL` count |
| 2 | energy minimisation on the **CPU** reaches a plausible condensed-phase energy: below −1000 kJ/mol total, and between −60 and −25 kJ/mol **per water** |
| 3 | 2000 steps of MD with **`-nb gpu -pme gpu`**, so offload is mandatory and `mdrun` aborts rather than falling back |
| 4 | `md.log` contains `1 GPU selected for this run.`, short-ranged nonbonded work on the GPU, **and** PME on the GPU |

Stage 2 is deliberately on the CPU: it proves the topology and force field are
self-consistent enough to produce forces at all, so a failure in stage 3 is
unambiguously about the GPU rather than about the inputs. The per-water band is
wide because this is a 200-step minimisation of a freshly solvated box rather
than an equilibrated simulation — the purpose is to catch an energy that is
absurd, such as a box whose nonbonded terms never contributed and which sits
near zero, not to reproduce a published number.

Stage 4 is the one the file exists for. Stages 0 through 3 can all pass on an
image that silently did the work on the CPU.

### Verified against upstream, 2026-09-26

- GROMACS 2026.3 is the current stable release, with the tarball and md5 above,
  and a matching `regressiontests-2026.3.tar.gz` for a more rigorous suite than
  this `test.sh`;
- `-DGMX_GPU=CUDA` is the switch, `-DCMAKE_CUDA_ARCHITECTURES` takes a
  semicolon-delimited list of two- or three-digit suffixes, and CUDA 12.1 or
  newer is required with compute capability 5.0 or above;
- CUDA 13 compilation support arrived in 2025.3, and upstream CI covers 12.1,
  12.5.1 and 12.6;
- both official container registries' newest tags and the GPU architectures the
  NGC page claims;
- that `-nb gpu` makes offload mandatory and aborts otherwise, and the three
  `md.log` lines that report the task assignment;
- that `spc216.gro` and `oplsaa.ff` ship in `share/gromacs/top`;
- the CPU flags on the login node and on a GPU node, quoted under "Do not miss".

**Not** verified, and left to the first run: the actual per-water energy this
build produces (recorded as the regression baseline the first time `test.sh`
passes), whether `AVX_512` beats `AVX2_256` on our Genoa nodes, and how long
the compile takes.
