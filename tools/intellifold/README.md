# IntelliFold v2

| | |
|---|---|
| Status | **planned** — nothing built, nothing fetched, nothing run |
| Recipe | [`intellifold_2.def`](intellifold_2.def) — written, never executed |
| Upstream | <https://github.com/IntelliGen-AI/IntelliFold> |
| Licence | **Apache-2.0, code *and* model parameters, commercial use permitted** |
| Weights | not fetched — [`fetch-weights.sh`](fetch-weights.sh), login node only |
| Engine | AlphaFold 3's JAX/XLA engine, vendored and **built from source** |
| GPU | yes — `GPU_MAX_CC` **UNMEASURED**, and unusually hard to measure |
| Bonds | **UNQUALIFIED** — see below |

Upstream's licence statement, verbatim:

> The IntelliFold project, including code and model parameters, is made
> available under the Apache 2.0 License, it is free for both academic
> research and commercial use.

That is the whole reason for the entry. It is an AlphaFold-3-class model with
an AlphaFold-3 input dialect and **none of AlphaFold 3's output restriction** —
`../alphafold3`'s parameters bar commercial use of the *structures*, which for
a therapeutic programme outlives the run by years. IntelliFold vendors AF3's
**code** (Apache-2.0) as its inference engine; it does not use AF3's weights,
which are the non-commercial half.

## It is a JAX image, not a torch image, and that changes two things

**One: `GPU_MAX_CC` cannot be measured the usual way.** Every other GPU entry
here reads its ceiling out of torch:

```bash
python -c "import torch; print(torch._C._cuda_getArchFlags())"
```

There is no torch in this image. And if a future rebuild adds one — upstream's
checkpoint-conversion extra pulls it — its arch flags would describe the torch
wheel and say **nothing** about the JAX/XLA path that actually runs the model.
Reading the number off it would be worse than having no number, because it
would look like a measurement.

What can be reported cheaply, and is an *inference* rather than a measurement:

```bash
/usr/bin/apptainer exec "$CHPC_CONTAINERS/intellifold_2.sif" python -c \
  "import jax, jaxlib; from jax.lib import xla_bridge; \
   print(jax.__version__, jaxlib.__version__, xla_bridge.get_backend().platform_version)"
```

`sm_120` — the RTX PRO 6000 Blackwell nodes — needs a CUDA 12.8 or newer
toolchain, which is why the recipe bases on `nvidia/cuda:12.8.1-...`. That is
reasoning from release notes, not evidence.

**The qualification is a fold per device class.** Boltz's entry is the model:
its "any `gpu` node" row is a measurement because it was actually run on an
H100 NVL (job 1899084) *and* on a Blackwell node (job 1899088, `ggpu1-19`), and
that is the only reason that row is trustworthy. Do the same here — one small
fold on each of `--gres=gpu:nvidia_l40s:1` (8.9), an H100 NVL (9.0) and a
Blackwell node (12.0) — and write the job ids into this table before setting
`GPU_MAX_CC` to anything.

Until then `tool.conf` carries the literal `GPU_MAX_CC=UNMEASURED`, which
**fails closed**: `chpc-tool` compares with `awk` (`a+0 > b+0`), `awk` reads a
non-numeric string as `0`, every device is above `0`, and `chpc-tool exec
intellifold` refuses on any GPU node. A refusal costs seconds; a wrong ceiling
is a job that dies twenty minutes in with `no kernel image is available for
execution on the device`, which reads as a broken install and is a scheduling
accident (doc 05). Five tools here already declare 9.0 and lose jobs to exactly
that on the Blackwell nodes.

**Two: the C-compiler trap is here in its second form.** Boltz's is the first
form — `python:3.12-slim` with no compiler, Triton JIT-compiling cuequivariance
kernels at first use, and every prediction above ~128 tokens dying four seconds
in with `RuntimeError: Failed to find C compiler` from
`triton/runtime/build.py`, having written nothing. Job array 1928395 in a
sibling project lost all five tasks in under a minute each to precisely that.

**Decision for IntelliFold: a full toolchain in `%post`, kept, not purged.**
Two reasons and only the first is obvious:

1. upstream's install *compiles* the vendored AF3 engine —
   `pip install ./third_party/alphafold3 && build_data` — so `build-essential`,
   `cmake` and `zlib1g-dev` are required at build time regardless;
2. XLA compiles kernels at **run** time. It does that in-process with LLVM, so
   it does not shell out to `cc` the way Triton does — but it reaches for
   `ptxas`/`nvlink` from the CUDA toolkit, which is why the base is `-devel`
   rather than `-runtime`, and AF3's own performance documentation records XLA
   compilation problems bad enough to need an `XLA_FLAGS` workaround. That flag
   (`--xla_gpu_enable_triton_gemm=false`) is set as an overridable default in
   `%environment`.

