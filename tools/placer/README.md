# PLACER

| | |
|---|---|
| Status | verified 2026-09-19 on an L40S (cc 8.9) — `chpc-tool test placer`: 3 models in `4dtz_selftest_model.pdb`, coordinates differ between samples, 3 score rows. No job id recorded. |
| Image | `placer_1.0.sif`, 4.17 GB — an environment, **no code and no weights**; recipe [`placer_1.0.def`](placer_1.0.def) |
| GPU | `--gres=gpu:nvidia_l40s:1` (or `nvidia_h100_nvl:1`), never a bare `gpu:1` — `GPU_MAX_CC=9.0` |
| Code + weights | on FAC at `$CHPC_LAB/data/placer`, which is what `$PLACER_DIR` resolves to: the checkout plus `weights/`, ~100 MB |
| Base | `pytorch/pytorch:2.3.1-cuda12.1-cudnn8-runtime` |
| Licence | BSD-3-Clause — source **and** weights |
| Upstream | `baker-laboratory/PLACER` @ `7dc5563` |

## Run it

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/placer/run1 && cd "$_"   # inputs here; the same path is valid inside the container
eval "$(chpc-tool export placer)"                         # PLACER_DIR: the checkout on FAC, not in the image
chpc-tool exec placer -- python "$PLACER_DIR/run_PLACER.py" \
    --ifile in.cif --odir out --suffix run1 -n 50 \
    --predict_ligand <LIGID> --rerank prmsd
```

`python` is spelled out because the entry's `ENTRY` is not prepended in front
of a bare script path. `<LIGID>` is the ligand as the input file names it
(`D-LDP-501` in the self-test's `4dtz.cif`). `-n 50` is a production ensemble
**(untested)**: the self-test draws 3, which proves sampling happens and
averages nothing.

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines to
the values above. The method, the `eval` idiom and which GPU to ask for:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

Input is an mmCIF or PDB that already contains the ligand pocket to repack, and
`--predict_ligand` names the ligand inside it. The self-test uses upstream's own
example, `$PLACER_DIR/examples/inputs/4dtz.cif` with `--predict_ligand
D-LDP-501` (`test.sh:23-30`). When the input has no ligand at all,
`run_PLACER.py` requires `--target_res` instead.

The script is not in the image. `run_PLACER.py`, `examples/` and `weights/` sit
on FAC at `$CHPC_LAB/data/placer` and are reached through `$PLACER_DIR`, so the
`eval` line is not optional here: without it the path is empty and there is
nothing to run.

`--odir` receives one **multi-model** PDB and a CSV of scores. The self-test's
is `4dtz_selftest_model.pdb`, one `MODEL` record per sample, with one CSV row
per sample; as a general rule that name is `<input>_<suffix>_model.pdb`
**(untested)**. Nothing asserts an order, so `--rerank prmsd` is ordering you
have not verified. Before any number comes off that file: split it, and check
the models differ — the count alone is satisfied by one structure written *n*
times, which is the degeneracy PLACER exists to remove.

## Do not miss

- **PLACER's multi-model output must be split before scoring.**
  `catalytic_geometry.measure()` reads model 0, so handing it the ensemble
  scores sample 1 *n* times and reports a preorganisation fraction of exactly
  0.000 or 1.000. `test.sh` asserts the model count *and* that the coordinates
  differ, because an ensemble of identical models passes a count on its own.
- **The image holds no PLACER.** Code and weights are on FAC; run
  `eval "$(chpc-tool export placer)"` and invoke the script through
  `$PLACER_DIR`. A PLACER update is a `git pull` on the share, not a rebuild.
- **`--target_res` is required when the input has no ligand.** `test.sh` uses
  upstream's own `4dtz.cif` rather than a generated backbone, because
  ligand-pocket repacking is what PLACER is for.
- **Preorganisation from a constrained relax is not a measurement.** The
  enzdes constraints impose the geometry regardless of substrate, which is how
  every cascade differential came back at exactly +0.000. Measured spread over
  the round-0 human IgG1 complex: relax ensemble 0.00–0.02 Å, PLACER ensemble
  0.35–0.68 Å.
- **L40S or H100 only.** cu121 emits no `sm_120`, so a Blackwell node dies at
  the first kernel launch; `GPU_MAX_CC=9.0` makes `chpc-tool` refuse up front,
  and `jobs/placer_states.sbatch` is pinned to `--gres=gpu:nvidia_l40s:1`. Why:
  [`../README.md`](../README.md#which-gpu).

---

## Provenance

Built 2026-09-19 by kanderson6 on the CoreHPC login node, 1412 s, 4.17 GB.

### What the test proves

`chpc-tool test placer` repacks upstream's own `4dtz` ligand pocket, three
samples, on an L40S:

```
ok: 3 models in 4dtz_selftest_model.pdb, coordinates differ between samples,
    3 score rows
```

The second clause is the one that matters. A count of three is satisfied by
one structure written three times, which is exactly the degeneracy PLACER
exists to remove — so the test also asserts that the coordinates differ.

## Build notes

### The image holds no PLACER

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

### One conda install replaced torch

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

### openbabel comes from a wheel, and needs two system libraries

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

- **`%post` cloned to `/tmp`, which is the build machine's.** The
  environment check clones PLACER, imports through it and deletes it. It used
  `/tmp`, and apptainer binds the *host's* `/tmp` into `%post` — so the clone
  landed on the login node and survived. The first build failed for an
  unrelated reason, left it there, and every rebuild then died on
  `fatal: destination path '/tmp/PLACER' already exists`, which looks like a
  git problem in the wrong filesystem. It stages in `/opt/placer-selfcheck`
  now. General case in [`docs/07`](../../docs/07-containers-apptainer.md).
- **e3nn 0.5.4 does not exist on PyPI.** PLACER's lockfile names it; the index
  goes 0.5.3 → 0.5.5. Pinned to 0.5.5 here — see the recipe for why going
  through conda to get 0.5.4 exactly would be the worse trade, which the
  section above then demonstrated at first hand.
