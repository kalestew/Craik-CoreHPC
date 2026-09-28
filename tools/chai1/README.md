# Chai-1

<a id="run-it"></a>

## Run it: the P1B7/8UDR complex

This example folds the five protein chains of
[PDB 8UDR](https://www.rcsb.org/structure/8UDR), including the complete
deposited P1B7 Fab sequences, together with the covalently attached
sotorasib-derived ligand. The [input bundle](../../examples/p1b7/) supplies
the sequences, the ligand description, the bond restraint and reference
coordinates. You do not need to assemble these files by hand.

### From your laptop: transfer and submit with Globus

After [Globus setupB-storage-and-data.md#laptop-to-cluster-globus-is-the-normal-transfer-route),
from your local CoreHPC checkout:

```bash
source ./env.sh &&
chpc-globus.sh doctor "$CHPC_REPO/examples/p1b7" &&
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch --dry-run -- chai1
```

```bash
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch -- chai1
```

The first block previews; the second transfers the input folder directly
from your project, waits for Globus success, then submits one GPU job using
the shared lab installation. Add `template` after `chai1` for the optional
template mode described below. Follow the
[shared laptop walkthrough](../../docs/11-p1b7-walkthrough.md#submit-from-your-laptop-with-globus)
for receipts, logs, and result retrieval. The numbered steps below are the
alternative manual cluster-shell route; do not run both for the same lesson.

### 1. Copy and check the example on the login node

Complete the [shared setup](../../docs/11-p1b7-walkthrough.md) first; it
creates a checkout at `~/corehpc` and explains `ssh chpc`. In that SSH
session, on the login node, paste:

```bash
export COREHPC="$HOME/corehpc" &&
source "$COREHPC/env.sh" &&
export WORK="$CHPC_USER_SCRATCH/tutorials/p1b7-chai1-$(date +%Y%m%d-%H%M%S)" &&
mkdir -p "$(dirname "$WORK")" &&
cp -R "$COREHPC/examples/p1b7" "$WORK" &&
cd "$WORK" &&
printf '%s\n' "$WORK" > "$HOME/p1b7-last-workdir.txt" &&
git -C "$COREHPC" rev-parse HEAD > corehpc-commit.txt &&
pwd &&
python3 check_inputs.py &&
chpc-tool doctor chai1 &&
bash run.sh chai1 --dry-run
```

The `&&` at line endings stops the block on failure. It also saves the
working-folder path for reconnecting and writes the CoreHPC Git revision
to `corehpc-commit.txt` for your run record.

`WORK` stores your personal run-folder path; `pwd` prints that folder.
The input check should succeed, and `doctor` should report that Chai is
available. The dry run prints the command without predicting anything.
If a shared image or weight cache is missing, give the maintainer the
message; reinstalling Chai in your home directory is unnecessary.

### 2. Understand the two input files

On the login node:

```bash
cat chai1.fasta
cat chai1.restraints
```

The FASTA records are ordered as HLA heavy chain (275 residues),
beta-2-microglobulin (99), KRAS peptide `VVVGACGVGK` (10), P1B7 Fab heavy
chain (226), Fab light chain (213), and ligand. Chai assigns them chain
letters **A, B, C, D, E, F in that order**. The names in FASTA headers are
human-readable names; the restraint's chain letters refer to this order.
If you reorder records, you must update the restraints too.

A protein record begins `>protein|name=...`. The ligand record begins
`>ligand|name=...` and its next line is a SMILES string: a description of
the molecule's atoms and bonds. It describes the bound adduct used by this
example. Do not replace it with a free-drug SMILES from a catalogue.

The comma-delimited restraint connects **`C,C6@SG`** to **`F,@C1`**:
peptide chain C, cysteine 6, sulfur SG, to ligand chain F, atom C1. That
sixth peptide residue is KRAS Cys12 because this peptide begins at KRAS
residue 7. Chai uses positions in the supplied sequence, so enter 6 here.

The same warhead carbon is called **C25 in the MOV chemical dictionary**
and **C1 for this exact Chai SMILES**. These names are not interchangeable.
Changing the SMILES atom order can change Chai's atom names while preserving
the molecule. The checker verifies the example's mapping, and the runner
checks the predicted geometry afterwards. Chai generally appends an entity
copy suffix in its output, so the output atom may be named `C1_1`.

### 3. Allocate a compatible GPU and run

Paste on the login node:

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 64G -t 04:00:00 --pty bash -l
```

Wait for the new prompt. This starts a shell on a compute node; it may sit
in the queue first. Then paste:

```bash
source "$COREHPC/env.sh" &&
cd "$WORK" &&
hostname &&
nvidia-smi --query-gpu=name --format=csv,noheader &&
bash run.sh chai1
```

The runner passes both the FASTA and the covalent-restraint file, uses five
samples with seed 1, three trunk recycles and 200 diffusion timesteps, and
checks the resulting covalent geometry. These controls set how many
candidate structures Chai generates and how much refinement it performs;
you can keep the supplied values for this first run.

Use the named L40S GPU request as written. This installed Chai image cannot
run on the cluster's Blackwell GPUs, which a generic `--gres=gpu:1` might
assign. The 64 GB request is host memory, not GPU memory; these resources
are a starting allocation for this new full-Fab tutorial, not a measured
runtime or memory promise.

The first run uses **single sequences**, with no multiple sequence
alignments (MSAs) or template. Chai's ESM sequence embeddings remain on;
they are not an MSA. Do not add `--use-msa-server` or
`--use-templates-server` to a compute-node command: that node has no
internet access. For research runs, stage MSAs in Chai's expected alignment
format before submission and supply `--msa-directory`; see
[the shared MSA instructions](../../docs/11-p1b7-walkthrough.md).

### 4. Locate the results and distinguish sample number from rank

When the command finishes, in the same shell:

```bash
find out/chai1-none -type f -name 'pred.model_idx_*.cif'
find out/chai1-none -type f -name 'scores.model_idx_*.npz'
find logs -type f -name 'chai1-none-*.log'
python3 check_output.py chai1 out/chai1-none
```

There should be five predicted mmCIF structures and corresponding score
files. The last command repeats the geometry check on all samples; inspect
any `FAIL` before using the affected structure.
**`model_idx_0` is the first sample, not necessarily the best one.**
Unlike Boltz, Chai does not name the highest-confidence prediction `0`.
Preserve all the samples and their scores. A good confidence score cannot
substitute for the runner's covalent-geometry check or examination of the
antibody docking pose.

The runner refuses to overwrite an output folder. To repeat a mode, start
from a fresh working copy with step 1. This prevents an old prediction
from being mistaken for the result of a changed input.

### 5. Add the 8UDR reference as a template

While your interactive GPU allocation is still active:

```bash
bash run.sh chai1 template --dry-run &&
bash run.sh chai1 template
find out/chai1-template -type f -name 'pred.model_idx_*.cif'
```

The runner prepares the template-hit table and stages the reference
coordinates. Chai expects a **tab-delimited m8 hit table with no header**,
whereas its restraint file is **comma-delimited with a header**. Supplying
the mmCIF alone as `--template-hits-path` is not sufficient. The reference
must also be available as `templates/8UDR.cif.gz` beneath the prediction
output directory, with that capitalization and compression.

Template spans refer to residues with coordinates and must agree with
Chai's kalign alignment. They are not simply the full lengths of the
deposited chains. The example prepares these details for you. The
[template notes below](#templates-fixed-in-chai12-and-the-hit-range-is-kaligns-to-decide)
explain them when you are ready to supply another structure.

This run is a **reference-template reconstruction**: Chai has been shown
the experimental complex you will compare against. Keep it labelled
separately from the no-template prediction. It does not independently
establish that P1B7, or a new design placed in its pose, binds this target.

### 6. Release the GPU or use a batch job

Type `exit` once to return to the login node and release your interactive
allocation. To submit a run that survives closing the SSH session, make a
fresh work folder and use this on the login node instead of step 3:

```bash
cd "$WORK" &&
mkdir -p logs &&
JOB_ID=$(sbatch --parsable p1b7.sbatch chai1) &&
printf '%s\n' "$JOB_ID" > last-job-id.txt &&
printf 'Submitted job %s\n' "$JOB_ID"
```

Use `p1b7.sbatch chai1 template` for the template mode. Do not submit a
mode whose output folder already exists. Follow the
[shared walkthrough](../../docs/11-p1b7-walkthrough.md) for monitoring,
reading logs, recovering from errors, and archiving to permanent storage.

## Installed version and previous verification

| | |
|---|---|
| Status | verified 2026-09-25 on an L40S (`chpc-tool test chai1`, job 1986672, `ggpu1-06`, 87 s, two cases) |
| Image | `chai1_2.sif`, 3.48 GB, no weights; recipe [`chai1_2.def`](chai1_2.def), rebuilt 2026-09-24 to add kalign |
| GPU | `--gres=gpu:nvidia_l40s:1` or `--gres=gpu:nvidia_h100_nvl:1` (`GPU_MAX_CC=9.0`, measured: no `sm_120`). Never a bare `--gres=gpu:1`. |
| Weights | 6.2 GB at `$CHAI_DOWNLOADS_DIR` (`$CHPC_LAB/data/chai1`), fetched by [`fetch-weights.sh`](fetch-weights.sh); three parts, see Traps |
| Licence | Apache-2.0, code **and** weights |
| Upstream | `chai_lab==0.6.1` (PyPI) |
| Base | `python:3.12-slim` (torch 2.6.0+cu124) |
| Built | `chai1_1`: 2026-09-18, kanderson6, CoreHPC login node (716 s); `chai1_2`: rebuilt 2026-09-24 |

## Command reference: your own inputs

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/chai1/run1 && cd "$_"   # in.fasta here; the same path is valid inside the container
chpc-tool exec chai1 -- chai-lab fold --num-trunk-recycles 3 --num-diffn-timesteps 200 --num-diffn-samples 5 --num-trunk-samples 1 --seed 1 in.fasta out
```

Those are the image's own defaults (read from it 2026-09-25) plus a seed; the
self-test runs the same command at one recycle, 20 timesteps and one sample.
No `eval` is needed: `exec` exports `CHAI_DOWNLOADS_DIR` into the container
and nothing on the line above names a variable. The 31-residue self-test
peaked at 17.3 GB RSS; size `--mem` for your input.

A covalent bond is one more flag and one more file (the format is under
"Inputs and outputs"):

```bash
chpc-tool exec chai1 -- chai-lab fold --constraint-path cov.restraints --num-trunk-recycles 3 --num-diffn-timesteps 200 --num-diffn-samples 5 --num-trunk-samples 1 --seed 1 cov.fasta out_cov
```

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines
to the values above (its `--gres` default is already `nvidia_l40s`). The
method, the `eval` idiom and which GPU to ask for:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

**Input** is a FASTA whose headers carry chai's entity grammar:
`>protein|name=...`, or `>ligand|name=...` with a SMILES as the sequence. A
plain `>seq` header parses as a record and then fails entity-type dispatch,
which is a confusing error for a simple mistake. The self-test's two inputs:

```
>protein|name=test-peptide
MKTAYIAKQRQISFVKSHFSRQLEERLGLIE
```

```
>protein|name=pep
MKTAYCAKQRQISFV
>ligand|name=lig
C=CC(=O)NC
```

Chains are assigned positionally from the FASTA: entity 1 is `A`, entity 2 is
`B`. The self-test and the block above run single-sequence; upstream
recommends MSAs "for improved performance". Templates go in through
`--template-hits-path`, a tab-delimited m8 table whose structures must already
be staged (Traps, "Templates"); a compute node cannot fetch them.

**A covalent bond** is a `--constraint-path` file, comma-delimited with a
header. The residue is 1-based, the atom follows `@`, and a SMILES ligand's
atoms are named element plus 1-based per-element ordinal in RDKit atom order,
so `@C1` is the terminal CH2 of `C=CC(=O)NC` (its carbons are C1 C2 C3 in
written order and C4 the N-methyl):

```
chainA,res_idxA,chainB,res_idxB,connection_type,confidence,min_distance_angstrom,max_distance_angstrom,comment,restraint_id
A,C6@SG,B,@C1,covalent,1.0,0.0,0.0,peptide-hapten,bond1
```

Those names come from the RDKit pinned in this image; the self-test asserts
them and prints the whole ligand's naming (`C1_1 C2_1 C3_1 O1_1 N1_1 C4_1` in
`chai1_2.sif`, the `_1` being the entity copy). Every predictor addresses a
bond differently and every one folds a wrong address without complaint:
[`../covalent-bonds.md`](../covalent-bonds.md).

**Weights** are three parts (six TorchScript components, `conformers_v1.apkl`,
and a 5.6 GB traced ESM-2 3B from a different URL), all at
`$CHPC_LAB/data/chai1` and all fetched by `fetch-weights.sh`; `chpc-tool
doctor chai1` checks that the directory exists and is writable. The ESM trace
is the part a hand-built cache misses, and `--use-esm-embeddings` is on by
default (Traps, "Weights").

**Output** lands in the directory you named: `pred.model_idx_<i>.cif` for
each of the `--num-diffn-samples` draws, and its scores in
`scores.model_idx_<i>.npz`. **The index is the raw sample index, not a rank.**
`pred.model_idx_0.cif` is an arbitrary draw; the aggregate score is in the
`.npz`, and ranking is your job. Boltz is the opposite (`_model_0` is its
best), so "index 0" across the two tools compares a ranked best against a
random sample.

Before trusting a number: ipTM penalises beta-strand addition, so never filter
substrate poses on it; and for a covalent run, assert the bond geometry of
every draw you keep with the checker in `../covalent-bonds.md`. A bond that
landed 13.59 Å from the warhead cost about 0.01 of ipTM.

## Do not miss

- **Output is not ranked.** `pred.model_idx_0.cif` is an arbitrary draw. Rank on `scores.model_idx_<i>.npz` yourself.
- **`--gres=gpu:nvidia_l40s:1` or `nvidia_h100_nvl:1`, never a bare `gpu:1`.** No `sm_120` in this image; `chpc-tool exec` refuses a Blackwell node up front, but only the `--gres` line decides where a job lands.
- **The restraints file is comma-delimited with a header; the m8 template table is tab-delimited with none.** The same tool, two delimiters. The wrong one gives a file chai parses into zero restraints, and it folds anyway, exit 0 (job 1976695).
- **A failing kalign is silent.** The hit is dropped and the fold exits zero having used no templates. Max 4 templates per chain; it raises rather than truncating.
- **The FASTA header is `>protein|name=...`**, not `>seq`.
- **Do not filter substrate poses on ipTM.** Beta-strand addition is confidence-penalised, so the filter preferentially discards the correct extended geometry.

---

## Provenance

`chai1_1.sif` (3.47 GB) was built 2026-09-18 by kanderson6 on the CoreHPC
login node (716 s) and verified on an L40S with a one-case self-test.
`chai1_2.sif` was rebuilt 2026-09-24 to add kalign, without which templates
cannot run at all; STATUS dropped back to `built` because that is the registry
ladder (a different image is a different claim), and it was verified again
2026-09-25.

`chpc-tool test chai1` (job 1986672, `ggpu1-06`, NVIDIA L40S, compute
capability 8.9, 87 s, exit 0) proves two things, and the second is the one
that earns the word:

1. **A 31-mer folds.** At `--num-trunk-recycles 1 --num-diffn-timesteps 20
   --num-diffn-samples 1`, then 31 CA records, numeric coordinates in every
   Cartesian column, and a CA radius of gyration above 3 Å: 12.91 Å measured.
   The spread check is the one that matters; it separates "wrote a CIF" from
   "ran the diffusion module". ESM embeddings are left **on** (the default),
   because that path is what needs the 5.6 GB trace and is the most likely
   thing to be missing. The earlier one-case test, recorded when `chai1_1.sif`
   was the image, measured on an L40S: 47 s, 17.3 GB peak RSS, spread
   12.91 Å, pLDDT 82–89.
2. **A declared covalent bond lands where it was declared.** A 15-mer with one
   cysteine at position 6 and the Michael acceptor `C=CC(=O)NC`, restraint
   `A,C6@SG,B,@C1`, 40 diffusion timesteps; then the shared geometry checker
   ([`check_covalent_bond.sh`](../_template/check_covalent_bond.sh)), by
   connectivity rather than by name: SG–C1_1 at 1.83 Å, one ligand contact
   inside 2.10 Å, furthest ligand atom 5.86 Å, and the bonded carbon's single
   heavy neighbour is C2_1, a terminal Michael-acceptor CH2. Then the name,
   separately: the ligand's heavy atoms came back `C1_1 C2_1 C3_1 O1_1 N1_1
   C4_1`, element plus 1-based per-element ordinal in RDKit atom order, which
   is the vocabulary every restraint the consuming project renders addresses
   by name. A rebuild can renumber a SMILES ligand's atoms without moving a
   bond, so the assertion is made against this image at qualification time.

Case 2 was added on the day of qualification because case 1 alone cannot
support the word: HA-ADAPT's chai1 corpus is quarantined over a bond that
landed 13.59 Å from the warhead, and case 1 would have passed on every one of
those structures. The story, once:
[`../covalent-bonds.md`](../covalent-bonds.md). The fixture chemistry is not
the campaign's; the programme's hapten lives in the data repo and never in a
tool registry.

`GPU_MAX_CC=9.0` is measured, not inferred: `chai_lab` requires `torch<2.7`,
so this image is torch 2.6.0+cu124, and inside it
`torch._C._cuda_getArchFlags()` reports `sm_50 sm_60 sm_70 sm_75 sm_80 sm_86
sm_90`, no `sm_120`.

Licence: the old non-commercial Chai Community License was replaced. v0.6.1 is
Apache-2.0 for the weights as well as the code (checked against the repo's
LICENSE file 2026-09-17), so this is usable commercially and nothing here
needs `chpc-assets`.

## Build notes

Base is `python:3.12-slim` and not a pytorch tag because `chai_lab` 0.6.1
pins `torch>=2.3.1,<2.7` and `numpy~=1.21`; pip resolves torch 2.6.x with
cu124 wheels inside a 3.12 base, and no current `pytorch/pytorch` tag is that
old (`chai1_2.def`). The same pin is the hardware limit in the header.

`chai1_2.def` adds **kalign 3.4.0** from Debian trixie, because `chai_lab`'s
m8 hit parser asserts on the binary and `chai1_1.sif` had none. The rebuild
invalidates this tool's prediction cache by design (`spec_id` folds in
`container_digest`). Which kalign, and why the major version is load-bearing,
is under Traps, "Templates".

## Traps

- **`CHAI_DOWNLOADS_DIR` must arrive as `APPTAINERENV_CHAI_DOWNLOADS_DIR`.**
  The image sets it as a `/tmp` fallback in `%environment`, and a plain host
  `export` loses to that — even though the image writes it defensively as
  `${VAR:-default}` (doc 07). `chpc-tool` emits both forms. This silently put
  1.3 GB in `/tmp` before it was found.
- Chai's downloader is `requests` with no retry and no resume, and it writes
  to a temp name it only renames on success — so a broken connection near the
  end of the 5.6 GB trace discards the lot. `fetch-weights.sh` uses `curl -C -`
  for that file and chai's own API for the small ones.
- **Do not filter substrate poses on ipTM.** Beta-strand addition is
  confidence-penalised, so an ipTM filter preferentially discards the correct
  extended geometry. ipTM is fine for Track 3 binder designs.
- **Do not use `torch.cuda.get_arch_list()` to check the arch flags on a CPU
  node:** on torch 2.6 it returns `[]` when no GPU is present, which is
  indistinguishable from a CPU-only build (doc 05). Ask
  `torch._C._cuda_getArchFlags()` instead.

### Weights: three parts, and the third is easy to miss

`fetch-weights.sh` gets all of it, ~6.2 GB:

1. six TorchScript components via `chai1_component()` — `feature_embedding`,
   `bond_loss_input_proj`, `token_embedder`, `trunk`, `diffusion_module`,
   `confidence_head`
2. `conformers_v1.apkl`
3. **a traced ESM-2 3B, 5.6 GB, from a different URL prefix**

Part 3 is fetched lazily on first use because `--use-esm-embeddings` defaults
to true. Following the component list alone gets a cache that looks complete,
passes a file count, and fails at the first real fold on a node with no
internet. It is easy to miss because chai-lab does **not** depend on
`fair-esm` or `transformers` — neither is installed — so searching the
environment for an ESM dependency finds nothing. It ships its own trace.
The registry's `esm` entry is unrelated and does not satisfy this.

### Templates: fixed in chai1_2, and the hit range is kalign's to decide

Measured 2026-09-24, in both images, with networking disabled.

**`chai1_2.sif` fixes this and templates now load.** What follows is what
`chai1_1.sif` did, kept because the second half of it is still true.

Chai-1's template input is a **search result**, not a structure:
`--template-hits-path` takes a BLAST-m8 table and `--use-templates-server`
fetches one. Given a hit, `parse_m8_to_template_hits` resolves the structure
itself and then realigns it to the query with **kalign**:

```
AssertionError: kalign is required for templates, but was not found in PATH.
Try 'apt install kalign'?
```

`command -v kalign` found nothing in `chai1_1.sif`, so templates could not run
there at all. `chai1_2.def` installs **kalign 3.4.0** from Debian trixie and the
rebuild invalidates this tool's prediction cache by design (`spec_id` folds in
`container_digest`).

The major version is load-bearing in one direction. `chai_lab` runs
`kalign -i in -o out --nthreads 1`, and `--nthreads` arrived in kalign 3. The
kalign that bioconda still ships as `kalign`, and that `colabfold_1.5.5.sif`
carries, is **2.04**, and it rejects that command line — measured against
colabfold's own binary. kalign 3.4.0 also accepts the older `-format fasta` form
that protenix uses, so 3.x is a superset and both tools take it.

The failure is silent: `kalign_query_to_reference` catches `CalledProcessError`
and returns `None`, the hit is dropped, and the fold exits zero having used no
templates. `%test` therefore calls `chai_lab`'s own function and asserts on the
alignment it returns, not on `command -v kalign`.

Two other template facts worth having before that rebuild, both read from the
installed package rather than from documentation:

- **The CIF cache is offline-able, and the naming is exact.** The loader calls
  `rcsb.download_cif_file(hit_identifier.upper(), directory=...)`, which resolves
  `<dir>/<PDBID>.cif.gz` and downloads **only if that path does not exist**. The
  directory is not a flag: it is `<output_dir>/templates`, fixed in `chai1.py`.
  Staging `8VRA.cif.gz` there under exactly that upper-case name is what makes a
  templated fold possible on a compute node. Lower-case, or `.cif`, and the job
  reaches for `files.rcsb.org` and hangs.
- **The hit table is tab-delimited, and the restraints file next door is not.**
  `parse_m8_file` passes `delimiter="\t"`; the restraints reader passes no `sep`
  at all and therefore takes commas. The two files this one tool consumes
  disagree, and getting the restraints one wrong is what killed job 1976695.

#### The hit range is a fixpoint of kalign's alignment, not a span you choose

`subject_start`/`subject_end` are counted over the template chain's **modelled**
residues — the loader strips gap characters out of gemmi's polymer sequence
before slicing — which is a different basis from the AlphaFold 3 dialect's, and
for a cryo-EM Fab the two differ by more than a hundred residues.

That is necessary and not sufficient. The loader slices
`seq[subject_start:subject_end]`, realigns **that slice** to the query with
kalign, and then `TemplateHit.__post_init__` refuses the hit unless the
alignment consumes the slice from its first residue to its last:

```
ValueError: query_pdb_id='H' <> pdb_id='8vr9' yields discrepant start/end
indices: 1 116 != 0 117 - 1.
```

So the admissible range is whatever kalign says it is. Measured on a
three-member related set, 15 chain hits: **11 began at the first modelled
residue and 4 did not**, because kalign left the template's leading residue
unaligned. Writing the obvious `subject_start=1` made Chai-1 reject those four
outright; correcting only those four made all 15 load.

Being *rejected* rather than silently dropped is the only piece of luck on this
surface — everywhere else on it, a template that cannot be reconciled just
vanishes. It also means the span cannot be derived on the coordinator: it has to
be computed in this image, where kalign is, in the same way the ligand atom
mapping is derived where RDKit is.
