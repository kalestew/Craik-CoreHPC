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

## Bonds: the AF3 keys ARE honoured, and a bond it declares may not be one

**Measured 2026-09-25**, on a real covalent complex (a haptenated peptide-MHC
with an antibody Fv, 658 tokens) on an H100 NVL, five diffusion samples on
each of two ligand routes. This settles the first question and opens a
sharper one.

**`userCCD` and `bondedAtomPairs` both work.** A top-level `userCCD` block
referenced as `ccdCodes: ["LIG-1"]` is read, the ligand is tokenised per
atom (41 heavy atoms, matching the block), and the output carries
`_struct_conn` with `conn_type_id covale` naming the peptide cysteine's `SG`
and the ligand atom the input asked for. A registered code in `ccdCodes`
works too, from the image's own component table.

**But the declaration is not the geometry.** In two of five samples on each
route, the file declares the covale and the two atoms are **2.78-2.79 A**
apart -- outside any S-C covalent range. The bond is on the right atom (the
decoy carbon is 12-15 A away in all ten) and it is not a bond. A gate built
on `_struct_conn` alone would pass all ten.

So `test.sh` case 2, which asserts on the coordinates, is still the right
check and is now known to be necessary rather than merely prudent.

**The two routes are not interchangeable.** Same molecule, same atom names,
same 41 heavy atoms -- and the structures differ systematically: the
antibody lands 17-46 A from its crystal position on the shipped-block route
and 52-53 A away on the registry route, with non-overlapping ranges over
five samples at one seed. The registry route is the one the model is more
confident about (ipTM 0.70-0.71 against 0.57-0.59). Whatever you fold with,
record which.

## Original note: bonds were UNQUALIFIED, and `test.sh` case 2 is the qualification

The brief this entry was written from says the input is AlphaFold-3-style JSON
with `bondedAtomPairs` addressed as `[entity_id, residue_id, atom_name]`,
1-based residues. Upstream's README says the first half of that — *"The input
is an AlphaFold 3-style JSON"* — and **never mentions `bondedAtomPairs` at
all**. So the bond form is an inference from the shared dialect, not a
documented capability, and it is recorded here as unqualified.

**Read from the source 2026-09-25, which narrows it without closing it.**
`intellifold/run_jax_inference.py` parses its input with
`alphafold3.common.folding_input.load_fold_inputs_from_path` — AF3's own
parser, not a reimplementation — and grep finds the strings `bondedAtomPairs`
and `userCCD` in **no file of the `intellifold` package**, which is what you
would expect when the parsing is delegated. So both keys are read by the same
code that reads them for AlphaFold 3, and the dialect inference above is now an
inference about one line of code rather than about a family resemblance.

That is not qualification, and the gap that remains is the interesting half:
parsing a key is not the same as *featurising* it. `folding_input` will accept
a `bondedAtomPairs` entry and hand IntelliGen's own featuriser a bond it may or
may not carry into the model. Only `test.sh` case 2, on the coordinates,
settles that — which is exactly what it was written to do.

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

## Templates: the AlphaFold 3 route, validated offline

Measured 2026-09-24 in this image. This entry runs the **JAX** path
(`run_jax_inference.py`, AlphaFold 3 runner flags), not IntelliFold v1's
PyTorch path — which matters here, because the two take templates completely
differently and only one of them works.

**What this image reads** is `alphafold3.common.folding_input`: a per-protein
`templates` list of `{mmcifPath, queryIndices, templateIndices}`. Confirmed by
loading a five-chain templated input with three members per chain — fifteen
templates, all accepted, with the pair counts this project derived.

Four properties, all from the installed package:

- **`templates: []` means no templates; `templates` absent means go and search.**
  The two are not the same and the difference is silent on a node with no
  internet.
- **Up to 20 templates per chain**, from `ProteinChain`'s own docstring.
- **One polymer chain per file.** `get_polymer_features` raises
  `must be filtered to a single polymer chain`, so a five-chain complex becomes
  five files. It also raises when the mmCIF has no `_entry.id`, and separately
  when it has no `_pdbx_audit_revision_history.revision_date` — naming that item
  in the error text.
- **`templateIndices` count the declared polymer, gaps included.**
  `get_polymer_features` indexes `to_res_arrays(include_missing_residues=True)`
  with them. Indices counted over the *modelled* residues are shifted by however
  many the structure failed to model, silently — 9 residues for this project's
  reference heavy chain, 110 for its related set's.

**No date gate on this path.** Unlike Protenix, a user-supplied template
bypasses the search pipeline's filters entirely: `features.py` goes straight
from `template.mmcif` to `get_polymer_features` with no release-date comparison.
The release date still has to be *present* or the read fails.

Note that IntelliFold v1's own featurizer, in `data/module/inference.py`, is a
vendored copy of Protenix's and carries the same hard-coded `2021-09-30` cutoff.
It is not on this image's code path. Do not read that file and conclude the
cutoff applies here; it does not.

**kalign is not installed and is not needed** on this path, because the
correspondence is supplied rather than computed.
