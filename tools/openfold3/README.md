# OpenFold3 (research preview)

| | |
|---|---|
| Status | **built** 2026-09-25 — image exists, `%test` passed on the login node. Nothing folded. |
| Image | `openfold3_3.sif` — [`openfold3_3.def`](openfold3_3.def) |
| Upstream | <https://github.com/aqlaboratory/openfold-3> — **note the hyphen** |
| Licence | Apache-2.0, code and weights, academic **and commercial** use |
| Weights | Hugging Face `OpenFold/OpenFold3`, default set `OpenBind-0` |
| GPU | yes — `GPU_MAX_CC=12.0`, measured from torch's arch flags. See the caveat. |
| Covalent bonds | **REFUSED — settled 2026-09-25 against the released wheel. See below.** |
| Training cutoff | `OpenBind-0`: the PDB through **June 2025** |

The OpenFold consortium's open reimplementation of AlphaFold 3, from the
AlQuraishi lab. Apache-2.0 on both halves, so — like `../protenix` and
`../intellifold`, and unlike `../alphafold3` — it puts no restriction on what
may be done with the structures it produces.

`aqlaboratory/openfold-3`, with a hyphen. `aqlaboratory/openfold3` is a 404 and
`aqlaboratory/openfold` is the AlphaFold **2** reimplementation, which is a
different model. Worth a line because two of those three are easy to reach for.

## Covalent support is unqualified, and the entry says so everywhere

Upstream's documentation says OpenFold3 *"replicates the input features
described in the AlphaFold3 publication"*. It does **not** mention
`bondedAtomPairs`, covalent bonds, CCD codes, SMILES, `userCCD`, or ligand atom
naming anywhere that could be found. So:

- **there is no source for a claim that it accepts a bond**, and none is made
  here — not in `tool.conf`'s `NOTE`, not in `%help`, not in this table;
- `tool_doctor` prints `COVALENT SUPPORT UNQUALIFIED` on every run, because
  that is the one thing a path check can never see and the one thing that
  decides whether this tool is usable for the work it was added for;
- **`verified` for this entry means a bonded fold actually ran and the bond
  landed on the right atom.** Not that the container started. `test.sh` has two
  phases and both are hard failures, with deliberately **no** environment
  variable to skip the second. An escape hatch is a thing that gets used at
  6pm and quoted back the next morning as a green test.

It is entirely possible for this entry to reach `built` and legitimately never
reach `verified`. That is a finding, not unfinished work, and the place to
write it is the section below.

## Settled 2026-09-25: it is not an AlphaFold 3 dialect, and the bond field is dead

The entry below was written from upstream's documentation, which says only that
OpenFold3 "replicates AlphaFold 3's input features" and never mentions a bond.
Reading the released wheel (`openfold3` 0.5.0) answers it, and the answer is
worse than unqualified.

**It has its own input schema.**
`openfold3/projects/of3_all_atom/config/inference_query_format.py` defines
pydantic models that `run_openfold --query-json` loads through
`InferenceQuerySet.from_json`:

```
{"seeds": [42], "queries": {"<name>": {
    "chains": [{"molecule_type": ..., "chain_ids": [...], "sequence": ...,
                "ccd_codes": [...], "smiles": ..., "main_msa_file_paths": [...],
                "paired_msa_file_paths": [...]}],
    "use_msas": true, "covalent_bonds": [...], "pocket_constraint": ...}}}
```

`chains`, not `sequences`. `ccd_codes`, not `ccdCodes`. `main_msa_file_paths`,
not `unpairedMsaPath`. And `Chain` is declared `extra="forbid"`, so an
AlphaFold 3 JSON is rejected rather than half-read — which is the one piece of
good news here.

**`molecule_type`'s vocabulary is still unread**, and that is the one
outstanding fact on this page rather than an oversight. It is the first field a
renderer has to get right and its accepted values are whatever that module's
enum says; nothing here has read it, and guessing `"protein"` because it looks
like AlphaFold 3 is exactly the reasoning the rest of this section disproves.
One command on the login node settles it, and it needs no GPU:

