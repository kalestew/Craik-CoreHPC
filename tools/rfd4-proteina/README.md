# rfd4-proteina

RFD4-Proteina: the IPD/NVIDIA all-atom flow model that co-designs sequence and
structure, released 2026-10-19 under BSD-3-Clause. Antibody and TCR CDR redesign
on a fixed framework against an optional fixed antigen, with ligands and
covalent polymer-ligand bonds in the representation.

Staged for the Hap108or haptenated-pMHC campaign. **`STATUS=verified`** as of
2026-11-18: the cu13 image is fetched and digest-verified, the 1.7 GB bundle is
staged with its sha256 sidecars, and all five stages of `test.sh` pass on an
RTX 5090 — including a real 60-step generation from the local bundle with the
network off, which brought the sotorasib adduct back on the peptide cysteine by
its warhead atom at 1.591 Å against the deposited 1.765. Every item below
carries its date and its method.

## Licence: BSD-3-Clause, weights included, not gated

Checked 2026-11-16 from the Hugging Face model card and the model API.

This was an open question worth asking rather than assuming, because the
standalone Proteina weights in the same model family are **NVIDIA Open Model
License** via NGC, not BSD. Had RFD4's weights been gated or separately
licensed, they would have had to come through `assets.tsv` and `chpc-assets`
rather than through `fetch-weights.sh`.

They are not. The card's frontmatter is `license: bsd-3-clause`, its licence
section says "The BSD 3-Clause license covers the RFD4-Proteina model, weights
and code only", and `GET /api/models/nvidia/RFD4-Proteina` reports
`gated: False`.

The qualifier matters and is the reason for the "only" in that sentence: the
same repository bundles **optional** AlphaFold2 and OpenFold3 refolding images
whose own terms "restrict commercial use or redistribution". This entry stages
none of them, and `ENTRY` is deliberately `rfd4-generate` rather than
`rfd4-evaluate` so that the oracle path cannot be reached by accident. See
`tool.conf`'s `NOTE`.

## Two upstream revisions, because one pin cannot express this

| What | Revision | Digest |
|---|---|---|
| Weights (`config.json`, `model.safetensors`) | `a06e2509c7033b010fc43614e9fd840303588502` | `5b549dd61adb2f6c6b5cb95bda13f40f5e31556b4e6c755edc0ca6f011c68fb0` |
| Image (`runtime/rfd4-proteina-cu13-amd64.sif`) | `5ec66c399bf0b48727ab24e6b298dcf33864fa07` | `058a27dff02778cd7304cf8955c73115f6baaa4dfc0202540c73a10a403fa957` |

The weights revision is the one the tool's **own** config declares
(`configs/inference.yaml:hf_ckpt_revision`), which upstream calls the source of
truth for the model. The `runtime/` directory holding the `.sif` images **did
not exist at that commit** — every path under it 404s there — so the image is
pinned at the repo revision that carries it.

Verified 2026-11-16 that this is two pins rather than a mismatch:
`config.json` and `model.safetensors` are **byte-identical at both revisions**
(LFS oid `5b549dd6…`, which is also `release-checkpoints.json`'s own
`bundle_sha256`). Upstream warns that the flow model and autoencoder "must be
used together" and are not interchangeable with the previous release's, so this
is the check that mattered.

`DIGEST=` in `tool.conf` is a first for this registry: upstream publishes a
`.sha256` sidecar beside each image, so the digest is a fact about the
*published artifact* rather than about one host's copy. That removes the
objection that left the consuming project's ADR 0027 Part 3 open — a coordinator
does not have to hash a multi-gigabyte `.sif` sitting on FAC to know what it is.
`fetch-weights.sh` verifies it at download and refuses on mismatch.

## The composition question, answered 2026-11-16

The consuming project's ADR 0026 names exactly one claim that no primary source
states:

> Whether a CDR redesign condition and a covalent hapten condition compose in a
> *single* run is undocumented. Upstream covers the two modes separately and
> never together. […] It is the first thing to test, before any staging work.

