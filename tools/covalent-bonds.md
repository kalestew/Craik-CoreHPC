# Covalent bonds in the co-folding tools

Five entries in this registry can be asked to fold a ligand bonded to a
polymer: `boltz`, `chai1`, `protenix`, `intellifold` and, on paper,
`alphafold3`. Each tool addresses a bond in a different vocabulary, and every
one of them returns a plausible structure when the address is wrong. This page
tells that story once; the per-tool READMEs point here.

`openfold3` is a special case worth reading before you assume it cannot do this.
It accepts a `covalent_bonds` field and **ignores it** — measured, not inferred
— but it does fold covalent modifications, reliably, through a route no
documentation connects to bonds: a modified residue named by CCD code in
`non_canonical_residues`. That is a different capability rather than a smaller
one, and it has its own row below.

`rfdiffusion3` **cannot be told about a bond at all** — it reads the bonds
already in the input file and infers the modification. It is a design tool
rather than a predictor, so it appears in the table below with a row of its own;
the failure mode is the same shape and arrives by a different route.

## A declared bond is a proposal, not a constraint

The most expensive thing on this page is not any tool's vocabulary. It is that
**a correctly addressed bond can still be ignored by the model, on the strength
of sequence context alone.**

Measured on `intellifold`, 2026-09-27, 95 folds on one L40S. Two runs differing
by a single residue two positions from the bond:

| peptide | bond declared | draws at 1.2–2.1 Å |
|---|---|---|
| `MKTAY`**`N`**`AT`… | `ASN ND2` — `NAG C1` | **15/15**, 1.336–1.478 Å |
| `MKTAY`**`N`**`AK`… | `ASN ND2` — `NAG C1` | **0/25**, free at 6.7–10.9 Å |

`N-A-T` is an N-glycosylation sequon and `N-A-K` is not. Same JSON, same CCD
code, same atom names, same seeds, same engine. Reversing the endpoints changes
nothing (0/15), so the pair is unordered as documented and the sequon is the
whole variable.

Nothing reports the veto. The log is silent, no `_struct_conn` record appears
either way, and no confidence score moves. So "the tool accepts this bond
vocabulary" is **not** the same claim as "this bond will be built", and the
first does not license the second for a chemistry the model has not seen in that
context. Check the geometry of the system you are actually folding, not of a
fixture that resembles it.

For a first hands-on example, use the
[P1B7 / 8UDR walkthrough](../docs/11-p1b7-walkthrough.md). Its
[committed input bundle](../examples/p1b7/README.md) includes all five protein
chains, the bound-form sotorasib ligand, predictor-specific bond declarations,
and a checker for that complete complex. The one-peptide checker below is
for the registry's small self-tests; it cannot be applied unchanged to P1B7,
which has many cysteines across several chains.

## Why geometry is the only check

HA-ADAPT's entire Chai-1 corpus, 1,726 results, is quarantined. The free drug
was folded while *declared* bonded: the peptide cysteine ended up bonded to an
aromatic ring carbon at 1.68 Å instead of to the warhead carbon, which sat at
13.59 Å. Both numbers look bond-plausible to anything that only asks "is
something near the SG". ipTM moved 0.710 to 0.698 between the wrong attachment
and the right one. No confidence score, no exit status and no inspection of the
output catches this. Only the coordinates do, and only when they are asserted
against the atom that was meant.

The shared checker asserts four things, in increasing order of what they cost:
the anchor atom exists exactly once; exactly one ligand heavy atom is within
bonding distance of it; that atom is a carbon, not the amide N or the carbonyl
O; and that carbon's only heavy neighbour inside the ligand is another carbon.
The last clause separates a terminal Michael-acceptor CH2 from an N-methyl or
an internal carbon without depending on what the predictor named anything.

```bash
sh tools/_template/check_covalent_bond.sh > check_bond.py
chpc-tool exec <tool> -- python check_bond.py model.cif --anchor SG
```

Run it on every draw you intend to keep, not only the one the tool ranked
first. It assumes one polymer chain, one ligand and one anchor atom, which is
the shape of every covalent test in this registry; it is not a general
validator.

## How each tool addresses a bond