```bash
/usr/bin/apptainer exec "$CHPC_CONTAINERS/openfold3_3.sif" python -c \
  "from openfold3.projects.of3_all_atom.config import inference_query_format as q; \
   print(q.Chain.model_json_schema())"
```

Record the answer here when somebody runs it. It does not change the refusal
below — a dead `covalent_bonds` field is not a naming problem — but it turns
"unknown" into a measurement, which is the difference between declining to build
something and not having looked.

**The bond endpoint is an integer index.** `Bond(atom1: Atom, atom2: Atom)`
with `Atom = (chain_id: str, residue_id: int, atom_id: int)`. Not a name. That
makes it the only tool in this registry whose bond has no vocabulary to be
checked against at all: an off-by-one moves the bond and nothing disagrees.

**And nothing reads it.** The string `covalent_bonds` appears in exactly one
file of the wheel — the schema above. No consumer, in the inference path or
anywhere else. So a covalent request validates, runs, exits zero, and writes a
confident structure in which the ligand is bonded to nothing. That is the
HA-ADAPT contamination with a new spelling, and it is why this is a refusal
rather than an open question.

**What follows.** Fold the apo system here; refuse anything covalent. The
consuming project has removed `openfold3` from its AF3-dialect builder for the
same reason, so an input is never labelled for a tool that cannot read it.
`test.sh` phase 2 keeps its value: it becomes the check that tells us when
upstream starts consuming the field.

`test.sh` phase 2 tries the AlphaFold 3 spelling — `bondedAtomPairs` with
`[entity_id, residue_id, atom_name]` endpoints and a registered CCD ligand —
because it is the only documented candidate, not because there is a source for
it. It distinguishes three outcomes, and they mean different things:

| Outcome | Looks like | Means |
|---|---|---|
| (a) rejected | schema error naming the key | wrong key. Find the real one in the installed package's schema, write it here |
| (b) accepted, ignored | a run that succeeds, a plausible structure | **the dangerous one.** The checker catches it as a free ligand metres from the anchor |
| (c) accepted, honoured | geometry check passes | qualified. Paste the working JSON into this file — upstream documents none |

Outcome (b) is why the check is geometric. HA-ADAPT's entire Chai-1 corpus —
1,726 results — is quarantined because the free drug was folded while
*declared* bonded, with the peptide cysteine bonded to an aromatic ring carbon
at 1.68 Å instead of the warhead at 13.59 Å. **ipTM moved 0.710 → 0.698**
between the wrong structure and the right one. No confidence score detects it;
no exit status detects it; nothing downstream can be trusted by inspection.
The shared checker asserts that exactly one ligand heavy atom is within 2.1 Å
of `SG`, that it is a carbon, and that that carbon's only heavy neighbour
inside the ligand is another carbon:
[`../_template/check_covalent_bond.sh`](../_template/check_covalent_bond.sh).

## The C-compiler trap, in both of its forms at once

Upstream advertises *"kernel acceleration through cuEquivariance and
DeepSpeed4Science kernels"*. Both compile at **first use**, on the compute
node, in the middle of a job:

- **cuEquivariance's triangle kernels are Triton.** This registry has already
  paid for that lesson. `boltz_2.sif` is built from `python:3.12-slim` with no
  compiler, and every prediction above ~128 total tokens dies four seconds in
  with `RuntimeError: Failed to find C compiler` from
  `triton/runtime/build.py`, having written nothing — while the self-test
  passed the entire time, because a 31-mer never reaches the kernel path.
  Confirmed independently outside this registry: job array 1928395 in a sibling
  project lost all five tasks in under a minute each to exactly that error.
- **DeepSpeed4Science's evoformer attention** goes through DeepSpeed's JIT op
  builder, which needs `nvcc`, a C++ compiler and `ninja` at run time, and
  fails the same way — late, loudly, nothing written.

**Decision for OpenFold3: a full CUDA/C++ toolchain in the image, and the base
is `-devel` rather than `-runtime` so that `nvcc` is present.** Boltz can ship
without a compiler and record `--no_kernels` in its `NOTE` because upstream
documents that flag; OpenFold3 has no documented equivalent, which removes the
argument for the cheaper image. `%post` and `%test` both assert `cc` and
`nvcc`; `tool_doctor` probes the built image for both rather than trusting this
paragraph, so a rebuild from a slimmer base is noticed instead of discovered by
a job. `TORCH_EXTENSIONS_DIR` is pointed at `/tmp` — its default is under
`$HOME`, which here is small, shared, and the last place two concurrent array
tasks should both be writing a build tree.

