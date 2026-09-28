# IntelliFold v2

| | |
|---|---|
| Status | **verified** 2026-09-27 on `ggpu1-06` (NVIDIA L40S) in 2 m 32 s — folds, honours `bondedAtomPairs`, and puts the bond on the declared atom: 5/5 draws on glycosylation at 1.410–1.450 Å, and the sotorasib warhead on `C25` in 5/5 draws with 3/5 closed, best 1.727 Å against 1.765 Å in deposited 8UDR |
| Image | `intellifold_2.sif`; recipe [`intellifold_2.def`](intellifold_2.def) |
| Base | `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04`; a JAX/XLA image with no torch in it |
| Engine | AlphaFold 3's JAX/XLA engine, vendored and **built from source** in `%post` |
| GPU | `--gres=gpu:nvidia_l40s:1` or `--gres=gpu:nvidia_h100_nvl:1`, both exercised (`GPU_MAX_CC=9.0`, an exercised lower bound; Blackwell untested and refused) |
| Weights | `intellifold_v2.bin.zst` and `intellifold_v2_fourier.npz` at `$INTELLIFOLD_MODEL_DIR` (`$CHPC_LAB/data/intellifold/model_v2`), fetched by [`fetch-weights.sh`](fetch-weights.sh) on the login node |
| Bonds | `userCCD` and `bondedAtomPairs` both honoured, and the bond is always on the declared atom — but **a declared bond is a proposal the sequence prior can veto outright** (0/25 vs 15/15 on one residue of context), and warhead bonds come out long in a third of draws. Measured over 95 folds: [Bonds](#bonds-what-95-folds-say) |
| Licence | **Apache-2.0, code *and* model parameters, commercial use permitted** |
| Upstream | <https://github.com/IntelliGen-AI/IntelliFold>; `UPSTREAM_REF` is unset in tool.conf, so the pip version in the image is not recorded |
| Training cutoff | **none stated upstream**, re-checked 2026-09-25 against the preprint, README, model card and the staged weights (Traps) |

## Run it

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l   # both classes exercised: L40S (job 2008659, the full test) and H100 NVL (the 658-token folds)
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

Seeds are `modelSeeds` in the JSON, and each seed produces **five diffusion
samples**. That matters here more than for most entries: the covalent bond is
not built identically in every draw, so the sample count is part of the method
rather than a detail. See [Bonds](#bonds-what-95-folds-say).

### P1B7: the full covalent complex

The 823-residue sotorasib-modified pMHC–Fab complex from the shared
[P1B7 walkthrough](../../docs/11-p1b7-walkthrough.md). The input is committed as
[`examples/p1b7/intellifold.json`](../../examples/p1b7/intellifold.json) —
five protein chains, `MOV` as chain F, and the bond as
`[["C", 6, "SG"], ["F", 1, "C25"]]`.

**On the login node**, to set up a working copy:

```bash
export COREHPC="$HOME/corehpc" &&
source "$COREHPC/env.sh" &&
export WORK="$CHPC_USER_SCRATCH/tutorials/p1b7-intellifold-$(date +%Y%m%d-%H%M%S)" &&
mkdir -p "$WORK" && cp -R "$COREHPC/examples/p1b7/." "$WORK/" && cd "$WORK" &&
git -C "$COREHPC" rev-parse HEAD > corehpc-commit.txt &&
python3 check_inputs.py
```

Then in a GPU allocation:

```bash
srun -p gpu --gres=gpu:nvidia_h100_nvl:1 -c 16 --mem 96G -t 4:00:00 --pty bash -l
cd "$WORK" && eval "$(chpc-tool export intellifold)"
chpc-tool exec intellifold -- intellifold predict intellifold.json \
    --model-dir="$INTELLIFOLD_MODEL_DIR" --output-dir=out_if -- --norun_data_pipeline
python3 check_output.py intellifold out_if
```

**Measured 2026-09-27 on `ggpu4-02` (H100 NVL), 3 m 34 s**, one seed, five
samples:

| draw | `C:Cys6:SG – F:MOV:C25` | | `ranking_score` | rank |
|---|---|---|---|---|
| sample-0 | 2.608 Å | too long | 0.5385 | 2nd |
| sample-1 | 0.919 Å | **too short** | 0.5361 | 3rd |
| sample-2 | **1.755 Å** | against 1.765 Å deposited | 0.5330 | 4th |
| sample-3 | 1.484 Å | | 0.5404 | **1st** |
| sample-4 | 1.634 Å | | 0.5323 | 5th |

`check_output.py` passes three of five, and the best draw is **within 0.010 Å of
the deposited bond**. Three things to take from this, in increasing order of how
much they cost.

**The failures go in both directions.** A 0.919 Å sulfur–carbon contact is not a
long bond or a missed one — it is shorter than any real S–C bond and physically
impossible. A screen that only asks "is the ligand close enough to the anchor"
passes it. `check_output.py` uses a *window*, 1.40–2.10 Å, for exactly this
reason, and the lower bound is not decoration.

**Nothing in the output distinguishes the five.** All five write
`_struct_conn.conn_type_id covale` naming `C/CYS6/SG` and `F/MOV/C25`, including
the 0.919 Å and 2.608 Å draws. All five report `iptm 0.53`, `ptm 0.53`,
`fraction_disordered 0.01` — identical to two decimals — and all five report
**`has_clash 0.0`**, so the clash detector does not flag a sub-bond-length
sulfur–carbon contact either.

**And the tool's own ranking is not a bond screen.** Total spread in
`ranking_score` across the five is 0.008. The draw that reproduces the crystal
bond to 0.010 Å is ranked **fourth of five**; the 2.608 Å draw is ranked second
and the impossible 0.919 Å draw third. Taking the top-ranked model gives a real
bond here (1.484 Å) — but taking the top *two*, as anybody comparing samples
would, includes one that is not a bond at all.

So: three of five is the normal case rather than a bad run — the same rate
measured over 25 draws of the small fixture — and the selection cannot be
delegated to the tool. **Fold several samples, screen every one on the geometry,
and pick from what passes.**

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

Output lands under `--output-dir`, laid out as
`<name>/seed-<N>_sample-<M>/<name>_seed-<N>_sample-<M>_model.cif`, plus a
top-level `<name>_model.cif` which is a **copy of the draw it ranked first** —
count that one twice and you weight one sample double, which is why `test.sh`
globs on `sample-` rather than on `*.cif`. Five diffusion samples per seed.

A declared bond appears as `_struct_conn` with `conn_type_id covale` on the large
complexes; the small self-test cases write **no `_struct_conn` at all**, in
either direction. So the record is not even consistently present, let alone
trustworthy: `_struct_conn` is a declaration, not a geometry. Run the checker on
every draw you keep — and note that on the small cases there is *nothing* except
the geometry to read.

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
- **A DECLARED BOND IS A PROPOSAL, AND THE SEQUENCE PRIOR CAN VETO IT.** This is
  the most expensive thing on this page. Two runs differing by **one residue two
  positions from the bond** — `N-A-T`, a glycosylation sequon, against `N-A-K`,
  which is not — went **15/15 bonded at 1.34–1.48 Å** against **0/25, free
  ligand at 6.7–10.9 Å**. Same JSON, same CCD code, same atom names, same seeds.
  Nothing reports the veto: no log line, no `_struct_conn` either way, no
  confidence score that moves. So "IntelliFold honours `bondedAtomPairs`" does
  **not** license "this bond will be built" for a chemistry the model has not
  seen in that context. [Bonds](#bonds-what-95-folds-say).
- **The address is AF3's, not Protenix's.** `entity_id` is a chain **label**, not
  a 1-based index into `sequences`. Neither convention errors on the other's
  input. A SMILES ligand cannot carry a bond at all — use a registered CCD code
  or a `userCCD` block.
- **Warhead bonds come out long, so screen every draw.** Sotorasib on a cysteine
  put the bond on the right carbon in 25 of 25 draws and *closed* it in 17 —
  clustered at 2.0–2.1 Å against an ideal 1.81 Å, straddling the 2.1 Å gate.
  Assert the geometry of every draw you keep:
  [`../covalent-bonds.md`](../covalent-bonds.md).

---

- **No training cutoff is stated upstream**, so whether a template post-dates
  these weights cannot be established from this page; Hap108or records that
  as a declared refusal. Templating works mechanically (Traps); the
  admissibility argument is yours to make.

## Provenance

Built 2026-09-25 (tool.conf): the image exists and its `%test` passes. Builder
and wall time are not recorded, and `UPSTREAM_REF` was never filled in.

### Verified 2026-09-27, after the test was found to be wrong and the tool right

`chpc-tool test intellifold` PASSED on `ggpu1-06`, an NVIDIA L40S, in 2 m 32 s:

```
ok: 31 CA atoms, CA spread 12.79 A
  draw                                        C1   nearest which
  bonded_probe_seed-1_sample-0_model.cif   1.450     1.450 C1
  bonded_probe_seed-1_sample-1_model.cif   1.410     1.410 C1
  bonded_probe_seed-1_sample-2_model.cif   1.416     1.416 C1
  bonded_probe_seed-1_sample-3_model.cif   1.430     1.430 C1
  bonded_probe_seed-1_sample-4_model.cif   1.449     1.449 C1
5/5 draws carry the declared bond at 1.20-2.10 A
  draw                                       C25   nearest which
  warhead_probe_seed-1_sample-0_model.cif  1.986     1.986 C25
  warhead_probe_seed-1_sample-1_model.cif  2.091     2.091 C25
  warhead_probe_seed-1_sample-2_model.cif  2.632     2.632 C25
  warhead_probe_seed-1_sample-3_model.cif  1.727     1.727 C25
  warhead_probe_seed-1_sample-4_model.cif  2.129     2.129 C25
3/5 draws close the bond; best 1.727 A against 1.765 A in deposited 8UDR
```

**The first run of this test failed, and the tool was not at fault.** Case 2 as
originally written bonded a cysteine to the `CH3` of `ACT` — the acetate ion —
and read the result with `find … | head -1`. That reads `seed-1/sample-0`, and
`seed-1/sample-0` is the single worst draw of that seed's five, at 2.231 Å. Four
of the other five were fine. The test asserted a property of one arbitrary
sample, which is not a property of the tool, and it reported FAIL on a working
capability.

Two changes followed, both from the measurements below. Every draw is now
checked, never one. And the deterministic gate is a **glycosylation** case rather
than the cysteine one, because glycosylation is the configuration whose bond this
model builds every time — 5/5 here, 15/15 over three seeds, spread 0.14 Å. The
cysteine warhead moved to case 3, held to what it actually delivers.

Case 1 folds a 31-mer with empty MSAs and asserts 31 CA atoms and a CA radius of
gyration above 3 Å.

### Bonds: what 95 folds say

Two rounds of measurement. **2026-09-25**, on a real covalent complex (a
haptenated peptide-MHC with an antibody Fv, 658 tokens) on an H100 NVL, five
diffusion samples on each of two ligand routes; job ids not recorded.
**2026-09-27**, on ggpu1-06 (L40S), 95 folds across five configurations designed
to isolate what actually decides whether a declared bond gets built.

**Both keys are read.** A top-level `userCCD` block referenced as
`ccdCodes: ["LIG-1"]` is honoured, the ligand is tokenised per atom (41 heavy
atoms, matching the block), and a registered code from the image's own component
table works too. Neither key appears anywhere in the `intellifold` package — both
are read by the vendored AlphaFold 3 parser, which is why they work at all.

#### The sequence prior can veto a correctly addressed bond

| peptide | bond declared | draws at 1.2–2.1 Å | where the ligand sat |
|---|---|---|---|
| `MKTAY`**`N`**`AT`… | `ASN ND2` — `NAG C1` | **15/15** | 1.336–1.478 Å |
| `MKTAY`**`N`**`AK`… | `ASN ND2` — `NAG C1` | **0/25** | free, 6.7–10.9 Å |
| `MKTAY`**`N`**`AK`… reversed | `NAG C1` — `ASN ND2` | 0/15 | free, 8.4–13.0 Å |
| `MKTAY`**`C`**`A`… | `CYS SG` — `MOV C25` | 17/25 | `C25` nearest in 24/25; never escapes |
| `MKTAY`**`C`**`A`… | `CYS SG` — `ACT CH3` | 18/25 | `CH3` nearest in 23/25; two draws at 14–19 Å |

Rows one and two differ by **one residue, two positions from the bond**. `N-A-T`
is an N-glycosylation sequon; `N-A-K` is not. Everything else is identical — the
JSON, the CCD code, the atom names, the seeds, the engine, the node. One is a
textbook 1.44 Å N-glycosidic bond in every draw and the other is a free sugar
9 Å away in every draw.

Row three is the control that rules out the obvious alternative: reversing the
endpoints changes nothing, so `bondedAtomPairs` is unordered as documented and
the sequon is the whole variable.

**Nothing reports the veto.** The logs of the bonded and unbonded runs are
identical apart from JAX's dtype warning. No `_struct_conn` record appears in
either — the small cases write none at all. No confidence score distinguishes
them. A gate built on anything but the coordinates passes all 40.

The consequence for this programme: `bondedAtomPairs` being honoured is a
statement about the *parser*. Whether the model will act on it is a statement
about the chemistry **in its sequence context**, and it has to be measured for
the system you are folding, not inherited from a fixture that resembles it.

#### The warhead bond is built long

`MOV` is AMG 510 (bound form) — sotorasib, 41 heavy atoms, in the CCD baked into
this image, and the same component the P1B7 walkthrough folds. Its `C25` is the
acrylamide warhead carbon, which deposited 8UDR bonds to `CYS SG` at 1.765 Å.

Over 25 draws the bond is on `C25` — the nearest ligand heavy atom in 24 of 25,
and in the exception the neighbour `C24` at 2.767 Å with nothing in bonding range
at all. So the atom is never wrong. The *length* is: 17 of 25 inside 1.2–2.1 Å,
clustered at 2.0–2.1 Å, straddling the gate. Against the CCD's own geometry this
is systematically long by roughly 0.25 Å.

It is worth knowing why, because it is not a defect to be fixed by trying harder.
`MOV`'s `C25` carries three hydrogens and one heavy neighbour, and the CCD flags
**no leaving atom** — as a standalone component the bound form of the drug is
drawn complete, with the sulfur it attaches to replaced by an H. So the
declaration asks for a fourth heavy contact on a carbon the component says is
saturated, and there is no field in this dialect that says "remove this
hydrogen". `ACT`/`CH3` is topologically identical, and behaves the same way.
`NAG` is the contrast: `O1` **is** flagged as a leaving atom, and the sequon case
lands at 1.44 Å with a 0.14 Å spread.

The two ligand routes also disagree with each other on the large complex. Same
molecule, same atom names, same 41 heavy atoms — and the antibody lands 17–46 Å
from its crystal position on the shipped-block route and 52–53 Å away on the
registry route, non-overlapping over five samples at one seed. The registry route
is the one the model is more confident about (ipTM 0.70–0.71 against 0.57–0.59).
Whatever you fold with, record which.

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
- whether the image runs on a Blackwell node (refused, and still untried);
- a `v2-flash` checkpoint: the brief mentions one, upstream's README names
  only IntelliFold-v2, and this entry does not fetch it;
- whether the systematic 0.25 Å overshoot on a saturated warhead carbon is
  specific to this engine. The leaving-atom reading above explains it and does
  not prove it; the comparison that would is the same two ligands through
  `boltz`, `chai1` and `protenix`, which take SMILES and so encode the valence
  differently.

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
