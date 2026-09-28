# P1B7 / 8UDR tutorial inputs

This folder contains everything needed to describe the P1B7 Fab bound to a
sotorasib-modified KRAS G12C peptide presented by HLA-A*03:01. You do not need
another lab project, a sequence editor, an MSA server or a Python environment
to prepare the starting files. Ordinary `python3` checks the bundle; the
shared containers run the predictions.

Start with the [step-by-step tutorial](../../docs/11-p1b7-walkthrough.md)
or the [Boltz](../../tools/boltz/README.md),
[Protenix](../../tools/protenix/README.md) or
[Chai-1](../../tools/chai1/README.md) walkthrough.

## Send a prediction from your laptop

Open a terminal in your CoreHPC checkout. After the one-time
[Globus setup](../../docs/02-storage-and-data.md), these commands check access,
preview the dispatch, then transfer this folder and submit one Boltz job:

```bash
source ./env.sh
chpc-globus.sh doctor "$CHPC_REPO/examples/p1b7"
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch --dry-run -- boltz
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch -- boltz
```

If CoreHPC is a submodule, use `source corehpc/env.sh` from your project
root instead. Replace the final `boltz` with `protenix` or `chai1` for another
predictor, or use `-- boltz template` for the template exercise. Each dispatch
gets a fresh scratch folder. Globus reads the files here directly; leave them
unchanged until the transfer finishes. See the
[laptop walkthrough](../../docs/11-p1b7-walkthrough.md#submit-from-your-laptop-with-globus)
for job status, logs and downloading results back into your project.

## What is in the input?

The five protein sequences come directly from the deposited polymer sequences
in [PDB 8UDR](https://www.rcsb.org/structure/8UDR), biological assembly 1.
They include residues without resolved coordinates. In particular, these are
the full deposited Fab chains, including their constant domains, rather than
the shorter variable domains used in some lab benchmarks.

- **A:** HLA-A*03:01 heavy chain, 275 residues.
- **B:** beta-2-microglobulin, 99 residues.
- **C:** KRAS peptide `VVVGACGVGK`, 10 residues.
- **D:** P1B7 Fab heavy chain, 226 residues.
- **E:** P1B7 Fab light chain, 213 residues.
- **F:** one sotorasib bound-form ligand, CCD component `MOV`, 41 heavy atoms.

That is 823 protein residues plus the ligand. This is larger than the earlier
658-token Fv benchmarks in the tool READMEs. Their timings and GPU memory
measurements do not measure this full-Fab input. The tutorial allocations are
starting requests, not guarantees of completion on every GPU.

All three predictors receive the same chain order **A, B, C, D, E, F**.
Chai assigns these letters by position in the FASTA; Protenix bond entities
are numbered **1 through 6** by position in its JSON list. Changing the order
without changing the bond changes the molecule.

### The covalent attachment, exactly

The cysteine is **position 6 in the supplied peptide sequence**, even though
it is **KRAS residue 12** in biological/author numbering. Its sulfur atom is
`SG`. The attached MOV atom is **`C25` in CCD naming**. The deposited
`_struct_conn` record says `C:CYS:6:SG` to `F:MOV:C25`; its distance is
1.765 Å. The offline checker confirms this against actual coordinates.

Boltz uses `[C, 6, SG]` to `[F, 1, C25]`. Protenix uses entity 3,
position 6, `SG` to entity 6, position 1, `C25`. Chai takes a SMILES string
instead of the CCD component, so the same terminal carbon is named **`C1`**:
its CSV says `C,C6@SG,F,@C1`. Copying `C25` into Chai's restraint would attach
the ligand to a different atom.

The Chai string begins `CCC(=O)`, the saturated bound-form chemistry, rather
than the unreacted drug's `C=CC(=O)`. The bond is still a separate restraint;
putting a ligand beside a peptide in a FASTA does not declare an attachment.
The ligand specification and mapping were cross-checked against the local
Hap108or target definition and its deposited reference, then stored here as
explicit tutorial data in [manifest.json](manifest.json).

The deposited structure uses **label chain F** for MOV but **author chain D**,
which is also the Fab heavy-chain author letter. The supplied checker uses
mmCIF **label** chain IDs to avoid mixing them up. Predictor outputs use the
tutorial's A–F order and sequence numbering from 1.

## Files to inspect

- [proteins.fasta](proteins.fasta): readable sequences with chain roles.
- [boltz.yaml](boltz.yaml): five proteins, `ccd: MOV`, and the bond.
- [protenix.json](protenix.json): six entities and `covalent_bonds`.
- [chai1.fasta](chai1.fasta) and [chai1.restraints](chai1.restraints): proteins,
  bound-form ligand SMILES, and the separate comma-delimited bond restraint.
- [intellifold.json](intellifold.json): AlphaFold 3's dialect — `bondedAtomPairs`
  with `[["C", 6, "SG"], ["F", 1, "C25"]]`, where `entity_id` is a chain **label**
  and not Protenix's 1-based index into the entity list. Neither convention errors
  on the other's input.
- [openfold3.json](openfold3.json): **the one that will not work, on purpose.** It
  declares `covalent_bonds` for the same bond as everything else here, and
  openfold3 validates the field and discards it, so the ligand comes out 18–47 Å
  away. Checked with `check_output.py openfold3 … --expect-unbonded`, which passes
  on the documented apo outcome and fails the day the field starts working. See
  [tools/openfold3/README.md](../../tools/openfold3/README.md#covalent-support).
- [rfd3.yaml](rfd3.yaml): the odd one out. Not a prediction — RFdiffusion3
  **designs** a new 120-residue protein around the sotorasib-modified cysteine,
  which is the job the P1B7 Fab does by other means. It declares no bond and has
  no way to, because it reads the bonds in `reference/8UDR.cif.gz` and infers the
  modification itself; see
  [tools/covalent-bonds.md](../../tools/covalent-bonds.md).
- [manifest.json](manifest.json): chain identities, reference URLs and SHA-256
  checksums of the bundled compressed structures.
- `reference/8UDR.cif.gz`: deposited P1B7 reference coordinates.
- `reference/8VRA.cif.gz`: related R023 antibody complex used in the Protenix
  template exercise; its antibody chain letters are the reverse of 8UDR's.
- `templates/protenix-D.a3m` and `templates/protenix-E.a3m`: explicit related
  antibody hits, not sequence MSAs.

[colabfold-protein-only.fasta](colabfold-protein-only.fasta) is an optional
five-chain **protein-only control** in ColabFold's colon-separated multimer
syntax. ColabFold does not represent this ligand or its covalent attachment.
That file cannot reproduce the haptenated target in the other three inputs.

## Check the bundle without starting a job

From this folder on your laptop, or from its scratch copy on the cluster,
type:

```bash
python3 check_inputs.py
bash run.sh boltz --dry-run
bash run.sh protenix --dry-run
bash run.sh chai1 --dry-run
```

`check_inputs.py` audits all six declarations, `intellifold.json` and
`openfold3.json` included. `run.sh` drives the first three; the other two are run
from their own tool pages, which record what each measured:
[intellifold](../../tools/intellifold/README.md#p1b7-the-full-covalent-complex)
and
[openfold3](../../tools/openfold3/README.md#p1b7-what-a-dropped-bond-actually-looks-like).

`PASS inputs` means the sequences, chain order, ligand and bond addresses
agree with the bundled deposited structure. `--dry-run` prints the exact
prediction command and starts no GPU work. It does not claim the installed
container has parsed the input or the full prediction has succeeded.

## Run and inspect a prediction

After starting the GPU allocation shown in the linked walkthrough, run one
of these commands from your scratch copy:

```bash
bash run.sh boltz
```

```bash
bash run.sh protenix
```

```bash
bash run.sh chai1
```

Each starts five samples with seed 1 and uses single-sequence input. This
keeps the first lesson independent of online MSA services. For scientific
use, prepare appropriate MSAs before the prediction job: use the login node
for remote searches/downloads and an allocated CPU node for substantial local
database searches. Follow the relevant tool README; single-sequence success
is not a measure of docking accuracy.

Results go into `out/boltz-none`, `out/protenix-none` or `out/chai1-none`.
Logs go into `logs/TOOL-MODE-JOB.log`, where the words are replaced by your
tool, mode and Slurm job number. The runner refuses an existing output folder;
make a fresh scratch copy for a rerun so an earlier result is not reused.

The runner requires all five model files and automatically checks every
predicted sample after the predictor finishes. To repeat the geometry check
yourself, type the matching command:

```bash
python3 check_output.py boltz out/boltz-none
python3 check_output.py protenix out/protenix-none
python3 check_output.py chai1 out/chai1-none
```

Use just the line for the result you actually ran. You can replace the final
directory with one model filename. The checks require all five complete
protein chains, the 41-atom ligand, the correct peptide SG and the correct
ligand attachment atom. They screen the attachment distance at 1.40–2.10 Å,
look for an extra ligand contact to the SG, and check the terminal carbon's
local connectivity from coordinates. A failed model stays on disk and the
job exits nonzero. Read the `FAIL` message before keeping that model.

A `PASS` checks local chemistry and composition. It does not establish the
correct antibody pose, side-chain stereochemistry or accuracy of the whole
complex. Compare the predicted structure with the reference as a separate
scientific assessment. Do not choose a sample solely because its filename
ends in zero: Boltz ranks its outputs; Chai and Protenix sample indices are
not ranks.

## Add templates as a second exercise

A template supplies known structural information to a prediction. It does
not add missing molecules or declare the covalent bond. Keep the same inputs
and request a separate template run:

```bash
bash run.sh boltz template --dry-run
bash run.sh boltz template
```

Boltz maps the five input protein chains A–E to A–E in the supplied 8UDR CIF.
This is a **reconstruction exercise using the known answer**, not an
independent prediction benchmark. `prepare_templates.py` expands the local
CIF and writes absolute paths into `prepared/boltz/boltz.yaml`. The output
goes to `out/boltz-template`.

```bash
bash run.sh chai1 template --dry-run
bash run.sh chai1 template
```

Chai also receives the known 8UDR reference. Its wrapper derives a
tab-delimited `prepared/chai1/chai1.m8` using the pinned container's kalign
and real template parser, and requires a valid hit for every protein chain.
The m8 subject coordinates count **modelled residues**, not the complete
deposited sequence. This matters for the heavy chain's nine unresolved
residues. Template structure requests copy the bundled snapshot locally;
they never fetch from RCSB during the GPU job. The wrapper also avoids
Chai's conflicting requirements that the output directory start empty while
template CIFs resolve under that directory. Output is `out/chai1-template`.

```bash
bash run.sh protenix template --dry-run
bash run.sh protenix template
```

Protenix's duplicate-sequence filter rejects templates essentially identical
to the query, so giving P1B7 its own 8UDR chains would silently lose those
templates. This exercise instead templates **only the two antibody chains**
on related [R023 structure 8VRA](https://www.rcsb.org/structure/8VRA):
P1B7 heavy D receives 8VRA heavy E; P1B7 light E receives 8VRA light D.
The MHC, beta-2-microglobulin and peptide receive no template. This is a
different experiment from the five-chain 8UDR demonstrations above.

The preparation creates `prepared/protenix/root`, links to shared model
weights, stages a lower-case `mmcif/8vra.cif`, and adds 8VRA's release date to
a **local** copy of the release-date cache. It sets the patched image's
template cutoff to `3000-01-01` and disables remote template fetching. The
shared cache is not edited. The generated JSON has absolute template paths.
Before inference, `protenix_template_check.py` calls the pinned image's actual
template parser and featurizer. It requires one accepted template for each
antibody chain without errors or warnings; otherwise the run stops. It writes
`prepared/protenix/template-check.json` as evidence. Output is
`out/protenix-template`. Also inspect the subsequent prediction log for
template warnings before claiming that inference used the templates.

## Provenance and validation scope

Snapshots were taken from the local Hap108or reference collection, whose
recorded retrieval date is 2026-09-24. `manifest.json` records their public
RCSB sources and exact stored-byte checksums. Inputs use the pinned registry
formats: [Boltz 2.2.1 YAML](https://github.com/jwohlwend/boltz/blob/v2.2.1/docs/prediction.md),
[Protenix 1.1.0 JSON](https://github.com/bytedance/Protenix/blob/v1.1.0/docs/infer_json_format.md),
and [Chai 0.6.1 template parser](https://github.com/chaidiscovery/chai-lab/blob/v0.6.1/chai_lab/data/parsing/templates/m8.py).

The offline input audit and deposited-reference geometry check pass locally.
On 2026-09-26, this bundle was transferred to CoreHPC scratch with Globus and
its template helpers were checked on the login node with the installed images:

- `chai1_2.sif`: `chai_template.py --prepare-only` accepted all five 8UDR
  protein hits, including the 217 modelled residues aligned to the full
  226-residue heavy-chain query.
- `protenix_2.sif`: the generated local cache and
  `protenix_template_check.py` produced one accepted feature for P1B7 D
  (226 residues) from 8VRA E (228), and one for P1B7 E (213) from 8VRA D
  (216), with no errors or warnings.

These were CPU template-input checks; they did not run GPU prediction.

### Measured 2026-09-27: the first full-Fab GPU runs

Every bonding input in this bundle has now been run on this complex, five samples
each at seed 1 with single-sequence inputs, and checked with `check_output.py`:

| | draws in 1.40–2.10 Å | range | closest to 1.765 Å | wall time |
|---|---|---|---|---|
| chai1 | 5/5 | 1.651–1.741 Å | 1.741 Å | 5 m 49 s |
| protenix | 5/5 | 1.488–1.640 Å | 1.640 Å | 2 m 07 s |
| boltz | 3/5 | 1.295–1.887 Å | 1.737 Å | 6 m 54 s |
| intellifold | 3/5 | 0.919–2.608 Å | 1.755 Å | 3 m 34 s |
| openfold3 | 0/5, by design | 18.2–47.2 Å | — | 2 m 02 s |

L40S (`ggpu1-06`) except intellifold, on an H100 NVL (`ggpu4-02`). Boltz, chai1
and protenix ran through `run.sh`; the other two from their own tool pages.

Read this as a demonstration of restraint handling, **not** a benchmark: five
draws at one seed, no MSAs, and `check_output.py` examines the local bond and
chain composition only. The antibody dock — the hard part, and the reason P1B7
exists — is not assessed by any of it.

The discussion of what the numbers mean, including why three of the four missed
draws were too SHORT rather than too long, is in the walkthrough's
[Covalent restraints, predictor by predictor](../../docs/11-p1b7-walkthrough.md#covalent-restraints-predictor-by-predictor).

The registered tools' own small GPU tests are described in their READMEs.
Those tests and older Fv benchmarks remain separate evidence from the runs above.
Preserve your job log and inspect the outputs from your run.
