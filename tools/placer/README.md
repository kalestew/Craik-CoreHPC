# PLACER

| | |
|---|---|
| Built | 2026-09-19, kanderson6, CoreHPC login node |
| Image | `placer_1.0.sif` — an environment, **no code and no weights** |
| Recipe | [`placer_1.0.def`](placer_1.0.def) |
| Upstream | `baker-laboratory/PLACER` @ `7dc5563` |
| Code + weights | on FAC at `$CHPC_LAB/data/placer` (`PLACER_DIR`) |
| Base | `pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime` |
| Licence | BSD-3-Clause — source **and** weights |
| GPU | yes — **not on Blackwell**, `GPU_MAX_CC=9.0` |

## The image holds no PLACER

Unusually for this registry, the checkout lives outside the image. The jobs
invoke `run_PLACER.py` by path and `cd` into the checkout, the weights are
only ~100 MB, and PLACER is a research tree that gets pulled rather than
released — so a PLACER update is a `git pull` on the share, not a rebuild of a
9 GB image. `PLACER_DIR` is exported by the registry because the path is a
site fact.

```
git clone https://github.com/baker-laboratory/PLACER "$CHPC_LAB/data/placer"
git -C "$CHPC_LAB/data/placer" checkout --detach 7dc5563
```

## One conda install replaced torch

The first version of this recipe installed openbabel the obvious way:

```
conda install -c conda-forge openbabel=3.1.1
```

With conda-forge at top priority the solver does not just add openbabel, it
rewrites the base environment underneath torch:

```
pytorch   2.3.1-py3.10_cuda12.1_cudnn8.9.2_0 --> 2.0.1-py3.10_cpu_0
pytorch-mutex                       1.0-cuda --> 1.0-cpu
mkl                                 2023.1.0 --> 2025.0.0
numpy                                 1.26.4 --> 2.2.5
```

A CPU-only torch 2.0.1, in a CUDA image, from one `conda install`. It
surfaced as

```
libtorch_cpu.so: undefined symbol: iJIT_NotifyEvent
```

which is the mkl-2025/torch mismatch and reads like a packaging bug — so the
tempting fix is to pin mkl. That would have been the wrong fix: the symbol was
a symptom, and had mkl happened to stay compatible the build would have
**succeeded** and shipped an image whose GPU silently did not exist. The crash
was the lucky outcome.

What makes this worth writing down is that the recipe already contained the
warning. Three paragraphs above the offending line, the e3nn comment says
choosing conda "resolves pytorch as a dependency from conda-forge and can
replace the cu121 torch this entire stack is pinned to". The reasoning was
right and was applied to e3nn only. The rule is not "be careful with conda",
it is: **nothing in a pinned-torch image goes through a conda solve** — and,
since care is not a mechanism, the recipe now asserts it:

```python
assert torch.version.cuda == "12.1", f"not a cu121 torch: cuda={torch.version.cuda}"
```

A CPU build reports `torch.version.cuda is None`, so any future dependency
that swaps torch fails the build instead of shipping.

## openbabel comes from a wheel, and needs two system libraries

`openbabel-wheel==3.1.1.23` is a manylinux build of openbabel's own 3.1.1
source. It installs in seconds, touches nothing else, and is the reason this
recipe no longer has a 60-minute conda solve.

It has one trap. Every format plugin links **both** `libXrender` and
`libXext`, and if either is missing each plugin fails to load independently:

```
*** Open Babel Error in openLib
  .../openbabel/3.1.0/pdbformat.so did not load properly.
  Error: libXrender.so.1: cannot open shared object file
```

openbabel itself still imports, and `OBReleaseVersion()` still answers — but
**no format is registered**, so `OBConversion.SetInFormat('pdb')` returns
`False` and every read silently yields an empty molecule.

The two libraries are separate packages and `libxrender1` does **not** pull
`libxext6`: it brings libX11, libxcb, libXau and libXdmcp, and that is all.
Installing only `libxrender1` moves the error to the identical message about
`libXext.so.6` and changes nothing else — which is exactly what happened here,
on the build after the first fix. About 2 MB for both.

This is why `%post` and `%test` assert on `SetInFormat` rather than on the
import: the import is the thing that keeps working. The assertion is what
turned the second missing library into a build failure with a name in it
instead of a PLACER run that read every structure as empty.

Measured with both libraries present: `3rgk.pdb` → 1232 atoms, 150 residues.

PLACER only uses `from openbabel import openbabel`, never `pybel`, so pybel's
separate import-time format enumeration does not matter here.

## Traps

- **PLACER's multi-model output must be split before scoring.**
  `catalytic_geometry.measure()` reads model 0, so handing it the ensemble
  scores sample 1 *n* times and reports a preorganisation fraction of exactly
  0.000 or 1.000 — the degeneracy PLACER was added to remove. `test.sh`
  asserts the model count *and* that the coordinates differ between samples,
  because an ensemble of identical models passes a count on its own.
- **Preorganisation from a constrained relax is not a measurement.** The
  enzdes constraints impose the geometry regardless of substrate, which is how
  every cascade differential came back at exactly +0.000. Measured spread over
  the round-0 human IgG1 complex: relax ensemble 0.00–0.02 Å, PLACER ensemble
  0.35–0.68 Å.
- **`--target_res` is required when the input has no ligand.** `test.sh` uses
  upstream's own `4dtz.cif` example rather than a generated backbone, because
  ligand-pocket repacking is what PLACER is for.
- **e3nn 0.5.4 does not exist on PyPI.** PLACER's lockfile names it; the index
  goes 0.5.3 → 0.5.5. Pinned to 0.5.5 here — see the recipe for why going
  through conda to get 0.5.4 exactly would be the worse trade, which the
  section above then demonstrated at first hand.
- **Not on Blackwell.** cu121 emits no `sm_120`, so `ggpu1-[13-19]` dies at the
  first kernel launch. `GPU_MAX_CC=9.0` makes `chpc-tool` refuse up front, and
  `jobs/placer_states.sbatch` is pinned to `--gres=gpu:nvidia_l40s:1`.