`tool_doctor` probes the built image for `cc`/`gcc`/`clang` rather than
hardcoding the answer, so a rebuild that slims the base is noticed rather than
discovered by a job.

## Bonds are UNQUALIFIED, and `test.sh` case 2 is the qualification

The brief this entry was written from says the input is AlphaFold-3-style JSON
with `bondedAtomPairs` addressed as `[entity_id, residue_id, atom_name]`,
1-based residues. Upstream's README says the first half of that — *"The input
is an AlphaFold 3-style JSON"* — and **never mentions `bondedAtomPairs` at
all**. So the bond form is an inference from the shared dialect, not a
documented capability, and it is recorded here as unqualified.

Two consequences worth knowing before anyone writes an input:

- **`entity_id` is a chain label** (`"A"`, `"B"`), which is *not*
  `../protenix`'s convention — Protenix's `entity1` is a 1-based **index into
  the `sequences` list**. Neither tool errors on the other's convention. Both
  produce a structure.
- **If AF3's rule carries over, a SMILES ligand cannot carry a bond.** AF3's
  documentation is explicit: *"there is no atom name that could be used to
  define the bond"*, and the fix is a registered CCD code or a `userCCD` block
  whose atom names you assign yourself (see `../alphafold3/README.md`, which
  works this through). `test.sh` uses a CCD code for that reason.

`test.sh` case 2 folds a one-cysteine peptide bonded to a CCD ligand and then
asserts, **on the coordinates**, that exactly one ligand heavy atom is within
2.1 Å of `SG`, that it is a carbon, and that that carbon's only heavy neighbour
inside the ligand is another carbon. If the run is rejected, that is the
finding — record it here and leave `STATUS=built`. If the run *succeeds* and
the geometry is wrong, that is worse and the test says so: HA-ADAPT's Chai-1
corpus (1,726 results, quarantined) was the free drug folded while declared
bonded, and **ipTM moved 0.710 → 0.698** between the wrong attachment and the
right one. Shared checker:
[`../_template/check_covalent_bond.sh`](../_template/check_covalent_bond.sh).

## MSAs

`--norun_data_pipeline`, always, on a compute node: the data pipeline reaches
the internet and compute nodes here have none (doc 02). Supply `unpairedMsa` /
`pairedMsa` in the JSON, generated on the login node with `../mmseqs2` or
`../colabfold`. Everything after the bare `--` on the command line is passed
straight through to AlphaFold 3.

## When someone builds it

```bash
chpc-tool build intellifold          # login node only; /usr/bin/apptainer 1.5.2,
                                     # --fakeroot UNAVAILABLE, no `module load apptainer`
tools/intellifold/fetch-weights.sh   # login node; weights onto FAC
chpc-tool publish intellifold
chpc-tool test intellifold           # GPU node -- this is what `verified` means
```

Weights go on FAC (`/mnt/fac/CX500146_DS1`, 5 TB, ~1.1 TB used), never on
`/mnt/scratch`, which is purged at 30 days and is never canonical. Run
`chpc-fac-fixacl` on anything created there — the inheritable DENY ACL makes
new files unreadable by their own owner (doc 02).

Upstream's default `--model-dir` is the **relative** `./model_v2`. That is the
Boltz `BOLTZ_CACHE` trap with a different name: a job that `cd`s anywhere gets
a different, empty directory and then tries to download from a node with no
internet. `tool_exports` resolves an absolute path and both the fetch script
and the test refuse a relative one.

## What was verified, and what was taken on trust

Verified against upstream on 2026-09-24:

- the licence, quoted above — Apache-2.0 on code **and** model parameters,
  academic and commercial use;
- `pip install intellifold`, and the from-source route
  `pip install ./third_party/alphafold3 && build_data && pip install intellifold`;
- the CLI shape: `intellifold predict <input.json> --model-dir=... --output-dir=...`,
  with post-`--` flags passed to AF3, and `--norun_data_pipeline` as the
  no-data-pipeline mode;
- the two shipped artefacts, `intellifold_v2.bin.zst` and
  `intellifold_v2_fourier.npz`, auto-downloading from Hugging Face into
  `./model_v2` on first run;
- *"The input is an AlphaFold 3-style JSON."*

**Not** verified, and marked as such in the files that depend on it:

- **`bondedAtomPairs`** — not mentioned anywhere in upstream's documentation.
  The whole covalent capability is inferred from the AF3 dialect.
- **a `v2-flash` checkpoint.** The brief mentions one; upstream's README names
  only IntelliFold-v2. If it exists it is not documented there, and this entry
  does not fetch it.
- the base image tag `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04` — confirm it
  exists before starting a build;
- that CUDA 12.8 is sufficient for `sm_120` here — inference from release
  notes, see above;
- that an empty `unpairedMsa`/`pairedMsa` is accepted as single-sequence mode
  by this engine;
- the CCD code `ACT` and its methyl atom name `CH3` used in `test.sh`'s bonded
  case, and whether the engine will accept a bond to it at all.
