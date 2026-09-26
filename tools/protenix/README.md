# Protenix v1

| | |
|---|---|
| Status | **verified** 2026-09-25 — SLURM 1986816, ggpu1-09, NVIDIA L40S, 140 s, exit 0 |
| Image | `protenix_2.sif` — [`protenix_2.def`](protenix_2.def), the templates build |
| Upstream | <https://github.com/bytedance/Protenix> |
| Licence | code Apache-2.0; **v1 parameters Apache-2.0, commercial use permitted** |
| Weights | on FAC — [`fetch-weights.sh`](fetch-weights.sh), login node only |
| GPU | yes — `GPU_MAX_CC=9.0`, measured; **no `sm_120`**, so never a bare `--gres=gpu:1` |
| Pinned at | **v1**, for the licence. See "Why v1". |

An AlphaFold-3-class co-folding model that, unlike AlphaFold 3, is Apache-2.0
on both halves — and, unlike AlphaFold 3, will bond a ligand to a polymer
residue without a `userCCD` detour. That combination is the entire reason this
entry exists beside [`../alphafold3`](../alphafold3).

## Why v1, and why that is not a conservatism

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

## Covalent bonds: the addressing is not AlphaFold 3's

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

That is not defensive writing. It is the HA-ADAPT Chai-1 failure, which
quarantined 1,726 results: the peptide cysteine bonded to an aromatic ring
carbon at 1.68 Å instead of the warhead at 13.59 Å, and **ipTM moved 0.710 →
0.698** between the wrong structure and the right one. No confidence score
detects it. The shared checker is
[`../_template/check_covalent_bond.sh`](../_template/check_covalent_bond.sh).

## MSAs are a login-node stage, not a flag

`pairedMsaPath` and `unpairedMsaPath`, and upstream recommends **absolute**
paths. Compute nodes here have no internet (doc 02), so anything that reaches
an MSA server is a job that hangs until it times out. Generate on the login
node — that is what [`../mmseqs2`](../mmseqs2) and [`../colabfold`](../colabfold)
are for — and pass the files in.

## `GPU_MAX_CC` is 9.0, measured — so never a bare `--gres=gpu:1`

The `gpu` partition is three different devices: L40S at compute capability
8.9, H100 NVL at 9.0, RTX PRO 6000 Blackwell at 12.0. A bare `--gres=gpu:1`
lands on any of them. Five tools here declare a 9.0 ceiling and die on the
Blackwell nodes with `no kernel image is available for execution on the
device` — which reads as a broken install and is a scheduling accident
(doc 05).

**Measured 2026-09-25 inside the built image, on the login node, on the pinned
version** (protenix 1.1.0, torch 2.7.1+cu126):

```
sm_50 sm_60 sm_70 sm_75 sm_80 sm_86 sm_90
```

No `sm_120`. So this is one of the entries that must name its device: ask for
`--gres=gpu:nvidia_l40s:1` or an H100, or exclude `ggpu1-[13-19]` by name,
which keeps both eligible and is what this project's job scripts do.

The value stayed `UNMEASURED` until it was measured, and that literal is the
reason nothing was lost in the meantime: `chpc-tool` compares with `awk`
(`a+0 > b+0`) and `awk` reads a non-numeric string as `0`, so every device is
above that ceiling and `chpc-tool exec` refuses on any GPU node. Fails closed,
on purpose — a refusal is recoverable in seconds, a wrong ceiling is a job that
dies twenty minutes in with a message about the wrong thing.

To re-measure after a rebuild, inside the image, **on the login node**:

```bash
/usr/bin/apptainer exec "$CHPC_CONTAINERS/protenix_2.sif" \
  python -c "import torch; print(torch._C._cuda_getArchFlags())"
```

The highest `sm_NN` is the number: `sm_120` → `12.0`, `sm_90` → `9.0`. The
login node has no `nvidia-smi`, so the guard is silent there and cannot block
its own measurement. Use `_cuda_getArchFlags`, **not**
`torch.cuda.get_arch_list()`, which returns `[]` when no GPU is visible —
exactly the login node. `%post` prints a `GPU_MAX_CC candidate:` line at the
end of the build; that is the same measurement, and it still has to be copied
into `tool.conf` by a human.

## The C-compiler trap: a compiler is installed, on purpose

Boltz's image is built from this same `python:3.12-slim` base with only `git`
and `ca-certificates`. Its cuequivariance kernels are Triton, which
JIT-compiles at first use and needs a C compiler **inside** the image, so every
prediction above ~128 total tokens dies four seconds in with
`RuntimeError: Failed to find C compiler` from `triton/runtime/build.py`,
having written nothing. Independently confirmed outside this registry: job
array 1928395 in a sibling project lost all five tasks in under a minute each
to exactly that error.

**Decision for Protenix: install `build-essential` in `%post` and keep it.**

Upstream's README does not say whether Protenix pulls a Triton-backed or
otherwise JIT-compiled kernel through its torch dependency chain, and that
could not be confirmed either way from the documentation — so this is
insurance, not a diagnosis. It costs ~200 MB against a failure that (a) wastes
a whole GPU job, (b) arrives mid-run rather than at import, (c) is invisible to
`--help`, to `%test`, and to any self-test small enough to be quick, and (d)
has no documented escape hatch here: Boltz has `--no_kernels` only because
someone already paid for that discovery. `%post` and `%test` both assert the
compiler is on `PATH`, and `tool_doctor` probes the built image for `cc`/`gcc`/
`clang` rather than assuming, so a future rebuild from a slimmer base is
noticed instead of discovered.

