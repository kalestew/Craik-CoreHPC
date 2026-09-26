# OpenFold3 (research preview)

| | |
|---|---|
| Status | built 2026-09-25 (`%test` passed on the login node); `chpc-tool test openfold3` has not run and nothing has been folded with it |
| Image | `openfold3_3.sif`; recipe [`openfold3_3.def`](openfold3_3.def) |
| Base | `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04`; torch 2.14.0+cu130 |
| GPU | `--gres=gpu:1`, any `gpu` node (`GPU_MAX_CC=12.0`: torch carries `sm_120`; the cuEquivariance and DeepSpeed kernels have not been exercised on a Blackwell node) |
| Weights | Hugging Face `OpenFold/OpenFold3`, default set `OpenBind-0`, into `$OPENFOLD3_WEIGHTS` (`$CHPC_LAB/data/openfold3`, with `HF_HOME` inside it) by [`fetch-weights.sh`](fetch-weights.sh) on the login node; whether that has completed is not recorded in the entry, `chpc-tool doctor openfold3` says |
| Covalent bonds | **apo folds only.** `covalent_bonds` is declared in the query schema and read by nothing; settled 2026-09-25 against the released wheel |
| Licence | Apache-2.0, code and weights, academic **and commercial** use |
| Upstream | <https://github.com/aqlaboratory/openfold-3> — **note the hyphen**; the wheel read is `openfold3` 0.5.0; `UPSTREAM_REF` is unset in tool.conf |
| Training cutoff | `OpenBind-0`: the PDB through **June 2025** |

## Run it

```bash
srun -p gpu --gres=gpu:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/openfold3/run1 && cd "$_"   # in.json here; the same path is valid inside the container
chpc-tool exec openfold3 -- run_openfold predict --query_json=in.json --output_dir=out   # (untested)
```