`%post` also imports `cuequivariance_torch` explicitly and says what it means
if the import is missing, because boltz's failure mode was precisely a kernel
package that was absent while everything importable imported fine.

## `GPU_MAX_CC` is 12.0, from torch's arch flags — with one caveat

The `gpu` partition is three devices — L40S 8.9, H100 NVL 9.0, RTX PRO 6000
Blackwell 12.0 — and a bare `--gres=gpu:1` lands on any of them. Five tools
here declare a 9.0 ceiling and die on the Blackwell nodes with `no kernel image
is available for execution on the device`, which reads as a broken install and
is a scheduling accident (doc 05).

**Measured 2026-09-25 inside the built image, on the login node:** torch
2.14.0+cu130, arch flags `sm_75 sm_80 sm_86 sm_90 sm_100 sm_120`. `sm_120` is
present, so this is the second entry here (after boltz) that may take a bare
`--gres=gpu:1`.

The value stayed `UNMEASURED` until then, and that literal **fails closed**:
`chpc-tool` compares with `awk` (`a+0 > b+0`), `awk` reads a non-numeric string
as `0`, and `chpc-tool exec` therefore refuses on any GPU node until a real
number replaces it. To re-measure after a rebuild, inside the image, on the
**login node** (no `nvidia-smi` there, so the guard cannot block its own
measurement):

```bash
/usr/bin/apptainer exec "$CHPC_CONTAINERS/openfold3_3.sif" \
  python -c "import torch; print(torch._C._cuda_getArchFlags())"
```

Highest `sm_NN` is the number: `sm_120` → `12.0`. Use `_cuda_getArchFlags`,
**not** `torch.cuda.get_arch_list()`, which returns `[]` with no GPU visible —
exactly the login node. `%post` prints a candidate at the end of the build.

**And note what that command does not answer.** Torch's arch flags are torch's.
`cuequivariance` ships prebuilt kernels per architecture, and if those wheels
stop at `sm_90` the real ceiling is 9.0 whatever torch says. The only thing
that settles it is folding something on a Blackwell node — which is exactly
what makes boltz's "any `gpu` node" row a measurement rather than an inference
(jobs 1899084 on an H100 NVL and 1899088 on `ggpu1-19`).

## When someone builds it

```bash
chpc-tool build openfold3          # login node only; /usr/bin/apptainer 1.5.2,
                                   # --fakeroot UNAVAILABLE, no `module load apptainer`
tools/openfold3/fetch-weights.sh   # login node; parameters onto FAC
# read the GPU_MAX_CC candidate out of the build log, put it in tool.conf
chpc-tool publish openfold3
chpc-tool test openfold3           # GPU node -- BOTH phases. This is the qualification.
```

Parameters go on FAC (`/mnt/fac/CX500146_DS1`, 5 TB, ~1.1 TB used), never on
`/mnt/scratch`, which is purged at 30 days and is never canonical. `HF_HOME` is
exported *inside* the weights directory for that reason — `chpc.env` otherwise
points it at user scratch, which is right for a cache and wrong for the only
copy. Run `chpc-fac-fixacl` on anything created on the share (doc 02).

## What was verified, and what was taken on trust

Verified against upstream on 2026-09-24:

- Apache-2.0, code and weights, *"freely available for academic and commercial
  use"*;
- that it is a **research preview**, in upstream's own words;
- `pip install openfold3` followed by `setup_openfold`;
- weights on Hugging Face at `OpenFold/OpenFold3`, default parameter set
  `OpenBind-0` from 0.5.0;
- the CLI shape `run_openfold predict --query_json=...`;
- *"Kernel acceleration through cuEquivariance and DeepSpeed4Science kernels"*;
- that the documentation contains **no** mention of `bondedAtomPairs`,
  covalent bonds, CCD codes, SMILES or ligand atom naming — which is the
  negative finding this entry is built around.

**Not** verified, and marked as such in the files that depend on it:

