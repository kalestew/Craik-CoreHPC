# Protenix v1

<a id="run-it"></a>

## Run it: P1B7, peptide–MHC and the covalent ligand

This walkthrough uses the full deposited sequences from
[PDB 8UDR](https://www.rcsb.org/structure/8UDR): HLA-A*03:01, beta-2-
microglobulin, the sotorasib-modified KRAS peptide and both chains of the
P1B7 Fab. The [example bundle](../../examples/p1b7/) contains the prepared
JSON input, so your first run does not require writing JSON or installing
Python packages.

### From your laptop: transfer and submit with Globus

After [Globus setupB-storage-and-data.md#laptop-to-cluster-globus-is-the-normal-transfer-route),
from your local CoreHPC checkout:

```bash
source ./env.sh &&
chpc-globus.sh doctor "$CHPC_REPO/examples/p1b7" &&
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch --dry-run -- protenix
```

```bash
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch -- protenix
```

The first block previews; the second transfers the input folder directly
from your project, waits for Globus success, then submits one GPU job using
the shared lab installation. Add `template` after `protenix` for the optional
template mode described below. Follow the
[shared laptop walkthrough](../../docs/11-p1b7-walkthrough.md#submit-from-your-laptop-with-globus)
for receipts, logs, and result retrieval. The numbered steps below are the
alternative manual cluster-shell route; do not run both for the same lesson.

### 1. Prepare your working folder on the login node

Follow the [shared setup](../../docs/11-p1b7-walkthrough.md) to connect with
`ssh chpc` and create a checkout at `~/corehpc`. In that SSH session, paste:

```bash
export COREHPC="$HOME/corehpc" &&
source "$COREHPC/env.sh" &&
export WORK="$CHPC_USER_SCRATCH/tutorials/p1b7-protenix-$(date +%Y%m%d-%H%M%S)" &&
mkdir -p "$(dirname "$WORK")" &&
cp -R "$COREHPC/examples/p1b7" "$WORK" &&
cd "$WORK" &&
printf '%s\n' "$WORK" > "$HOME/p1b7-last-workdir.txt" &&
git -C "$COREHPC" rev-parse HEAD > corehpc-commit.txt &&
pwd &&
python3 check_inputs.py &&
chpc-tool doctor protenix &&
bash run.sh protenix --dry-run
```

The `&&` at line endings stops the block on failure. It also saves the
working-folder path for reconnecting and writes the CoreHPC Git revision
to `corehpc-commit.txt` for your run record.

This copies the example into your own scratch folder and checks its inputs.
`WORK` is the variable holding that folder's path; `pwd` prints it.
`--dry-run` displays the eventual prediction command without running it.
Proceed when the input audit passes and the installed tool is available.
If the shared weights or image are missing, send the maintainer the exact
`doctor` message; students can use the shared installation directly.

### 2. Read the chains and bond in the JSON

On the login node:

```bash
python3 -m json.tool protenix.json
```

The outer square brackets enclose a list of prediction jobs; this example
has one. Its `sequences` list has six entities in this exact order:

1. HLA-A*03:01, chain A, 275 residues.
2. Beta-2-microglobulin, chain B, 99 residues.
3. KRAS peptide `VVVGACGVGK`, chain C, 10 residues.
4. P1B7 Fab heavy chain, chain D, 226 residues.
5. P1B7 Fab light chain, chain E, 213 residues.
6. Bound sotorasib component `CCD_MOV`, chain F.

The `covalent_bonds` entry connects `entity1: 3`, `position1: 6`,
`atom1: "SG"` to `entity2: 6`, `position2: 1`, `atom2: "C25"`.
Entity numbers count entries in `sequences`, starting at 1; they are not
chain letters. `copy1` and `copy2` both select the first and only copy.

The sixth residue of this peptide is biological KRAS Cys12. Position 12
would be wrong in this ten-residue input. `CCD_MOV` requests the bound
ligand from the chemical-component dictionary, so the ligand atom name is
dictionary **C25**. Chai's **C1** describes that same carbon under its own
SMILES-based naming; do not copy that name here. Reordering the entities
requires changing the bond's entity numbers even if the explicit chain IDs
stay unchanged. The [pinned upstream JSON format](https://github.com/bytedance/Protenix/blob/v1.1.0/docs/infer_json_format.md)
documents these fields for this installed version.

### 3. Request a GPU and start the prediction

On the login node:

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 64G -t 04:00:00 --pty bash -l
```

The allocation may wait in the queue. Once its new shell prompt appears,
paste these commands on the compute node:

```bash
source "$COREHPC/env.sh" &&
cd "$WORK" &&
hostname &&
nvidia-smi --query-gpu=name --format=csv,noheader &&
bash run.sh protenix
```

The runner explicitly selects `protenix_base_default_v1.0.0`, requests
five samples with seed 1, uses ten cycles and 200 diffusion steps, and
passes `--use_msa false`. This is a **single-sequence** teaching run:
no evolutionary alignment search is needed, and a compute node cannot
reach Protenix's online MSA service. Without either this flag or staged
MSA paths, the tool can retry a network search indefinitely.

The runner also closes standard input with `< /dev/null`; retain that
redirection when adapting its native command. It prevents an alignment
subprocess from waiting forever on an open input pipe. The L40S request
is also deliberate: this image does not support the cluster's Blackwell
GPUs. A generic `--gres=gpu:1` can land on an incompatible node.

The resources above are a starting allocation for the new full-Fab
tutorial. The small verified tests in the installation record below do
not establish its runtime, memory use or prediction accuracy.

### 4. Find the predictions and check chemistry

After the command finishes, in the compute-node shell:

```bash
find out/protenix-none -type f -name '*_sample_*.cif'
find out/protenix-none -type f -name '*summary_confidence*.json'
find logs -type f -name 'protenix-none-*.log'
python3 check_output.py protenix out/protenix-none
```

The runner checks each predicted covalent bond. If it reports a failed
geometry check, preserve the output and inspect the failure before using
that sample. A high confidence score does not rescue an incorrectly
attached ligand. The last command repeats that check on every sample,
printing `PASS` or `FAIL` and the relevant geometry.

Protenix writes samples in generation order. **`sample_0` is not a rank**;
compare the accompanying summary-confidence files when selecting samples.
Keep those files and the chemistry checks with the structures. The runner
refuses to reuse an existing output folder; repeat step 1 to start a new run.

### 5. Learn the template path with a related antibody

The no-template run above is the common baseline across all three tools.
Protenix cannot use an exact copy of 8UDR in the same way as the Boltz and
Chai reconstruction exercises: its template prefilter rejects near-complete
duplicate sequences. Simply supplying all five 8UDR chains can therefore
produce a successful job that silently used fewer templates than requested.

The optional example instead supplies **related 8VRA antibody-chain
templates only**. The input to be folded remains the complete P1B7/8UDR
assembly. This is a different experiment from giving Boltz or Chai all five
chains of 8UDR; compare results with that distinction recorded.

In the same active GPU allocation:

```bash
bash run.sh protenix template --dry-run &&
bash run.sh protenix template
find out/protenix-template -type f -name '*_sample_*.cif'
```

The runner prepares the template-hit files and a private template cache.
The mapping is P1B7 heavy chain D→8VRA heavy chain E and P1B7 light chain
E→8VRA light chain D: this entry reverses the antibody-chain letters.
HLA, beta-2-microglobulin and peptide receive no templates in this mode.

Protenix needs a per-chain `templatesPath` plus `--use_template true`,
locally staged mmCIFs, known release dates, and a cutoff that permits those
dates. The lab image exposes `PROTENIX_MAX_TEMPLATE_DATE` and
`PROTENIX_TEMPLATE_FETCH_REMOTE`; the runner sets up the example without
changing the shared cache. A template file's existence alone does not prove
the predictor used it. The [template notes below](#templates-reachable-and-admissible-once-one-literal-became-a-key)
explain the gates and what to check when using another structure.

### 6. Finish the session or submit a batch job

Type `exit` once to release the interactive GPU and return to the login
node. For a job that continues after disconnecting, prepare a fresh working
copy and paste this on the login node instead of step 3:

```bash
cd "$WORK" &&
mkdir -p logs &&
JOB_ID=$(sbatch --parsable p1b7.sbatch protenix) &&
printf '%s\n' "$JOB_ID" > last-job-id.txt &&
printf 'Submitted job %s\n' "$JOB_ID"
```

Append `template` after `protenix` for that mode. Do not reuse a folder
that already contains the selected mode's output. The
[shared walkthrough](../../docs/11-p1b7-walkthrough.md) gives copyable
commands for monitoring, logs, recovery and archiving. It also explains
the next step for research runs: generate MSAs before submission and use
absolute `pairedMsaPath`/`unpairedMsaPath` entries instead of disabling MSAs.

## Installed version and previous verification

| | |
|---|---|
| Status | verified 2026-09-25 on an L40S (`chpc-tool test protenix`, job 1986816, `ggpu1-09`, 140 s, three cases) |
| Image | `protenix_2.sif`; recipe [`protenix_2.def`](protenix_2.def). [`protenix_1.def`](protenix_1.def) is the pre-template recipe; its image is no longer the entry's |
| Base | `nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04`; protenix 1.1.0 in `/opt/venv`, torch 2.7.1+cu126, kalign 3.4.0 from source |
| GPU | `--gres=gpu:nvidia_l40s:1` or `--gres=gpu:nvidia_h100_nvl:1` (`GPU_MAX_CC=9.0`, no `sm_120`). Never a bare `gpu:1` |
| Weights | the `protenix_base_default_v1.0.0` checkpoint, the CCD and the template tables at `$PROTENIX_ROOT_DIR` (`$CHPC_LAB/data/protenix`), fetched by [`fetch-weights.sh`](fetch-weights.sh) on the login node, last run 2026-09-25 |
| Licence | code Apache-2.0; **v1 parameters Apache-2.0, commercial use permitted**. v2 weights are proprietary and are refused by `fetch-weights.sh`, `tool_doctor` and `test.sh` |
| Upstream | <https://github.com/bytedance/Protenix>, `protenix==1.1.0` on PyPI (2.0.0 is the v2 generation) |
| Pinned at | **v1**, for the licence: "Why v1" under Build notes |

## Command reference: your own inputs

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/protenix/run1 && cd "$_"   # in.json here; the same path is valid inside the container
chpc-tool exec protenix -- protenix pred -i in.json -o out -n protenix_base_default_v1.0.0 -s 101 -e 5 < /dev/null
```

`-s 101 -e 5`, and the implicit `-c 10 -p 200 -d bf16`, are the image's own
defaults, read from its `--help` on 2026-09-25; `-e` is samples *per seed*, so
`-s 1,2 -e 5` is ten structures. The JSON carries the MSAs as absolute
`pairedMsaPath`/`unpairedMsaPath` generated on the login node; for a
single-sequence fold add `--use_msa false` instead, which is what the verified
test runs. One or the other, never neither (Do not miss). No tool variable
appears on the line, so no `eval` is needed: `exec` exports
`PROTENIX_ROOT_DIR` into the container.

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines
to the values above, keeping the `< /dev/null`. The method, the `eval` idiom
and which GPU to ask for: [`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

A JSON **list** of jobs, each with a `name` and a `sequences` list. The plain
case `test.sh` folds:

```json
[
  {
    "name": "plain_probe",
    "sequences": [
      {"proteinChain": {"sequence": "MKTAYIAKQRQISFVKSHFSRQLEERLGLIE", "count": 1}}
    ]
  }
]
```

A ligand is `{"ligand": {"ligand": "C=CC(=O)NC", "count": 1}}`, a SMILES. A
protein chain with precomputed MSAs adds `pairedMsaPath` and `unpairedMsaPath`,
absolute. A bond is a top-level `covalent_bonds` list (Traps, "Covalent
bonds"); templates are a per-chain `templatesPath` plus `--use_template`
(Traps, "Templates").

Output lands under `-o out`: one `<name>_sample_<i>.cif` per sample with a
`<name>_summary_confidence_sample_<i>.json` beside it (`find out -name '*.cif'`
finds them). **The samples are in sample order, not ranked.** Boltz sorts on
confidence and writes the best as `_model_0`; Protenix does not, so `sample_0`
is an arbitrary draw. Rank on the summary-confidence JSON. Before trusting a
bonded structure, run the geometry checker on every draw you keep (Do not
miss); before trusting a templated one, know that every template gate is a
warning and the fold exits zero having used none (Traps).

## Do not miss

- **`< /dev/null` on every run.** `kalign.py` Popens kalign without setting
  `stdin`, kalign 3 reads stdin even with `-i`, and an inherited open pipe
  blocks it forever at 0% CPU with no output and no error. A tty gives EOF and
  `sbatch` gives `/dev/null`, so it only bites wrapper scripts, pipelines and
  `ssh host 'cmd'`, which is exactly where it did (Traps).
- **`--use_msa false`, or MSA paths in the JSON. Never neither.** The default
  is to search protenix-server.com; a compute node has no route out and the
  retry is `Retrying... (1/5)` every five seconds with a counter that never
  advances (job 1986556, cancelled at thirteen minutes). MSAs are a login-node
  stage with [`../mmseqs2`](../mmseqs2) or [`../colabfold`](../colabfold),
  passed as absolute paths.
- **The subcommand is `pred`, name the model, and skip `--use_default_params`.**
  `predict` is the function; `pred` is the registration. Write
  `-n protenix_base_default_v1.0.0` explicitly, because a default is how the
  wrong generation would arrive quietly and v2's weights are proprietary.
  `--use_default_params` sets `cycle=10, step=200` for the base checkpoints,
  which are already the CLI defaults: a no-op, not better numbers.
- **Bonds address entities by 1-based INDEX into `sequences`, not by chain
  id.** Reorder the list and every bond moves silently. Pass ligand atom NAMES
  (`C1`, `N2`), never integers: an integer has two bases depending on whether
  the SMILES carries a `[C:7]` map. Assert the geometry of every draw you keep,
  never a confidence score: [`../covalent-bonds.md`](../covalent-bonds.md).
- **L40S or H100 NVL, never a bare `--gres=gpu:1`.** The image has no `sm_120`
  kernels. On a Blackwell node `chpc-tool exec` refuses before anything runs;
  a job that got there by another route dies at the first kernel launch.

---

## Provenance

Built 2026-09-25 on the CoreHPC login node (tool.conf), after four separate
recipe defects: a base with no `nvcc` for an extension Protenix compiles at
import, an unpinned install that resolved 2.0.0, a missing `ninja`, and
`/opt/venv/bin` absent from `PATH` during `%post`. The template rebuild that
produced `protenix_2` is dated 2026-09-24 in the recipe and in tool.conf.
Builder and wall time are not recorded.

`chpc-tool test protenix` passed 2026-09-25: SLURM 1986816, `ggpu1-09`, NVIDIA
L40S (compute capability 8.9), 140 s, exit 0. Three cases, both folds with
`--use_msa false`:

1. a 31-mer folds: 31 CA atoms, CA radius of gyration 12.95 Å;
2. a declared covalent bond lands where it was declared: SG–C1 at 1.68 Å, one
   ligand contact inside 2.10 Å, furthest ligand atom 5.28 Å, and the bonded
   carbon's single heavy neighbour is C2, a terminal Michael-acceptor CH₂ by
   connectivity, which needs no atom names to be true;
3. the template date gate moves in both directions: the default cutoff
   (2021-09-30) rejects a 2024 structure and `PROTENIX_MAX_TEMPLATE_DATE=3000-01-01`
   accepts it; kalign 3.4.0 answers on the path `configs_data.py` points at.

The first attempt, SLURM 1986556, was cancelled after thirteen minutes because
`test.sh` omitted `--use_msa false` (Do not miss).

`GPU_MAX_CC=9.0`, measured 2026-09-25 in the built image on the login node with
`torch._C._cuda_getArchFlags()`, on the pinned version (protenix 1.1.0, torch
2.7.1+cu126): `sm_50 sm_60 sm_70 sm_75 sm_80 sm_86 sm_90`, no `sm_120`. How
that measurement is taken for a new entry: [`../README.md`](../README.md#add-a-tool).

`fetch-weights.sh` was re-run 2026-09-25 against `protenix_2.sif`: the probe
input and the `PROTENIX_ROOT_DIR` layout (`checkpoint/`, `common/`) both held,
and with `--use_template true` it fetched `common/release_date_cache.json`
(219,912 entries, 1976-05-19 to 2024-05-22, 37,540 of them after the
2021-09-30 cutoff) and `common/obsolete_to_successor.json` (4,344 entries).
`mmcif/` exists and is empty.

Read from upstream 2026-09-24 and still relied on: the v1/v2 licence split and
the model table (Build notes, "Why v1"); the `covalent_bonds` field names and
the ligand atom spellings (`docs/infer_json_format.md`);
`pairedMsaPath`/`unpairedMsaPath` and the absolute-path recommendation. The
bond addressing and the SMILES-name resolution were then read from
`json_parser.py`/`json_to_feature.py` on 2026-09-25, which is what the `NOTE`
and Do not miss state.

Still unknown:

- the ligand atom names Protenix writes into the output CIF: `test.sh` asserts
  on geometry, not names, for this reason;
- what `positionN` means on the ligand side for anything other than a
  one-residue SMILES ligand (`1` worked);
- a templated fold end to end on a compute node: the template measurements
  below drove the featurizer on the login node, and case 3 exercises the gate
  and kalign, not a fold with template features in it;
- the image size and the weights size, which nothing in the entry records.

## Build notes

### Why v1, and why that is not a conservatism

An AlphaFold-3-class co-folding model that, unlike AlphaFold 3, is Apache-2.0
on both halves — and, unlike AlphaFold 3, will bond a ligand to a polymer
residue without a `userCCD` detour. That combination is the entire reason this
entry exists beside [`../alphafold3`](../alphafold3).

v2 is newer and larger — 464 M parameters against 368 M. Its **weights are
proprietary**. Upstream's own words:

> The model weights of Protenix-v2 are proprietary and confidential
> information of the rights holder, are not released under any open-source
> license, and may not be reproduced, distributed, sublicensed, disclosed, or
> otherwise transferred to any third party in any form without the express
> prior written consent of the rights holder.

against, for everything else:

> The Protenix project including both code and model parameters is released
> under the Apache 2.0 License. It is free for both academic research and
> commercial use.

The AlphaFold 3 entry in this registry records what that distinction costs:
a weights licence restricts the **outputs**, and a structure that enters a
filing or a partnership is the part that gets asked about, years after the
run finished. AF3's restriction is unavoidable if you want AF3. Protenix's is
avoidable — it is a checkpoint name — so choosing v2 here would be repeating
the AF3 output-restriction problem on a model that did not have to have it.

So: `VERSION=1`, `fetch-weights.sh` refuses any model name containing `v2`,
`tool_doctor` fails if a `*v2*` checkpoint appears under `$PROTENIX_ROOT_DIR`,
and `test.sh` refuses to run against one. Four refusals rather than a sentence,
because a sentence is what the sotorasib SMILES had.

Upstream's model table, as read 2026-09-24:

| Model | Released | Params | Licence |
|---|---|---|---|
| `protenix_base_default_v1.0.0` | 2026-02-05 | 368 M | Apache-2.0 — **this one** |
| `protenix_base_20250630_v1.0.0` | 2026-02-05 | 368 M | Apache-2.0 |
| `protenix_base_default_v0.5.0` | 2025-05-30 | 368 M | Apache-2.0 |
| `protenix-v2` | 2026-04-08 | 464 M | **proprietary — not here** |

### `nvcc` at build time, and nothing compiles at run time

Protenix compiles a CUDA extension at import, unconditionally and with no
fallback: `protenix/model/layer_norm/layer_norm.py` builds
`layer_norm_cuda_kernel.cu` through `torch.utils.cpp_extension` the first time
the model modules are imported. So the base is `-devel` for `nvcc`, not merely
`build-essential` for `cc`, and a `-slim` base gives an image whose plain
`import protenix` succeeds and whose first real job dies (measured 2026-09-25
on the first build attempt). `%post` imports the model modules, so the compiled
extension is baked into the read-only image and a job never writes a CUDA
build tree. CUDA 12.6 rather than 12.8, because `pip install protenix` resolves
torch 2.7.1+cu126 and the extension is compiled against that torch's headers.
`%post` and `%test` assert the compiler, `tool_doctor` probes the built image
for it, and `%environment` points `NUMBA_CACHE_DIR`, `TRITON_CACHE_DIR` and
`TORCHINDUCTOR_CACHE_DIR` at `/tmp`. The trap in general, and its forms across
this registry: [`docs/07-containers-apptainer.md`](../../docs/07-containers-apptainer.md#a-kernel-that-compiles-at-first-use-needs-a-compiler-in-the-image),
"A kernel that compiles at first use needs a compiler in the image".

## Traps

### Covalent bonds: the addressing is not AlphaFold 3's

A top-level `covalent_bonds` list, each entry

```json
{"entity1": 1, "copy1": 1, "position1": 6, "atom1": "SG",
 "entity2": 2, "copy2": 1, "position2": 1, "atom2": "C1"}
```

Three things here will cost someone a day if they are not written down:

- **`entityN` is a 1-based position in the `sequences` list, not a chain id.**
  Every other tool in this registry that takes a bond — AlphaFold 3's
  `bondedAtomPairs`, IntelliFold's copy of it — addresses by `entity_id`,
  which is a *label*. Protenix's is an *index*. Reorder the `sequences` list
  for any reason and every bond in the file silently points somewhere else.
  Nothing errors; you get a structure.
- **A SMILES ligand's atom has two spellings, and the integer one has two
  different bases depending on the SMILES text.** Read from
  `json_parser.py`/`json_to_feature.py` rather than from the docs, because the
  earlier note here had it wrong. Protenix *names* a SMILES ligand's atoms
  itself, as `f"{element}{count}"` with a 1-based per-element ordinal in RDKit
  atom order — so `C3` and `N2` are real atom names, and they are exactly the
  vocabulary the consuming project calls `smiles_order`. **Pass names.** An
  integer (or a digit string, which is coerced) is resolved through
  `entity_dict["atom_map_to_atom_name"]`, and that map is keyed by RDKit **atom
  map number** when the SMILES carries explicit maps like `[C:7]`, and by
  0-based **atom index** when it carries none. One integer, two bases, selected
  by whether the SMILES happens to contain a colon. Both are valid atoms either
  way, so the wrong one is invisible. Assert the geometry afterwards regardless.
- **Boltz's renumbering warning applies here too**: whatever numbering the
  antibody carries, the bond references positions in the sequence string you
  supplied. Map back to EU numbering explicitly.

`test.sh`'s second case is the check that matters, and it does not trust any
of the above: it folds a one-cysteine peptide with a Michael acceptor and then
asserts, on the coordinates, that exactly one ligand heavy atom is within
2.1 Å of `SG`, that it is a carbon, and that that carbon's only heavy
neighbour inside the ligand is another carbon. The last clause is what
separates a terminal warhead CH₂ from the N-methyl carbon without depending on
what the predictor decided to name things.

Why that check and not a confidence score, and how every tool here addresses
a bond: [`../covalent-bonds.md`](../covalent-bonds.md).

### Templates: reachable, and admissible once one literal became a key

Measured 2026-09-24 by calling this image's own `TemplateHitFeaturizer`, not by
reading documentation. The tool has everything needed: a per-chain
`templatesPath` on the `proteinChain` object, a `--use_template` flag whose help
text says *"requires templatesPath in input JSON"*, and a parser for both
hmmsearch a3m and hhsearch hhr hits.

`protenix_1.sif` could reach all of that and never use a template, for three
independent reasons. `protenix_2` fixes all three. A fourth gate is data, not
image, and it fires first.

#### 1. No kalign, and Ubuntu has no package for it

Protenix re-aligns every hit against the query with kalign and discards the
alignment the a3m carried. Its own config says `"/usr/bin/kalign",  # apt-get
install kalign` — and that advice does not work on this base. kalign is in
Debian; it is in **no** Ubuntu 24.04 component, main or universe. `apt-cache
policy kalign` returns nothing at all. It is built from source here, v3.4.0,
pinned by tag and sha256, installed with prefix `/usr` so it lands on the exact
path Protenix already defaults to and needs no config patch.

Version note, because this registry now carries two: `chai1_2` installs kalign
3.x from Debian because `chai_lab` passes `--nthreads`, which kalign 2.04
rejects. Protenix passes the older `-format fasta`, which 3.4.0 still accepts —
measured — so 3.x is a superset and both tools take it. bioconda's `kalign` is
still 2.04; do not substitute it to "match upstream".

#### 2. The date cutoff was unreachable, and that was a bug, not a policy

`infer_dataloader.py` built its featurizer with a string literal,
`max_template_date="2021-09-30"` — Protenix v1's training cutoff — so every
structure released after it was rejected. Two gates, both measured on a 2024
structure:

| staged | result |
|---|---|
| no `common/release_date_cache.json` | `errors: ['8udr date unknown.']`, 0 features |
| the real date, 2024-10-16 | `warnings: ['... Release date for 8udr is after cutoff.']`, `errors: []`, 0 features |

The second is the one to worry about. `strict_error_check` defaults to false, so
a post-cutoff template is a **warning**: the job renders a templated input, reads
it, discards every template, folds, exits zero and writes a structure. Nothing
in the output distinguishes that from a templated fold.

Upstream's own source says the restriction was not intended at inference:

- `TemplateHitFilter._is_after_cutoff` opens with `if cutoff is None: return
  False` — a designed no-cutoff state;
- `get_templates` takes a per-call `max_template_date` override;
- and the inference call site in `template_featurizer.py` **already passes**
  `max_template_date=None`.

That `None` is dead, because `get_templates` tests it with `if
max_template_date:` and falls back to the constructor's literal. The recorded
patch in `protenix_2.def` makes that one literal read a config key whose default
is the same literal, so the tool is bit-identical unless the key is set:

```
PROTENIX_MAX_TEMPLATE_DATE=3000-01-01
```

`3000-01-01` is not invented — it is the sentinel Protenix's own training branch
uses for "no cutoff", a dozen lines away. The patch script asserts its target
text and fails the build if upstream moves it, rather than matching nothing and
shipping an image where the fix silently is not in.

**The release dates in the template mmCIFs are not touched.** Moving the gate
keeps the dates true and the admissibility argument checkable; falsifying a date
would not.

#### 3. `fetch_remote` defaults true, and compute nodes have no internet

`configs.data.template.get("fetch_remote", True)` — so a template whose mmCIF is
not staged is fetched from PDBe mid-job, which on this cluster is a hang rather
than an error. The key did not exist in the config dict at all, so it could not
be turned off. It exists now, same environment idiom:

```
PROTENIX_TEMPLATE_FETCH_REMOTE=false
```

Stage every template as `$PROTENIX_ROOT_DIR/mmcif/<pdbid>.cif`, **lower case and
uncompressed** — Chai-1 wants the same structure as `<PDBID>.cif.gz`, upper case
and gzipped, so one staging step has to write both spellings.

`fetch-weights.sh` now passes `--use_template true`, which is the only switch
that makes `download_inference_cache` fetch `release_date_cache.json` and
`obsolete_to_successor.json`. Without them every hit is rejected with
`<pdbid> date unknown`, because the prefilter requires the accession to be *in*
the table and reads an absent table as "unknown" rather than as "no opinion".

#### 4. The release-date cache is a MEMBERSHIP gate, and it fires first

Measured 2026-09-25, driving the tool's own featurizer over a real rendered
input. This is the gate that actually emptied the first templated fold, and it
is not the cutoff:

```python
if pdb_id not in self.release_dates:
    pdb_id = self.obsolete_pdbs.get(pdb_id, pdb_id)
    if pdb_id not in self.release_dates:
        return PrefilterResult(False, error=f"{pdb_id} date unknown.")
```

`prefilter` returns before `_assess_hit` is ever called. So a PDB id absent from
`common/release_date_cache.json` is rejected **whatever the cutoff is set to** —
`PROTENIX_MAX_TEMPLATE_DATE=3000-01-01` does not reach it. Two more properties
make it quiet:

- `_parse_release_dates` returns `{}` for a path that does not exist and raises
  nothing, so a **missing** cache and an empty one are the same thing; and
- `_is_after_cutoff` returns `False` for an unknown date, so the cutoff logic
  itself is not what rejects these — it never sees them.

Measured on this project's own sets, all three directions:

| `common/release_date_cache.json` | `PROTENIX_MAX_TEMPLATE_DATE` | features |
|---|---|---|
| absent | either | **0** — `errors: ['8vrb date unknown.']` |
| present, real 2024 dates | default `2021-09-30` | **0** — `warnings: ['... after cutoff.']` |
| present, real 2024 dates | `3000-01-01` | **3** |

Only the third row folds with templates, and it needs *both* fixes. Note the
first row's `errors` against the second's `warnings`: an unknown date is an
**error** and a post-cutoff date is a warning, and neither stops the fold.

**The shared weights root now has this file.** `fetch-weights.sh` was re-run
2026-09-25 with `--use_template true`, and `$CHPC_LAB/data/protenix/common/`
holds `release_date_cache.json` and `obsolete_to_successor.json` beside the
CCD; `mmcif/` exists and is empty.

**It is still not enough for a template released after 2024-05-22, and that is
the point.** The cache is not a v1-era snapshot: it holds 219,912 entries dated
1976-05-19 to 2024-05-22, 37,540 of them after the 2021-09-30 cutoff, so the
cutoff is a filter applied at inference, not a property of the file, and a
structure released between the cutoff and the snapshot needs only
`PROTENIX_MAX_TEMPLATE_DATE`. Anything released after 2024-05-22 is absent and
reads as `date unknown`, which is every entry this project templates on (8UDR
2024-10-16; 8VR9, 8VRA and 8VRB 2024-09-04). So the dates for the entries
actually used have to be supplied, and the only honest source for them is the
deposited entry: this campaign's `release_dates.py` reads
`_pdbx_audit_revision_history` out of the same mmCIF the fold will read,
selecting the `Structure model` revision 1.0 row, and refuses if the date
disagrees with what the template set declares. Taking the first row of that
loop without selecting on content type and revision yields the **deposition**
date — 8UDR deposited 2023-09-28, released 2024-10-16 — which is the wrong
number by thirteen months in the direction that makes a post-cutoff structure
look admissible under a tighter cutoff.

Build the overlay root rather than writing four entries into the shared one: a
four-entry cache is not a PDB release-date cache, and left where the next
campaign inherits it, every hit outside those four becomes `date unknown`.

### It hangs forever if stdin is an open pipe

Found by a job that sat at 0% CPU for three minutes and would have sat there
until the wall clock ran out. `protenix/data/tools/kalign.py` runs

```python
process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
```

and **never sets `stdin`**, so kalign inherits whatever the parent had. kalign
3 reads standard input even when `-i` names an input file, so if stdin is a
pipe that nobody ever closes, kalign blocks in `pipe_read` forever and Protenix
blocks in `communicate()` waiting for it. Measured: the python process at
`pipe_read`, its kalign child at `pipe_read` on the same inherited pipe, zero
CPU time, no children, no output.

It is invisible in the two places people test — an interactive terminal (stdin
is a tty, kalign gets EOF) and an `sbatch` job (stdin is `/dev/null`). It bites
a wrapper script, a pipeline, `ssh host 'cmd'`, and anything that runs Protenix
with a pipe on stdin. The same run redirected from `/dev/null` finishes in
seconds.

**So always run Protenix with `< /dev/null`** when templates are on. It costs
nothing and it is the difference between a fold and a job that burns its whole
wall-clock allocation producing nothing. This affects only the template path,
because kalign is the only thing Protenix shells out to.

### The image's own help text was wrong until 2026-09-26

`apptainer run-help` on `protenix_2.sif` (built 2026-09-24) advertises
`protenix predict --input in.json --out_dir out`: there is no `predict`
subcommand and no `--input` flag, and the model is unnamed. The recipe's
`%help` was corrected 2026-09-26 to the `pred -i ... -o ... -n ... < /dev/null`
line under Run it; the built image keeps the old text until the next rebuild.
Trust this README over the image's help.

### Two gates that survive on purpose

Both are warnings under the default `strict_error_check=False`, so both drop the
template and let the fold exit zero:

- a hit whose ungapped sequence is a substring of the query **and** covers more
  than 95% of it is a `DuplicateError` — the tool declining to template a
  structure with itself. So a target's own reference entry cannot template it;
- a hit under ten residues is a `LengthError`, so very short peptide
  templates are dropped. The tutorial’s 10-residue peptide is omitted because
  its matching reference sequence is a duplicate, not because all peptides
  are categorically unsupported.

### Templates are de-duplicated by SEQUENCE, so a set can collapse

`get_templates` de-duplicates surviving hits on `hit_sequence` with the gaps
stripped, before it takes the top `max_hits`. Three structures of the same
complex — the same antibody bound three ways — are three *structures* and one
*sequence*, so they collapse to a single template per chain. Measured: seven
admissible chain hits went in and **three** template features came out, one
each for the two Fv chains and MHC-α.

That is not a defect, but it means "a three-member template set" buys Protenix
one template per chain and buys Boltz-2 three, because Boltz-2 is handed
structures and never compares sequences. The number of members is not a
number that transfers between tools.

Measured consequence on a real three-member related set: of fifteen chain hits,
**seven** are admissible — all three for each of the two Fv chains, one of three
for MHC-α, and none for β2m or the peptide, because those two chains are
identical to the query in every member. The chains Protenix can be templated on
are exactly the ones that differ from the query.

### Who templates this, and who has decided not to

This entry keeps the whole templated path — the kalign build, both config
patches, the staging layout and everything measured above — and it is the only
place that keeps it. **Hap108or itself has decided not to use it.** Recorded
2026-09-25 in its two template sets (`Hap108or-data/templates/*.yaml`, a
declared refusal with reason `tool_drops_members`), so `h8` runs Protenix
untemplated and refuses at plan time rather than at workspace time.

The reason is the duplicate gate in the section above, not a defect in this image.
That project folds a haptenated peptide-MHC, so any template worth showing
shares the target's HLA allele, its β2-microglobulin and its peptide — and
those three chains are exact subsequences of the query at coverage 1.000, above
the 0.95 `DuplicateError` threshold. Three of the five covered chains drop, the
fold exits zero, and the record says it was shown a set whose chains were never
used. Rendering only the Fv chains is a different experiment: its `set_id` rides
inside that project's computation digest, and "templated on this set" and
"templated on the Fv half of this set" are not the same claim.

**None of that is a reason for another consumer to avoid it.** The gate only
fires on chains that are near-identical to the query, so it costs nothing on a
system where the template is a homologue rather than the same molecule — which
is the ordinary case. If you are templating here, what you need is on this page:

1. `protenix_2.sif`, for kalign and the two patched keys;
2. `--use_template`, and a per-chain `templatesPath` on each `proteinChain`;
3. `PROTENIX_MAX_TEMPLATE_DATE=3000-01-01` if any member post-dates
   2021-09-30, and a `common/release_date_cache.json` **overlay** carrying
   every member released after the snapshot's 2024-05-22 end;
4. every member staged as `$PROTENIX_ROOT_DIR/mmcif/<pdbid>.cif`, lower case
   and uncompressed;
5. `< /dev/null`, always;
6. and the expectation that a hit covering >95% of the query as a substring,
   or one under ten residues, will be dropped with a warning and an exit
   status of zero.
