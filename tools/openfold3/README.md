# OpenFold3 (research preview)

| | |
|---|---|
| Status | **verified** 2026-09-27 on `ggpu4-03` (H100 NVL) in 1 m 26 s — folds; `covalent_bonds` asserted still inert; and a covalent modification through `non_canonical_residues` built as a real bond in 5 of 5 draws. Phase 1 also folded on `ggpu4-04`, and the covalent geometry reproduced on an L40S to within 0.004 Å |
| Image | `openfold3_3.sif`; recipe [`openfold3_3.def`](openfold3_3.def) |
| Base | `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04`; torch 2.14.0+cu130 |
| GPU | `--gres=gpu:1`, any `gpu` node (`GPU_MAX_CC=12.0`: torch carries `sm_120`; the cuEquivariance and DeepSpeed kernels have not been exercised on a Blackwell node) |
| Weights | Hugging Face `OpenFold/OpenFold3`, default set `OpenBind-0`, into `$OPENFOLD3_WEIGHTS` (`$CHPC_LAB/data/openfold3`, with `HF_HOME` inside it) by [`fetch-weights.sh`](fetch-weights.sh) on the login node; whether that has completed is not recorded in the entry, `chpc-tool doctor openfold3` says |
| Covalent bonds | **yes — but not through `covalent_bonds`, which is inert.** Modifications go in as a CCD-named residue via `non_canonical_residues`; measured `SG–CD` 1.671–1.746 Å against a 1.81 Å ideal in 5/5 draws. The component must carry the amino-acid backbone, so this does not reach drug-sized adducts. See [Covalent support](#covalent-support) |
| Licence | Apache-2.0, code and weights, academic **and commercial** use |
| Upstream | <https://github.com/aqlaboratory/openfold-3> — **note the hyphen**; the wheel read is `openfold3` 0.5.0; `UPSTREAM_REF` is unset in tool.conf |
| Training cutoff | `OpenBind-0`: the PDB through **June 2025** |

## Run it

```bash
srun -p gpu --gres=gpu:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/openfold3/run1 && cd "$_"   # in.json here; the same path is valid inside the container
chpc-tool exec openfold3 -- run_openfold predict --query_json=in.json --output_dir=out \
    --use-msa-server=False --use-templates=False
```

**The two flags are not optional on a compute node.** Without
`--use-msa-server=False` this reaches the public ColabFold server and dies with a
`ProxyError` after about forty-five seconds, having already loaded 2.3 GB of
weights — and the three MSA flags inside the query do **not** prevent it
(Traps). No tool variable appears on the line, so no `eval` is needed: `exec`
exports `OPENFOLD_CACHE` and `HF_HOME` into the container. Any `gpu` node is
allowed as far as torch's kernels go; an H100 NVL and an L40S have both run it,
and the Blackwell nodes have not (Provenance).

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines
to the values above, `--gres=gpu:1` included. The method, the `eval` idiom and
which GPU to ask for: [`../README.md`](../README.md#run-a-tool-on-your-inputs).

### P1B7: what a dropped bond actually looks like

The 823-residue sotorasib-modified pMHC–Fab complex from the shared
[P1B7 walkthrough](../../docs/11-p1b7-walkthrough.md). **This tool cannot fold
that chemistry**, and the committed input
[`examples/p1b7/openfold3.json`](../../examples/p1b7/openfold3.json) exists to
demonstrate the failure rather than to avoid it: it declares `covalent_bonds` for
the same `C:Cys6:SG – F:MOV:C25` bond every other predictor in the bundle
declares, and openfold3 drops it.

Why this case cannot use the route that *does* work: the modification would have
to exist as a single CCD component containing cysteine **and** sotorasib with the
backbone, and none does. `MOV` is a ligand component — see
[What this cannot do](#what-this-cannot-do).

```bash
cd "$WORK" && python3 check_inputs.py     # $WORK from the walkthrough's setup block
chpc-tool exec openfold3 -- run_openfold predict --query_json=openfold3.json \
    --output_dir=out_of3 --use-msa-server=False --use-templates=False
python3 check_output.py openfold3 out_of3 --expect-unbonded
```

**Measured 2026-09-27 on `ggpu1-06` (L40S), 2 m 1 s**, five draws:

| draw | `C:Cys6:SG – F:MOV:C25` | nearest ligand atom |
|---|---|---|
| sample-1 | 40.113 Å | `C18` at 38.098 Å |
| sample-2 | 18.214 Å | `O2` at 17.159 Å |
| sample-3 | 34.691 Å | `C25` at 34.691 Å |
| sample-4 | 43.625 Å | `C28` at 30.600 Å |
| sample-5 | 47.205 Å | `C25` at 47.205 Å |

The run exits 0. All five models carry five correct protein chains and all 41
ligand heavy atoms. The declaration validated. And the ligand is **18 to 47 Å
from the atom it was declared bonded to** — not docked in the wrong orientation,
simply somewhere else in the box.

`--expect-unbonded` makes `check_output.py` **pass** on this, because the apo
outcome is the documented behaviour of a field that is read and discarded. It is
a tripwire, not an excuse: the day any ligand atom lands within 2.10 Å of that
`SG`, the check fails and tells you `covalent_bonds` has started working.

This is also the concrete reason the consuming project removed `openfold3` from
its AF3-dialect builder. Fold P1B7 here only as a deliberate apo arm, the way
[`../colabfold`](../colabfold/README.md#p1b7-protein-only-comparison) is used —
and label it as one.

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

Output lands under `--output_dir`; `test.sh` looks for a `.cif` with `find`.
Whether and how it ranks samples is not recorded in this entry.
**A fold has now happened** — phase 1 of `test.sh` produced a 31-residue chain,
CA spread 12.87 Å, on `ggpu4-04` (H100 NVL) on 2026-09-27, so the sentence that
stood here saying nothing had been folded with this image is retired. The
covalent refusal is unchanged: a query carrying a `covalent_bonds` entry
validates, runs, exits zero and writes a confident structure with no bond in
it.

**`molecule_type`'s vocabulary, read 2026-09-27.** It is an **integer enum**,
not a string:

```
MoleculeType: PROTEIN=0  RNA=1  DNA=2  LIGAND=3
```

This page flagged it as its one outstanding fact and warned that guessing
`"protein"` because it looks like AlphaFold 3 was exactly the wrong reasoning.
It was: the value is `0`. A working minimal query, which folded on 2026-09-27:

```json
{"seeds": [1], "queries": {"plain_probe": {
  "chains": [{"molecule_type": 0, "chain_ids": ["A"], "sequence": "MKTAY..."}],
  "use_msas": false, "use_paired_msas": false, "use_main_msas": false}}}
```

**It calls the public ColabFold MSA server by default, and the query's MSA
flags do not stop it.** `use_msas`, `use_paired_msas` and `use_main_msas` each
default to `True`, and setting all three false still goes to the network: the
fetch is gated by a *separate* experiment setting, `use_msa_server`, which
exists only as a CLI flag on `run_openfold predict` and is not a field of the
query schema at all. The query flags are what the MSA *pipeline* reads
(`msa_pipeline_configs.py:109`); whether a fetch happens at all is decided
before that. On a compute node, which has no internet here (docs/02), the
symptom is a `ProxyError` against `api.colabfold.com` forty-five seconds in,
after 2.3 GB of weights have already loaded:

```bash
run_openfold predict --query_json=q.json --output_dir=out \
    --use-msa-server=False --use-templates=False
```

So a real fold either passes that flag and names its own MSA files in
`main_msa_file_paths`/`paired_msa_file_paths`, or does not run.

## Do not miss

- **`covalent_bonds` IS INERT — use `non_canonical_residues` instead.** The
  field named for bonds is declared on `Query`, validates, and is dropped before
  the model sees anything: the AtomArray is byte-identical with and without it.
  Its endpoint is an integer atom index with no name to check against, so it
  could not be addressed safely even if it worked. What *does* work is a
  modification named by CCD code in `non_canonical_residues` — measured as a
  real bond in every draw. [Covalent support](#covalent-support).
- **THE `seeds` FIELD IN YOUR QUERY JSON IS ALSO IGNORED.** `InferenceQuerySet`
  declares `seeds`, and the runner reads `experiment_settings.seeds` instead —
  default `[42]`. A query asking for `"seeds": [1, 2, 3]` folds seed 42, writes
  its output under `seed_42/`, and says nothing. The count comes from
  `--num-model-seeds` and the values from `--runner-yaml`. For a predictor whose
  results you intend to compare, this is the most expensive silent default in
  the entry.
- **A modified residue must carry the amino-acid backbone.** `non_canonical_residues`
  accepts any CCD code, including a ligand's. Give it one — `MOV`, sotorasib —
  and it builds all 41 atoms, with **no backbone and no peptide bond on either
  side**: the chain is silently cut in two at that position. The only warning
  says "could cause issues with incorrect polymer linkage", which does not sound
  like what it is. A typo'd code fails as
  `AttributeError: 'NoneType' object has no attribute 'as_array'`.
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

## Covalent support

**Settled 2026-09-27 by measurement, and it reverses what this entry said
before.** OpenFold3 folds covalent modifications correctly and in every draw.
What it does not do is read the field named for them.

### The field that looks right and is dead

`Query.covalent_bonds` validates, and is then dropped before the model sees
anything. The proof does not need a GPU, because the model's only bond input is
the `token_bonds` feature and `create_token_bonds()` reads `atom_array.bonds` and
nothing else — so the question is settled on the AtomArray:

```
apo query          : 126 atoms, 126 bonds, 0 crossing a chain boundary
covalent_bonds set : 126 atoms, 126 bonds, 0 crossing a chain boundary
```

Byte-identical bond lists. `structure_with_ref_mols_from_query()` builds the
structure chain by chain, concatenates the segments, calls
`connect_via_residue_names()` — which bonds within and along residues, never
between chains — and never looks at `query.covalent_bonds`.

Two things make this a confident reading rather than an absence of evidence.
First, the string `covalent_bonds` occurs **once** in the whole package: its own
declaration. Second, its sibling field in the same model, `pocket_constraint`,
has a complete consumer chain — config, featurisation, the diffusion module and
its own tests — so the schema is not simply aspirational throughout. One field is
wired and the other is not.

And `Bond.atom1` is `Atom(chain_id: str, residue_id: int, atom_id: int)`. The
endpoint is an **integer index**; there is no way to name `SG`. That breaks rule
2 of [`../covalent-bonds.md`](../covalent-bonds.md) at the level of the type
declaration, so this field should not be used even after it starts working.

### The route that works

Put the modification in as a **residue**, by CCD code, on the polymer chain:

```json
{"queries": {"mod": {"chains": [{
  "molecule_type": 0, "chain_ids": ["A"],
  "sequence": "MKTAYCAKQRQISFV",
  "non_canonical_residues": {"6": "YCM"}
}], "use_msas": false, "use_paired_msas": false, "use_main_msas": false}}}
```

`YCM` is S-(2-amino-2-oxoethyl)-L-cysteine, the iodoacetamide–cysteine adduct.
The key is a **1-based residue id** as a string; `_cast_keys_to_int` converts it.

This reaches the model as a genuine bond feature, and the mechanism is worth
knowing because it explains the limits. A non-canonical residue is **atomized**
exactly as AlphaFold 3 specifies — `YCM` occupies 10 tokens where a plain `CYS`
occupies 1 — and its bonds therefore survive `filter_fully_atomized_bonds()` into
`token_bonds`:

```
plain CYS at 6   122 atoms -> 15 tokens; residue 6 occupies  1 token;  0 token bonds
YCM at 6         126 atoms -> 24 tokens; residue 6 occupies 10 tokens; 9 token bonds
                 ... YCM6/CB -- YCM6/SG, YCM6/SG -- YCM6/CD, YCM6/CD -- YCM6/CE ...
```

Measured on `ggpu4-03` (H100 NVL), five diffusion samples:

| draw | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| `SG–CD` (Å) | 1.746 | 1.732 | 1.674 | 1.728 | 1.671 |

Against a CCD ideal of 1.81 Å, with the rest of the adduct built too
(`CD–CE` 1.47–1.51, `CE–NZ2` 1.28–1.33). **Five of five**, and the same five
distances came out within 0.004 Å on an L40S — so this is not one lucky draw on
one device.

### What this cannot do

The CCD component must contain **the whole modified residue, backbone
included**. That is a real bound, and it is where this route stops short of the
other five entries:

- a **modified amino acid** works: hundreds of PTMs and cysteine adducts have CCD
  codes, and they are what this route is for;
- a **drug-sized adduct does not**. Sotorasib on KRAS G12C is deposited as the
  ligand `MOV` bonded to `CYS`, and there is no CCD component for "cysteine plus
  sotorasib" as one residue. Passing `MOV` to `non_canonical_residues` builds its
  41 atoms with no backbone and **cuts the chain in two** at that position;
- a **custom component cannot be supplied.** `ccd_file_path` exists on the
  inference config and is read — but only into the **template** pipeline.
  `get_structure_with_ref_mols()` is a `@staticmethod` taking the query alone, so
  it never receives it and resolves CCD codes through biotite's bundled
  dictionary. Biotite's own `struc.info.set_ccd_path()` would do it, and no
  openfold3 setting reaches that at inference.

So: use this entry for post-translationally modified proteins, and use
`intellifold`, `boltz`, `chai1` or `protenix` for a covalent ligand. The P1B7
walkthrough's chemistry is the second kind.

## Provenance

Built 2026-09-25 (tool.conf): the image exists and its `%test` passed on the
login node. Builder and wall time are not recorded, and `UPSTREAM_REF` was
never filled in.

### Verified 2026-09-27: it folds, and it does covalent after all

`chpc-tool test openfold3` PASSED on `ggpu4-03`, an NVIDIA H100 NVL, in 1 m 26 s:

```
ok: 31 CA atoms, CA spread 12.86 A
apo query          : 126 atoms, 126 bonds, 0 crossing a chain boundary
covalent_bonds set : 126 atoms, 126 bonds, 0 crossing a chain boundary
ok: covalent_bonds is declared, parsed, and dropped -- the AtomArray is
    byte-identical with and without it
  ycm_probe_seed_42_sample_1_model.cif   SG-CD 1.746 A
  ycm_probe_seed_42_sample_2_model.cif   SG-CD 1.732 A
  ycm_probe_seed_42_sample_3_model.cif   SG-CD 1.674 A
  ycm_probe_seed_42_sample_4_model.cif   SG-CD 1.728 A
  ycm_probe_seed_42_sample_5_model.cif   SG-CD 1.671 A
5 draws, SG-CD 1.671-1.746 A against the CCD ideal 1.81 A
ok: SG-CD is a real thioether in all 5 draws
```

**`verified` for this entry means a covalently modified fold actually ran and
the bond landed in the right place.** Not that the container started. That was
met — but through `non_canonical_residues`, not through the field the entry was
built around, which phase 2a now asserts stays dead. The reasoning is in
[Covalent support](#covalent-support); the short version is that this entry
spent two days concluding "apo folds only" from a correct reading of
`covalent_bonds`, and the error was in the *scope* of the conclusion rather than
in the reading.

Phase 2 previously sent the AlphaFold 3 spelling, `bondedAtomPairs`. That was
never going to work: phase 1 had already established the schema is not AF3's and
`Chain` is `extra="forbid"`. It was testing a key this tool has never had, which
is why it failed as outcome (a) — and why its failure carried no information
about covalent support at all.

Both phases remain hard failures, with deliberately **no** environment variable
to skip the second: an escape hatch is a thing that gets used at 6pm and quoted
back the next morning as a green test.

`GPU_MAX_CC=12.0`, measured 2026-09-25 inside the built image on the login
node with `torch._C._cuda_getArchFlags()`: torch 2.14.0+cu130, arch flags
`sm_75 sm_80 sm_86 sm_90 sm_100 sm_120`. Those are torch's flags. Upstream
advertises cuEquivariance and DeepSpeed4Science kernels whose own wheels may
be narrower, and neither has been exercised on a Blackwell node. Boltz's "any
`gpu` node" row is trustworthy because it was actually run there (jobs 1899084
on an H100 NVL and 1899088 on `ggpu1-19` for torch, and 1997377 on `ggpu1-16`
for its cuequivariance kernels, 2026-09-26); this one is not yet. How the
measurement is taken: [`../README.md`](../README.md#add-a-tool).

### Settled 2026-09-25: it is not an AlphaFold 3 dialect, and the bond field is dead

> **Read with the section above.** Everything here about the schema and about
> `covalent_bonds` was confirmed on 2026-09-27 and still stands. What did not
> stand is the conclusion drawn from it — "fold the apo system here and nothing
> else" — because it assumed `covalent_bonds` was the only route to a bond.
> `non_canonical_residues` is the other one, and it works.

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

**What followed, and what replaced it.** The conclusion drawn here was "fold
the apo system; refuse anything covalent", and for a covalent *ligand* that is
still right. It was too broad for a covalent *modification*, which
`non_canonical_residues` builds correctly — see
[Covalent support](#covalent-support). The consuming project's removal of
`openfold3` from its AF3-dialect builder stands on its own footing: its chemistry
is a peptide bonded to a hapten, which is the ligand case, and no CCD component
contains that adduct as a residue.

`test.sh` phase 2a keeps the value this paragraph claimed for it, and states it
as an assertion rather than a hope: it fails if `covalent_bonds` ever starts
producing a bond, and says so in those words.

`test.sh` phase 2 *used* to try the AlphaFold 3 spelling — `bondedAtomPairs`
with `[entity_id, residue_id, atom_name]` endpoints and a registered CCD ligand
— on the grounds that it was the only documented candidate. It was written to
distinguish three outcomes:

| Outcome | Looks like | Means |
|---|---|---|
| (a) rejected | schema error naming the key | wrong key. Find the real one in the installed package's schema, write it here |
| (b) accepted, ignored | a run that succeeds, a plausible structure | **the dangerous one.** The checker catches it as a free ligand metres from the anchor |
| (c) accepted, honoured | geometry check passes | qualified. Paste the working JSON into this file — upstream documents none |

The framework was sound and the candidate was not. `bondedAtomPairs` is not a
key this tool has ever had, so phase 2 was pinned at (a) by construction and its
failure said nothing about covalent support. Worth keeping as a lesson: a test
whose input cannot be right produces a red tick that *feels* like a finding, and
this one was quoted as one.

Phase 2 now runs the real keys and splits the same way. `covalent_bonds` is
outcome **(b)** and phase 2a asserts it stays there. `non_canonical_residues` is
outcome **(c)**, and per the instruction in this table's last row, the working
JSON is pasted into [Covalent support](#covalent-support) — upstream documents
none.

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

- **The chemistry.** That project folds a peptide bonded to a hapten — a
  covalent *ligand*. `covalent_bonds` is declared and never read, and the route
  that does work needs the whole adduct to exist as one CCD residue, backbone
  included, which no hapten conjugate does. So the best possible adapter could
  still only fold the apo system. This reason survives the 2026-09-27 reversal
  intact; it is the ligand/modification distinction that does the work, not the
  dead field alone.
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