**They compose.** Measured on the CPU image
(`rfd4_proteina_0.0.3_cpu.sif`, sha256 `e42edc28…`, 817 MB) with no GPU, no
weights and no network, over a real input: PDB 8UDR, the P1B7 Fab on the
sotorasib-modified KRAS G12C peptide presented by HLA-A\*03:01, cropped to
Fv + pMHC + hapten.

```
bond: C/CYS6/SG -- F/MOV301/C25 type=1 d=1.765A
OK all 41 hapten atoms are coordinate-conditioned
OK all 324 designed CDR atoms are sequence-FREE
OK all 3120 framework/other-CDR atoms are sequence-conditioned
```

1.765 Å is the deposited bond length, unchanged.

**`test.sh` stage 2 *is* this check, and it has been run from the file** —
2026-11-17, same CPU image, extracted verbatim and executed against
`examples/p1b7/reference/8UDR.cif.gz` and `manifest.json`:

```
  cropped 12740 -> 9489 atoms (dropped 205 non-finite inside the crop)
  annotated CIF: 41 ligand atoms, 0 non-finite
  OK chain E 1-110 == manifest light chain; 89-99 == 'SSHRTGYTVEV'
  OK chain D 1-123 == manifest heavy chain; 101-112 == 'EGVTMGPGAFDI'
  bond: C/CYS6/SG -- F/MOV301/C25 type=1 d=1.765A
  OK all 41 hapten atoms are coordinate-conditioned
  OK all 324 designed CDR atoms are sequence-FREE
  OK all 3120 framework/other-CDR atoms are conditioned
  OK C_INTCRD refused by name: ValueError
```

It is the one stage that runs without a GPU, and
`RFD4_TEST_CPU_ONLY=1 chpc-tool test rfd4-proteina` runs stages 0 and 2 alone.
That mode exits 0 and prints `PARTIAL`, because it has generated nothing: it is
deliberately not evidence for `STATUS=verified`.

Three assertions were added over the original probe, each closing a way it
could have passed while being wrong. The CDR3 spans are **checksummed against
`manifest.json`'s own Fab sequences** rather than taken on trust — an earlier
hand calculation using VL=109 put all four heavy-chain loops one residue high,
and nothing about the resulting run would have looked wrong. The ligand atom
count is asserted against the manifest's `heavy_atoms` rather than against the
literal 41. And `C_INTCRD` is asserted to be **refused**, so the one condition
upstream will not accept cannot be written by accident.

### Five things the test had to get right, each of which failed first

Recorded because every one of them is a silent failure rather than an error, and
because a renderer for this tool has to handle all five.

1. **`input_as_annotated_cif` must be `true`.** With `false` the `RCSB_WITH_METALS`
   preset applies `add_missing_atoms=True`, which re-adds **31 hydrogens with NaN
   coordinates to the hapten** — 72 ligand atoms instead of 41, and 209
   non-finite atoms overall. `ANNOTATED_CIF` keeps the authored heavy atoms:
   41 ligand atoms, zero non-finite. Measured both ways on the same file.
2. **A coordinate group may not span the designed region.** `C_CRDGRP` is
   internal-coordinate conditioning and
   `conditioning_utils.py:materialize_internal_coords` requires each group's
   live coordinates to be *entirely finite*; the designed CDR has none. A group
   covering a free CDR fails with "Coordinate group 2 needs finite live
   coordinates to materialize its targets", which names neither the CDR nor the
   cause.
3. **The input must carry no non-finite coordinates in any conditioned group,**
   which deposited structures routinely do. 8UDR has unresolved backbone at
   heavy-chain 141–145 and 223–226 (CH1 loops, outside the Fv) and single
   non-finite atoms at every chain terminus. Cropping to Fv + target + hapten
   and dropping non-finite atoms is the fix, and it is the renderer's job.
4. **`C_SEQ`'s free value is the string `'<M>'`.** It is a residue-level `str`
   annotation whose `default_value` is that mask token — not `False`, not `""`,
   not absence. A test asserting "unconditioned" as falsiness reports every
   designed residue as conditioned and passes nothing.