| Tool | Where the bond goes | Polymer side | Ligand side | What goes wrong |
|---|---|---|---|---|
| boltz | `constraints:` in the input YAML | 1-based offset into the sequence string you supplied; every chain is renumbered from 1 | atom name | map back to the project's numbering yourself; `--output_format pdb` keeps the bond as connectivity records |
| chai1 | `--constraint-path` CSV, comma-delimited with a header (the m8 template table beside it is tab-delimited with none) | chain letter assigned positionally from the FASTA (entity 1 is `A`), 1-based residue, `A,C6@SG` | `@C1`: element plus 1-based per-element ordinal in RDKit atom order | a wrong delimiter yields a file chai parses into zero restraints, and it folds anyway |
| protenix | `covalent_bonds` in the JSON | `entity1` is a 1-based INDEX into the `sequences` list, not a label; `position1` 1-based; `atom1` a name | `atom2` as a name (`C1`, `N2`: element plus 1-based per-element ordinal); an integer is resolved by RDKit atom-map number when the SMILES carries `[C:7]` maps and by 0-based index when it does not | reorder `sequences` and every bond silently points elsewhere; pass names, never integers |
| intellifold | AlphaFold 3 schema `bondedAtomPairs` | `[entity_id, residue_id, atom_name]`, `entity_id` a label | atom name from a CCD code or a `userCCD` block; a SMILES ligand has no atom names to bond | measured over 95 folds: both keys honoured and the bond always on the declared atom, but built LONG and only in some draws — 15/15 on a glycosylation sequon, 17/25 on sotorasib, **0/25 on the same glycosylation without the sequon**. Screen every draw |
| alphafold3 | `bondedAtomPairs` (not built here) | as intellifold | as intellifold; `userCCD` for anything you only have as SMILES | polymer-to-polymer bonds are unsupported outright |
| openfold3 | **not `covalent_bonds`** — that field is inert. The route that works is `non_canonical_residues`, `{residue_id: CCD_code}` on the polymer chain | the residue you replace; it becomes the modification | none — there is no ligand chain, the modification IS the residue, so the shared checker above does not apply | `covalent_bonds` validates and is dropped before the model: the AtomArray is byte-identical with and without it, and `Bond.atom_id` is typed `int` so it cannot name an atom anyway. The live route needs a CCD component that already contains the whole adduct, and a custom one **cannot be supplied** — `ccd_file_path` reaches only the template pipeline. Measured: `YCM` at position 6 folds `SG–CD` at 1.670–1.745 Å in 5/5 draws |
| rfdiffusion3 | **nowhere — there is no field.** `FlagAndReassignCovalentModifications` runs unconditionally and reads the parser's BondList | whichever residue the file says is bonded; the whole residue is reassigned into the ligand's PN unit and atomized | whichever ligand atom the file says, by the bond record | a structure missing its `_struct_conn` record becomes a FREE ligand near a cysteine. Nothing is declared, so nothing can be wrong, so nothing warns. Measured on 8UDR: the deposited C/CYS6/SG–F/MOV/C25 bond at 1.765 Å is picked up unaided, and survives a 120-residue de novo design at 1.770 Å |

## Rules

1. Assert geometry with the checker above. Never `_struct_conn`, never a
   confidence score, never "the run finished".
2. Name atoms. Never pass an integer where a tool also accepts a name.
3. Confirm the tool's polymer-side numbering before writing a bond, and map
   back to the project's numbering explicitly afterwards.
4. Every covalent `test.sh` in this registry folds a one-cysteine peptide bonded
   to a Michael acceptor and runs this checker on the result. A new
   covalent-capable entry gets the same case. Two entries legitimately depart
   from it and say why in their own tests: `openfold3`, whose working route has
   no ligand chain for the checker to find, and `intellifold`, which adds a
   glycosylation case because that is the only configuration whose bond is
   deterministic enough to gate on.
5. **Assert on every draw, never on `find | head -1`.** A per-draw pass rate of
   two thirds looks like a broken tool when you read one arbitrary sample, and
   like a working one when you read five. `intellifold`'s entry reported FAIL
   for two days on this exact mistake: its fixture's sample-0 was the single bad
   draw of that seed.
