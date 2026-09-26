# IntelliFold v2

| | |
|---|---|
| Status | built 2026-09-25; a real 658-token covalent fold ran on an H100 NVL (cc 9.0), twice, and `chpc-tool test intellifold` has not run |
| Image | `intellifold_2.sif`; recipe [`intellifold_2.def`](intellifold_2.def) |
| Base | `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04`; a JAX/XLA image with no torch in it |
| Engine | AlphaFold 3's JAX/XLA engine, vendored and **built from source** in `%post` |
| GPU | `--gres=gpu:nvidia_l40s:1` or `--gres=gpu:nvidia_h100_nvl:1` (`GPU_MAX_CC=9.0`, an exercised lower bound; Blackwell untested and refused) |
| Weights | `intellifold_v2.bin.zst` and `intellifold_v2_fourier.npz` at `$INTELLIFOLD_MODEL_DIR` (`$CHPC_LAB/data/intellifold/model_v2`), fetched by [`fetch-weights.sh`](fetch-weights.sh) on the login node |
| Bonds | `userCCD` and `bondedAtomPairs` both honoured (measured 2026-09-25); a declared bond can still be built at 2.8 Å, so check the geometry |
| Licence | **Apache-2.0, code *and* model parameters, commercial use permitted** |
| Upstream | <https://github.com/IntelliGen-AI/IntelliFold>; `UPSTREAM_REF` is unset in tool.conf, so the pip version in the image is not recorded |
| Training cutoff | **none stated upstream**, re-checked 2026-09-25 against the preprint, README, model card and the staged weights (Traps) |