5. **The built annotation names are not the condition aliases.** The spec is
   written with `C_SEQ`, `C_CRD`, `C_CRDGRP`; the built array carries
   `condition_sequence_1_residue`, `condition_coordinate_1_atom`,
   `condition_CoordinateGroup_1_atom`. `C_INTCRD` is never writable at all —
   `condition_spec.py:378` refuses it by name ("a saved payload; edit C_CRDGRP
   instead").

`build_annotated_atom_array_from_condition_spec` returns a dict with keys
`atom_array`, `chain_info`, `ligand_info`, `metadata`.

### Chain and residue correspondence, verified by checksum

For 8UDR as atomworks parses it (label asym ids):

| chain | role | residues |
|---|---|---|
| A | MHC α | 1–275 |
| B | β2m | 1–99 |
| C | peptide (KRAS G12C, CYS6 bears the adduct) | 1–10 |
| D | Fab heavy | 1–226; **1–123 == P1B7 `vh_seq`** |
| E | Fab light | 1–213; **1–110 == P1B7 `vl_seq`** |
| F | sotorasib (CCD `MOV`) | 301, 41 heavy atoms |

The `vh_seq`/`vl_seq` equalities are asserted, not assumed, and they fix the
CDR mapping: this project's flat zero-based CDR offsets into `vl_seq + vh_seq`
(VL 110, VH 123, total 233) resolve to `CDR3A → E 89–99` (`SSHRTGYTVEV`) and
`CDR3B → D 101–112` (`EGVTMGPGAFDI`), both confirmed against the structure's own
residues. An earlier hand calculation using VL=109 put the four heavy-chain
loops one residue high.

## No CCD mirror, and a partial one is worse than none

Corrected 2026-11-17. This entry's first draft exported `CCD_MIRROR_PATH`, its
`tool_doctor` *required* the directory to exist, and `fetch-weights.sh --ccd`
was to create it. All three were wrong in the same way.

atomworks 3.0.4 treats a configured mirror as the **only** source of components
and disables its biotite fallback entirely — `ccd.py:204` "Local mirror
configured — use ONLY mirror codes" and `ccd.py:645` "use ONLY mirror, no
biotite fallback". Measured inside this image with a mirror holding exactly
`M/MOV/MOV.cif` in the documented `<letter>/<CODE>/<CODE>.cif` layout:

| | standard CCD codes | `ALA` | `MOV` |
|---|---|---|---|
| no mirror | 49,195 | loads (13 atoms) | loads (73 atoms) |
| MOV-only mirror | **1** | **raises `ValueError`** | loads (73 atoms) |

So a partial mirror trades every amino acid for one ligand that was already
there. `ALLOW_BIOTITE_CCD` defaults true, biotite 1.6.0's bundled CCD carries
MOV, and the composition check above passed with no mirror set.

The entry therefore exports no `CCD_MIRROR_PATH`, `tool_doctor` **fails** if it
finds a `ccd/` directory, and `--ccd` refuses with the reason. The doctor check
is inverted rather than deleted because the variable is one edit away from
being live again and the old instruction may outlive this file in somebody's
notes.

The cost, stated rather than hidden: the fallback is biotite's *bundled* CCD, so
which dictionary resolves a component is pinned by the biotite inside the image
rather than by this registry. That is a real argument for mirroring the CCD
**completely** later — ~49k components — and until somebody does, `VERSION` and
`DIGEST` are what make a change in it visible at all.

Note where MOV's 73 atoms go: 41 heavy plus 32 hydrogens, which is where
finding 1's "31 NaN hydrogens" come from. `add_missing_atoms` re-adds them off
this template, one short because the covalent bond consumes it.

## Measured on the GPU, 2026-11-18

Everything in this section was open until the image ran. RTX 5090 (sm_120),
driver 595.99.02, Apptainer 1.4.5, torch 2.14.1+cu130 against CUDA 13.0.

- **`GPU_MAX_CC=12.0`**, from `torch._C._cuda_getArchFlags()` inside the image:
  `sm_75 sm_80 sm_86 sm_90 sm_100 sm_120`. The cu13 wheel set does carry
  sm_120. `GPU_TESTED=nvidia_geforce_rtx_5090`.
- **Peak GPU memory ≈ 7.8 GB** for the campaign's full system — 10.5 GB
  sampled at 2 Hz against a 2.8 GB desktop baseline on this host. Comfortable
  against 32 GB, and upstream still states nothing.
- **86–88 s per draw**, measured over five draws of the full ~656-token system
  at 60 steps, `bf16-mixed`, eager (`compile_lengths=null`), start to published
  structure. Consistent to under two seconds.
- **The model honours both conditions.** The hapten came back on the declared
  cysteine by its warhead atom in every draw: 1.591 Å on the test crop with
  torch.compile buckets, and 1.182 / 1.168 / 1.213 Å on the campaign's own
  input with compilation off. The warhead is the *closest* ligand atom to the
  sulfur in each (next nearest 2.90 Å), and the decoy sits at 14.3 Å. Sequence
  conditioning is honoured too: on a real design round every substitution fell
  inside the two CDR3 spans the request opened, 21 of them, none anywhere else.
- **The hapten's atoms do appear in the output**: 72 MOV atoms against 41 heavy
  in the input, which is the 41 plus `add_missing_atoms`' 31 hydrogens.
- **`compile_lengths` changes the numbers.** The same input at seed 1 gave a
  1.591 Å bond with upstream's bucket list and 1.166 Å with compilation
  disabled, each reproducible. Treat it as part of a run's identity, not as a
  throughput knob.
- **A resolved seed names a draw exactly.** Two runs at seed 1 produced
  byte-identical output but for `_entry.time`; seed 2 produced different CDR3
  sequences. That holds at the default `torch_deterministic: false`, and it is
  worth knowing that two identical draws still *hash* differently, because the
  tool stamps a wall-clock time into the CIF it writes.

## What is still not established

- **The bond length.** Every draw placed the adduct correctly and compressed
  the S–C distance to ~1.17–1.21 Å, against 1.765 Å in the deposited entry and
  a 1.45–2.30 Å band across the five covalent predictors this campaign drives.
  Placement is honoured; geometry is not, and whatever reads these designs has
  to treat the bond length as a flag rather than as a measurement of chemistry.
- **Anything about a device other than this one.** `GPU_TESTED` names one class
  and anything else is unevidenced.

## Staging

```sh
# login node, once
tools/rfd4-proteina/fetch-weights.sh --image    # the cu13 .sif, digest-verified
tools/rfd4-proteina/fetch-weights.sh            # bundle + digests + 8UDR fixture
chpc-tool doctor rfd4-proteina
chpc-tool doctor --deep rfd4-proteina           # re-hashes the image; minutes
chpc-tool test rfd4-proteina                    # needs a GPU for stages 3 and 4
```

`fetch-weights.sh` fetches **exactly two files** — `config.json` and
`model.safetensors`, named positionally, which is what
`load_pretrained_bundle`'s `allow_patterns` amounts to. Pulling the whole repo
would also stage the `.ckpt` files this entry has decided not to use, giving a
second route to the same weights under different provenance, and it would bring
the AlphaFold2/OpenFold3 refolding assets whose terms restrict commercial use.
Do not widen that list casually.

Two things about the default mode worth knowing before it fails:

- It overrides `HF_HUB_OFFLINE=0` **on the download command only**. The entry
  exports `HF_HUB_OFFLINE=1` so that a misresolved bundle path on a compute node
  fails in seconds rather than hanging, and `chpc-tool exec` puts that into the
  container unconditionally — so without the override the one command that is
  supposed to reach the network is refused by the variable that exists to make
  every other command refuse.
- `--image` uses `curl`, not `hf`, because `hf` lives inside the image and
  fetching the image from inside itself is circular. It verifies against
  `tool.conf`'s `DIGEST` and moves a mismatch aside as `.rejected` rather than
  deleting it or refetching blind.

The CPU image is enough for stages 0 and 2 and is 817 MB against the cu13
image's 4.04 GB; it is the right thing to fetch first when all you need is to
validate an input.