- **everything about covalent bonds.** The `bondedAtomPairs` shape in
  `test.sh` phase 2 is the AlphaFold 3 spelling, tried because it is the only
  candidate with a source, not because OpenFold3 is documented to take it.
- the query JSON schema generally — `test.sh` and `fetch-weights.sh` both
  prefer upstream's **own** example file, found inside the image, over a schema
  copied out of a README;
- the `--output_dir` flag name;
- whether `setup_openfold` takes a destination argument, and whether it or
  `run_openfold` is what actually downloads the parameters;
- the base image tag `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04`;
- whether `cuequivariance_torch` is installed by default and whether OpenFold3
  enables those kernels by default the way boltz does — `%post` prints what it
  finds and says what a miss would mean.

## Templates: the only direct interface of the six

Read from the installed package 2026-09-24. Not yet run — this entry is
`built`, and nothing in this project renders an OpenFold3 input at all yet.

`Chain` in `projects/of3_all_atom/config/inference_query_format.py` carries two
mutually exclusive template routes, and the validator refuses both at once:

- `template_alignment_file_path` (+ `template_entry_chain_ids`) — the search
  route, an alignment cache entry.
- **`template_cif_paths` + `template_cif_chain_ids`** — *"CASE 2: CIF-direct
  mode"* in `preprocessing/template.py`. Hand it the files and the chains and
  it does the rest: no alignment file, no hit table, no residue index map, no
  search, no network. It is the simplest template interface in this registry and
  the only one that takes a multi-chain mmCIF and a chain letter.

Upstream's own `tests/inference/test_templates.py` is a working recipe, and it
is worth reading for a second reason: it exists because of issue #294, where
gapped alignment columns reached the template cache, the residue counts
disagreed, and **the template was silently dropped**. The test asserts a
CA-RMSD *gap* between a templated and an untemplated run rather than asserting
the job succeeded, which is the right shape for a check on this surface and the
shape `test.sh` should copy when this entry is qualified.

Two settings to know: `n_templates: int = 4` (`dataset_config_components.py`),
and `template_preprocessor_settings.output_directory`, which otherwise lands in
a persistent `/tmp` directory shared across runs and across same-sequence
queries — set it per run or one job reads another's cache.

CLI: `run_openfold predict --query-json ... --use-templates true`.

**Like every tool here but Boltz-2, its template pair features are masked to
within one chain** — `multichain_pair_mask`, under the comment *"Create asym ID
to mask inter-chain features"*. A template cannot hand over a binder's position
in OpenFold3. See ADR 0020's 2026-09-24 amendment in the parent repo.

**`covalent_bonds` is declared on `Query` and read by nothing.** Grep the
package: it appears in the schema and in no other file. A covalently bonded
ligand cannot be expressed here today, which matters more for this project than
the template story does.

## Who folds with this, and who has decided not to

This entry stays. It is built, its weights are fetched, its GPU ceiling is
measured, and everything known about its schema is written down — so a consumer
who wants an Apache-2.0 co-folding model with no restriction on its outputs can
use it for what it can actually do.

**Hap108or has decided not to build an adapter for it**, recorded 2026-09-25 in
ADR 0022 and as a declared refusal in both of its template sets
(`Hap108or-data/templates/*.yaml`). Two independent reasons, each sufficient:

- **The chemistry.** That project folds a peptide bonded to a hapten, and the
  section above settles that `covalent_bonds` is declared and never read on the
  inference path. The best possible adapter could only fold the apo system.
- **The templates.** `OpenBind-0` is trained on the PDB through June 2025, and
  both of that project's template sets are 2024 structures. They are already in
  these weights, so showing them adds no evidence — the first time that
  project's cutoff rule has fired on a real date, and it fired the right way.

What made the decision cheap rather than close: the apo fold is already covered.
`../colabfold` is `verified`, folds the apo system, and in that project's own
five-predictor benchmark placed the antibody variable domain better than any of
the ligand-bearing models (DockQ 0.110 against 0.017–0.046). A second apo arm
would have cost a renderer and bought nothing measurable.

None of that is a judgement on this tool for anyone else. A system whose
chemistry has no covalent bond in it, or a template set newer than June 2025,
meets neither objection.