## Run it

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l   # the real folds ran on nvidia_h100_nvl; an L40S is permitted and untested
mkdir -p /mnt/scratch/user/$USER/intellifold/run1 && cd "$_"   # in.json here; the same path is valid inside the container
eval "$(chpc-tool export intellifold)"                         # $INTELLIFOLD_MODEL_DIR in THIS shell, for the line below
chpc-tool exec intellifold -- intellifold predict in.json --model-dir="$INTELLIFOLD_MODEL_DIR" --output-dir=out -- --norun_data_pipeline
```

That is the line `test.sh` and the recipe's `%help` give. The first `--`
separates `chpc-tool exec intellifold` from the program; the second hands
everything after it to the AlphaFold 3 engine, and `--norun_data_pipeline` has
to be on that side. Seeds are `modelSeeds` in the JSON; how the diffusion
sample count is set is not recorded in this entry (the 2026-09-25 folds ran
five samples at one seed).

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines
to the values above. The method, the `eval` idiom and which GPU to ask for:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

AlphaFold 3's input dialect, one job per file. The plain case `test.sh` sends:

```json
{
  "name": "plain_probe",
  "modelSeeds": [1],
  "sequences": [
    {"protein": {"id": "A", "sequence": "MKTAYIAKQRQISFVKSHFSRQLEERLGLIE",
                 "unpairedMsa": "", "pairedMsa": "", "templates": []}}
  ],
  "dialect": "alphafold3",
  "version": 1
}
```

Empty `unpairedMsa`/`pairedMsa` is single-sequence mode; a real run pastes in
the a3m generated on the login node. `templates: []` means none; `templates`
absent means go and search, which is silent on a node with no internet
(Traps). A ligand is `{"ligand": {"id": "B", "ccdCodes": ["ACT"]}}`, or a
top-level `userCCD` block referenced the same way for anything you only have as
SMILES; a bond is a top-level `bondedAtomPairs`, `[["A", 6, "SG"], ["B", 1, "CH3"]]`:
chain label, 1-based residue, atom name.

Output lands under `--output-dir`, a `.cif` per sample (`find out -name '*.cif'`
is how `test.sh` finds it); a declared bond appears in it as `_struct_conn`
with `conn_type_id covale`. How the samples are named and whether the tool
ranks them is not recorded in this entry (untested); the 2026-09-25 folds were
compared on per-sample ipTM. Before trusting one: `_struct_conn` is a
declaration, not a geometry. In two of five samples on each ligand route the
file declared the covale and the two atoms sat 2.78-2.79 Å apart. Run the
checker on every draw you keep.

## Do not miss

- **Two `--` on the line.** `chpc-tool exec intellifold -- intellifold predict ... -- --norun_data_pipeline`:
  the first separates the tool from the program, the second is IntelliFold's
  own pass-through to AlphaFold 3. A flag on the wrong side of the second one
  is either unknown to IntelliFold or never reaches the engine.
- **`--norun_data_pipeline`, always.** The data pipeline reaches the internet
  and compute nodes have none (doc 02). Generate MSAs on the login node with
  [`../mmseqs2`](../mmseqs2) or [`../colabfold`](../colabfold) and paste them
  in as `unpairedMsa`/`pairedMsa`.
- **`eval "$(chpc-tool export intellifold)"` first, and `--model-dir`
  absolute.** Upstream's default is the relative `./model_v2`: a job that
  `cd`s anywhere gets an empty directory and tries to download from a node
  with no internet. Without the `eval`, `$INTELLIFOLD_MODEL_DIR` is empty on
  your command line.
- **It is a JAX image, not torch.** Nothing here reads torch's arch flags; XLA
  compiles kernels at first use, so a long silence followed by an OOM or a
  compile error is the `XLA_FLAGS` case (`--xla_gpu_enable_triton_gemm=false`
  is already set as an overridable default in `%environment`).
- **L40S or H100 NVL, never a bare `--gres=gpu:1`.** 9.0 rests on a real fold
  on an H100 NVL, not on an arch-flag list; Blackwell nodes are refused until
  something has run there.
- **A declared bond is not a bond, and the address is AF3's, not Protenix's.**
  `entity_id` is a chain label; a SMILES ligand cannot carry a bond, use a CCD
  code or `userCCD`; two of five samples declared a covale at 2.8 Å. Assert
  the geometry of every draw you keep: [`../covalent-bonds.md`](../covalent-bonds.md).

---

- **No training cutoff is stated upstream**, so whether a template post-dates
  these weights cannot be established from this page; Hap108or records that
  as a declared refusal. Templating works mechanically (Traps); the
  admissibility argument is yours to make.

## Provenance

Built 2026-09-25 (tool.conf): the image exists and its `%test` passes. Builder
and wall time are not recorded, and `UPSTREAM_REF` was never filled in.

`chpc-tool test intellifold` has **not** run, which is why the entry is
`built` and not `verified`. What it will prove when it does: case 1 folds a
31-mer with empty MSAs and asserts 31 CA atoms and a CA radius of gyration
above 3 Å; case 2 folds a one-cysteine peptide bonded to the CCD ligand `ACT`
at its `CH3` and asserts, on the coordinates, that exactly one ligand heavy
atom is within 2.1 Å of `SG`, that it is a carbon, and that that carbon's only
heavy neighbour inside the ligand is another carbon. Whether the engine accepts
`ACT`/`CH3` at all is unconfirmed. If case 2 is rejected, that is the finding:
record it here and leave `STATUS=built`.

### Bonds: the AF3 keys ARE honoured, and a bond it declares may not be one

**Measured 2026-09-25**, on a real covalent complex (a haptenated peptide-MHC
with an antibody Fv, 658 tokens) on an H100 NVL, five diffusion samples on
each of two ligand routes. Job ids were not recorded. This settles the first
question and opens a sharper one.

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

### The rest of the record

`GPU_MAX_CC=9.0` rests on that fold and on nothing else. There is no torch in
this image to read `_cuda_getArchFlags()` from, and a torch added later for
checkpoint conversion would describe the torch wheel, not the XLA path that
runs the model. Read it as a lower bound that has been exercised: L40S (8.9)
and H100 NVL (9.0) are permitted, RTX PRO 6000 (12.0) is refused until a fold
has run there, because jax compiles its kernels at first use and a node class
nothing has run on is a node class nothing has run on (tool.conf). Which nodes
are which: [`../README.md`](../README.md#which-gpu).

Bond support was originally unqualified: upstream's README says only *"The
input is an AlphaFold 3-style JSON"* and never mentions `bondedAtomPairs`.
Reading the source on 2026-09-25 narrowed it (`intellifold/run_jax_inference.py`
parses its input with `alphafold3.common.folding_input.load_fold_inputs_from_path`,
AF3's own parser, and neither `bondedAtomPairs` nor `userCCD` appears in any
file of the `intellifold` package) and the same day's fold settled it, above.

Verified against upstream 2026-09-24: the licence, quoted under Build notes;
`pip install intellifold` and the from-source route
`pip install ./third_party/alphafold3 && build_data && pip install intellifold`;
the CLI shape `intellifold predict <input.json> --model-dir=... --output-dir=...`
with post-`--` flags passed to AF3 and `--norun_data_pipeline` as the
no-data-pipeline mode; the two shipped artefacts, `intellifold_v2.bin.zst` and
`intellifold_v2_fourier.npz`, auto-downloading from Hugging Face into
`./model_v2` on first run.

Still unknown:

- the pip version pinned in the image (`UPSTREAM_REF` is empty), and the image
  and weights sizes, which nothing in the entry records;
- the job ids of the 2026-09-25 folds;
- whether the image runs on an L40S (permitted at 8.9, never exercised) or on a
  Blackwell node (refused);
- whether an empty `unpairedMsa`/`pairedMsa` is accepted as single-sequence
  mode by this engine: `test.sh` sends it and has not run;
- a `v2-flash` checkpoint: the brief mentions one, upstream's README names
  only IntelliFold-v2, and this entry does not fetch it;
- the CCD code `ACT` and its methyl atom name `CH3` used in `test.sh`'s bonded
  case, and whether the engine will accept a bond to it at all.

## Build notes

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

**A full toolchain in `%post`, kept, not purged.** Two reasons and only the
first is obvious:

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
discovered by a job. The trap in general, and its forms across this registry:
[`docs/07-containers-apptainer.md`](../../docs/07-containers-apptainer.md#a-kernel-that-compiles-at-first-use-needs-a-compiler-in-the-image),
"A kernel that compiles at first use needs a compiler in the image".

**`--model-dir` resolves to an absolute path on FAC.** Upstream's default
`--model-dir` is the **relative** `./model_v2`. That is the Boltz `BOLTZ_CACHE`
trap with a different name: a job that `cd`s anywhere gets a different, empty
directory and then tries to download from a node with no internet.
`tool_exports` resolves an absolute path and both the fetch script and the test
refuse a relative one.

## Traps

- **MSAs.** `--norun_data_pipeline`, always, on a compute node: the data
  pipeline reaches the internet and compute nodes here have none (doc 02).
  Supply `unpairedMsa` / `pairedMsa` in the JSON, generated on the login node
  with `../mmseqs2` or `../colabfold`. Everything after the bare `--` on the
  command line is passed straight through to AlphaFold 3.
- **`entity_id` is a chain label** (`"A"`, `"B"`), which is *not*
  `../protenix`'s convention — Protenix's `entity1` is a 1-based **index into
  the `sequences` list**. Neither tool errors on the other's convention. Both
  produce a structure.
- **A SMILES ligand cannot carry a bond.** AF3's documentation is explicit:
  *"there is no atom name that could be used to define the bond"*, and the fix
  is a registered CCD code or a `userCCD` block whose atom names you assign
  yourself (see `../alphafold3/README.md`, which works this through).
  `test.sh` uses a CCD code for that reason; the 2026-09-25 folds used a
  `userCCD` block and a registered code, and both were honoured (Provenance).

### Templates: the AlphaFold 3 route, validated offline

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

### No training cutoff is stated upstream, and that blocks templating

Re-checked 2026-09-25, and this time against the paper rather than only the
release notes. **IntelliFold-2 states no training data cutoff anywhere:**

- the preprint (*IntelliFold-2: Surpassing AlphaFold 3 via Architectural
  Refinement and Structural Consistency*, bioRxiv 2026.02.09.704787) says only
  "We re-processed the Protein Data Bank (PDB) dataset using an updated
  pipeline" in its data-curation section, with no date, no range and no
  evaluation-set boundary;
- the GitHub README gives none;
- the Hugging Face card gives none;
- the staged `model_v2` directory carries no metadata file.

Third parties benchmarking it partition on AlphaFold 3's 2021-09-30, but that
is a uniform benchmark date applied to ten co-folding tools at once — a
property of the benchmark, not a claim about these weights.

**A cutoff is a property of the weights, and this is a 2026 model.** Inheriting
IntelliFold-1's number would be an assumption, and the risk runs the dangerous
way: a 2026 model re-processing the PDB plausibly includes a 2024 release, which
would turn a template set meant as independent evidence into a memory aid and
make every score taken under it meaningless.

So a consumer who wants to template this tool has to establish the date
themselves — the mechanics work, and the Templates section above records them. What
cannot be established from this page is whether a given structure post-dates the
weights. Hap108or records that as a declared refusal with reason
`cutoff_unstated_upstream` in both its template sets, dated, so that the refusal
reads as a finding somebody can overturn rather than as an omission. Restore a
date here when upstream states one, not before.