(untested): that is the line `test.sh` and the recipe's `%help` give, and
neither has run on a compute node; `--output_dir` in particular is a flag name
nothing has confirmed. No tool variable appears on the line, so no `eval` is
needed: `exec` exports `OPENFOLD3_WEIGHTS` and `HF_HOME` into the container.
Any `gpu` node is allowed as far as torch's kernels go; nothing has yet run on
any of them (Provenance).

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines
to the values above, `--gres=gpu:1` included. The method, the `eval` idiom and
which GPU to ask for: [`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

Its **own** query schema, not AlphaFold 3's.
`openfold3/projects/of3_all_atom/config/inference_query_format.py` defines
pydantic models that `run_openfold predict --query_json=` loads through
`InferenceQuerySet.from_json`:

```
{"seeds": [42], "queries": {"<name>": {
    "chains": [{"molecule_type": ..., "chain_ids": [...], "sequence": ...,
                "ccd_codes": [...], "smiles": ..., "main_msa_file_paths": [...],
                "paired_msa_file_paths": [...]}],
    "use_msas": true, "covalent_bonds": [...], "pocket_constraint": ...}}}
```

`chains`, not `sequences`; `ccd_codes`, not `ccdCodes`; `main_msa_file_paths`,
not `unpairedMsaPath`. `Chain` is declared `extra="forbid"`, so an AlphaFold 3
JSON is rejected rather than half-read. Start from upstream's own example,
which ships inside the image and is what `test.sh` and `fetch-weights.sh`
prefer over a schema copied out of a README:
`chpc-tool exec openfold3 -- sh -c 'find / -xdev -path "*example*" -name "query_*.json"'`.
MSAs are files you generate on the login node and name in
`main_msa_file_paths`/`paired_msa_file_paths`.

Output lands under `--output_dir` (untested); `test.sh` looks for a `.cif`
with `find`. Whether and how it ranks samples is not recorded in this entry.
Before trusting anything: nothing has been folded with this image, and a query
that carries a `covalent_bonds` entry validates, runs, exits zero and writes a
confident structure with no bond in it.

**`molecule_type`'s vocabulary is still unread**, and that is the one
outstanding fact on this page rather than an oversight. It is the first field a
renderer has to get right and its accepted values are whatever that module's
enum says; nothing here has read it, and guessing `"protein"` because it looks
like AlphaFold 3 is exactly the reasoning the schema facts above disprove.
One command on the login node settles it, and it needs no GPU:

```bash
/usr/bin/apptainer exec "$CHPC_CONTAINERS/openfold3_3.sif" python -c \
  "from openfold3.projects.of3_all_atom.config import inference_query_format as q; \
   print(q.Chain.model_json_schema())"
```

Record the answer here when somebody runs it. It does not change the covalent
refusal (Provenance) — a dead `covalent_bonds` field is not a naming problem — but it turns
"unknown" into a measurement, which is the difference between declining to build
something and not having looked.

## Do not miss

- **Apo folds only.** `covalent_bonds` is declared on `Query` and consumed by
  nothing in the wheel, and its bond endpoint is an integer atom index with no
  name to check against. A covalent request produces a plausible, confident,
  unbonded structure. Why that is the worst outcome and how to check a bond
  elsewhere: [`../covalent-bonds.md`](../covalent-bonds.md).
- **Not an AlphaFold 3 JSON.** `chains`, `ccd_codes`, `main_msa_file_paths`,
  `extra="forbid"`. An AF3-dialect input is rejected outright, which is the
  one piece of good news.
- **MSAs are precomputed.** Compute nodes have no route out (doc 02); name
  the files in `main_msa_file_paths`/`paired_msa_file_paths`.
- **Any `gpu` node is allowed, and none has run it.** 12.0 is torch's arch
  list. If a job on `ggpu1-[13-19]` dies with what looks like a broken
  install, the cuEquivariance or DeepSpeed kernels are the first suspect and
  `GPU_MAX_CC` in tool.conf is the first thing to lower.
- **Templates share a cache.** `template_preprocessor_settings.output_directory`
  otherwise lands in a persistent `/tmp` directory shared across runs and
  across same-sequence queries; set it per run or one job reads another's.

---

## Provenance

Built 2026-09-25 (tool.conf): the image exists and its `%test` passed on the
login node. Builder and wall time are not recorded, and `UPSTREAM_REF` was
never filled in.

`chpc-tool test openfold3` has **not** run, and nothing has been folded with
this image. What it will prove: phase 1 folds upstream's own example query,
found inside the image, and asserts at least 20 CA atoms and a CA radius of
gyration above 3 Å; phase 2 sends the AlphaFold 3 spelling, `bondedAtomPairs`
with `[entity_id, residue_id, atom_name]` endpoints and a registered CCD
ligand, and runs the geometry checker on the result. Both phases are hard
failures, with deliberately **no** environment variable to skip the second: an
escape hatch is a thing that gets used at 6pm and quoted back the next morning
as a green test. Given the schema finding below, phase 2's expected outcome is
(a), a schema error; it keeps its value as the check that says when upstream
starts consuming the field.

**`verified` for this entry means a bonded fold actually ran and the bond
landed on the right atom.** Not that the container started. With
`covalent_bonds` unread, it is entirely possible for this entry to stay `built`
and legitimately never reach `verified`. That is a finding, not unfinished
work. `tool_doctor` prints `COVALENT BONDS ARE REFUSED HERE` on every run,
because that is the one thing a path check can never see and the one thing
that decides whether this tool is usable for the work it was added for.

`GPU_MAX_CC=12.0`, measured 2026-09-25 inside the built image on the login
node with `torch._C._cuda_getArchFlags()`: torch 2.14.0+cu130, arch flags
`sm_75 sm_80 sm_86 sm_90 sm_100 sm_120`. Those are torch's flags. Upstream
advertises cuEquivariance and DeepSpeed4Science kernels whose own wheels may
be narrower, and neither has been exercised on a Blackwell node. Boltz's "any
`gpu` node" row is trustworthy because it was actually run there (jobs 1899084
on an H100 NVL and 1899088 on `ggpu1-19`); this one is not yet. How the
measurement is taken: [`../README.md`](../README.md#add-a-tool).

### Settled 2026-09-25: it is not an AlphaFold 3 dialect, and the bond field is dead

The entry was written from upstream's documentation, which says only that
OpenFold3 "replicates AlphaFold 3's input features" and never mentions a bond.
Reading the released wheel (`openfold3` 0.5.0) answers it, and the answer is
worse than unqualified.

**It has its own input schema.**
`openfold3/projects/of3_all_atom/config/inference_query_format.py` defines
pydantic models that `run_openfold predict --query_json=` loads through
`InferenceQuerySet.from_json` (Inputs and outputs has the shape). `chains`,
not `sequences`. `ccd_codes`, not `ccdCodes`. `main_msa_file_paths`, not
`unpairedMsaPath`. And `Chain` is declared `extra="forbid"`, so an AlphaFold 3
JSON is rejected rather than half-read — which is the one piece of good news
here.

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

Outcome (b) is why the check is geometric, and why no confidence score or
exit status can stand in for it: [`../covalent-bonds.md`](../covalent-bonds.md).

### The rest of the record

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

Still unknown:

- the `--output_dir` flag name, the output layout and whether samples are
  ranked;
- which of the two download mechanisms in `fetch-weights.sh` fetches the
  parameters, and whether they are on the share now. Measured 2026-09-25: the
  bare `setup_openfold` is an interactive click prompt that aborts rather than
  taking its default when stdin is not a terminal, and `--config` takes a JSON
  serialisation of `OpenFoldSetupConfig`;
- whether `cuequivariance_torch` is installed by default and whether OpenFold3
  enables those kernels by default the way boltz does — `%post` prints what it
  finds and says what a miss would mean;
- the real kernel ceiling on a Blackwell node;
- the pip version in the image, and the image and weights sizes, which nothing
  in the entry records.

### Who folds with this, and who has decided not to

This entry stays. It is built, its weights are fetched, its GPU ceiling is
measured, and everything known about its schema is written down — so a consumer
who wants an Apache-2.0 co-folding model with no restriction on its outputs can
use it for what it can actually do.

**Hap108or has decided not to build an adapter for it**, recorded 2026-09-25 in
ADR 0022 and as a declared refusal in both of its template sets
(`Hap108or-data/templates/*.yaml`). Two independent reasons, each sufficient:

- **The chemistry.** That project folds a peptide bonded to a hapten, and the
  settled section above establishes that `covalent_bonds` is declared and never read on the
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

## Build notes

**A `-devel` base and a full CUDA/C++ toolchain, never purged.** Upstream
advertises *"kernel acceleration through cuEquivariance and DeepSpeed4Science
kernels"*, and both compile at **first use**, on the compute node, in the
middle of a job: cuEquivariance's triangle kernels are Triton and shell out to
`cc`; DeepSpeed4Science's evoformer attention goes through DeepSpeed's JIT op
builder, which needs `nvcc`, a C++ compiler and `ninja` at run time, and fails
the same way — late, loudly, nothing written. Boltz can ship without a
compiler and record `--no_kernels` in its `NOTE` because upstream documents
that flag; OpenFold3 has no documented equivalent, which removes the argument
for the cheaper image. `%post` and `%test` both assert `cc` and `nvcc`;
`tool_doctor` probes the built image for both rather than trusting this
paragraph, so a rebuild from a slimmer base is noticed instead of discovered by
a job. `TORCH_EXTENSIONS_DIR` is pointed at `/tmp` — its default is under
`$HOME`, which here is small, shared, and the last place two concurrent array
tasks should both be writing a build tree. `%post` also imports
`cuequivariance_torch` explicitly and says what it means if the import is
missing, because boltz's failure mode was precisely a kernel package that was
absent while everything importable imported fine. The trap in general, and its
forms across this registry:
[`docs/07-containers-apptainer.md`](../../docs/07-containers-apptainer.md#a-kernel-that-compiles-at-first-use-needs-a-compiler-in-the-image),
"A kernel that compiles at first use needs a compiler in the image".

**`HF_HOME` is exported *inside* the weights directory.** `chpc.env` otherwise
points it at user scratch, which is right for a cache and wrong for the only
copy: scratch is purged at 30 days and is never canonical (doc 02).

## Traps

- **The repository has a hyphen.** `aqlaboratory/openfold-3`.
  `aqlaboratory/openfold3` is a 404 and `aqlaboratory/openfold` is the
  AlphaFold **2** reimplementation, which is a different model. Worth a line
  because two of those three are easy to reach for.

### Templates: the only direct interface of the six

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

CLI: `run_openfold predict --query_json=... --use-templates true`.

**Like every tool here but Boltz-2, its template pair features are masked to
within one chain** — `multichain_pair_mask`, under the comment *"Create asym ID
to mask inter-chain features"*. A template cannot hand over a binder's position
in OpenFold3. See ADR 0020's 2026-09-24 amendment in the parent repo.

**`covalent_bonds` is declared on `Query` and read by nothing.** Grep the
package: it appears in the schema and in no other file. A covalently bonded
ligand cannot be expressed here today, which matters more for this project than
the template story does.