`%environment` also points `NUMBA_CACHE_DIR`, `TRITON_CACHE_DIR` and
`TORCHINDUCTOR_CACHE_DIR` at `/tmp`. A `.sif` is a read-only squashfs and
anything that caches beside its own source refuses at *import* time inside one
— which is how Boltz's numba failure got past a green build (doc 07).

## When someone builds it

```bash
chpc-tool build protenix            # login node only; /usr/bin/apptainer 1.5.2,
                                    # --fakeroot unavailable, no `module load apptainer`
tools/protenix/fetch-weights.sh     # login node; weights + CCD onto FAC
# read the GPU_MAX_CC candidate out of the build log, put it in tool.conf
chpc-tool publish protenix
chpc-tool test protenix             # GPU node -- this is what `verified` means
```

Weights and the chemical component dictionary go on FAC
(`/mnt/fac/CX500146_DS1`, 5 TB, ~1.1 TB used), never on `/mnt/scratch`, which
is purged at 30 days and is never canonical. Anything created on the share
needs `chpc-fac-fixacl` — the inheritable DENY ACL there makes new files
unreadable by their own owner (doc 02).

Do not flip `STATUS` past `planned` until `chpc-tool exec protenix` has run a
real inference, and not past `built` until `test.sh` — **both** cases —
passes. A container that starts and cannot find its weights looks exactly like
a working one until someone submits real work.

## What was verified, and what was taken on trust

Verified against upstream on 2026-09-24:

- the v1/v2 licence split, quoted above from upstream's README;
- the model table, including `protenix-v2` being the proprietary row;
- `covalent_bonds` field names, the 1-based entity indexing into `sequences`,
  and both SMILES atom spellings (0-based index, or element + 1-based ordinal)
  — upstream `docs/infer_json_format.md`;
- `pairedMsaPath` / `unpairedMsaPath` and the absolute-path recommendation —
  same document;
- installation is `pip install protenix`; inference is
  `protenix pred -i in.json -o out -n <model>`.

**Not** verified, and marked as such in the files that depend on it:

- `PROTENIX_ROOT_DIR` (checkpoints under `$ROOT/checkpoint`, CCD under
  `$ROOT/common`) and `PROTENIX_DATA_ROOT_DIR` come from upstream's training
  documentation read at second hand, not from a running image. If
  `fetch-weights.sh` downloads into `$HOME` instead, that is why, and
  `tool_exports` in `tool.conf` is what to fix.
- the exact `sequences` entry keys (`proteinChain`, `ligand`) used in
  `test.sh` and `fetch-weights.sh`;
- whether `covalent_bonds` sits at the job level or the file level;
- what `positionN` means on the ligand side of a bond when the ligand is a
  single SMILES residue;
- whether Protenix will fold at all with no MSA supplied;
- the output format and the ligand atom naming in it — `test.sh` parses both
  mmCIF and PDB and asserts on geometry rather than names for this reason;
- whether anything in the dependency chain JIT-compiles, which is why the
  compiler is insurance rather than a fix.

## Templates: reachable, and admissible once one literal became a key

Measured 2026-09-24 by calling this image's own `TemplateHitFeaturizer`, not by
reading documentation. The tool has everything needed: a per-chain
`templatesPath` on the `proteinChain` object, a `--use_template` flag whose help
text says *"requires templatesPath in input JSON"*, and a parser for both
hmmsearch a3m and hhsearch hhr hits.

`protenix_1.sif` could reach all of that and never use a template, for three
independent reasons. `protenix_2.sif` — the image this entry now ships — fixes
all three.

### 1. No kalign, and Ubuntu has no package for it

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

### 2. The date cutoff was unreachable, and that was a bug, not a policy

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

### 4. The release-date cache is a MEMBERSHIP gate, and it fires first

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

**The shared weights root does not have this file.** `fetch-weights.sh` asserts
both template dependencies and would fail without them, but it has not been
re-run since that assertion was added, so
`/mnt/fac/CX500146_DS1/data/protenix/common/` holds the CCD and nothing else and
`mmcif/` is empty. Re-running it is the fix for the general case.

**It would still not be enough for a post-cutoff template, and that is the
point.** Whatever snapshot upstream's cache was built from, it is a v1-era
artifact and a set worth showing this model is by construction newer than the
model. So the dates for the entries actually used have to be supplied, and the
only honest source for them is the deposited entry: this campaign's
`release_dates.py` reads `_pdbx_audit_revision_history` out of the same mmCIF
the fold will read, selecting the `Structure model` revision 1.0 row, and
refuses if the date disagrees with what the template set declares. Taking the
first row of that loop without selecting on content type and revision yields the
**deposition** date — 8UDR deposited 2023-09-28, released 2024-10-16 — which is
the wrong number by thirteen months in the direction that makes a post-cutoff
structure look admissible under a tighter cutoff.

Build the overlay root rather than writing four entries into the shared one: a
four-entry cache is not a PDB release-date cache, and left where the next
campaign inherits it, every hit outside those four becomes `date unknown`.

### 3. `fetch_remote` defaults true, and compute nodes have no internet

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

### Two gates that survive on purpose

Both are warnings under the default `strict_error_check=False`, so both drop the
template and let the fold exit zero:

- a hit whose ungapped sequence is a substring of the query **and** covers more
  than 95% of it is a `DuplicateError` — the tool declining to template a
  structure with itself. So a target's own reference entry cannot template it;
- a hit under ten residues is a `LengthError`, so a peptide chain cannot be
  templated at all.

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

The reason is the duplicate gate two sections up, not a defect in this image.
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
