# Covalent bonds in the co-folding tools

Five entries in this registry can be asked to fold a ligand bonded to a
polymer: `boltz`, `chai1`, `protenix`, `intellifold` and, on paper,
`alphafold3`. `openfold3` accepts the field and ignores it. Each tool addresses
a bond in a different vocabulary, and every one of them returns a plausible
structure when the address is wrong. This page tells that story once; the
per-tool READMEs point here.

A sixth, `rfdiffusion3`, **cannot be told about a bond at all** — it reads the
bonds already in the input file and infers the modification. It is a design tool
rather than a predictor, so it appears in the table below with a row of its own;
the failure mode is the same shape and arrives by a different route.

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
| intellifold | AlphaFold 3 schema `bondedAtomPairs` | `[entity_id, residue_id, atom_name]`, `entity_id` a label | atom name from a CCD code or a `userCCD` block; a SMILES ligand has no atom names to bond | measured: `userCCD` and `bondedAtomPairs` are both honoured, and a bond it accepts can still be built wrong, so check the geometry |
| alphafold3 | `bondedAtomPairs` (not built here) | as intellifold | as intellifold; `userCCD` for anything you only have as SMILES | polymer-to-polymer bonds are unsupported outright |
| openfold3 | `covalent_bonds` in its own query JSON | declared | declared | the field is loaded and never used: apo folds only |
| rfdiffusion3 | **nowhere — there is no field.** `FlagAndReassignCovalentModifications` runs unconditionally and reads the parser's BondList | whichever residue the file says is bonded; the whole residue is reassigned into the ligand's PN unit and atomized | whichever ligand atom the file says, by the bond record | a structure missing its `_struct_conn` record becomes a FREE ligand near a cysteine. Nothing is declared, so nothing can be wrong, so nothing warns. Measured on 8UDR: the deposited C/CYS6/SG–F/MOV/C25 bond at 1.765 Å is picked up unaided, and survives a 120-residue de novo design at 1.770 Å |

## Rules

1. Assert geometry with the checker above. Never `_struct_conn`, never a
   confidence score, never "the run finished".
2. Name atoms. Never pass an integer where a tool also accepts a name.
3. Confirm the tool's polymer-side numbering before writing a bond, and map
   back to the project's numbering explicitly afterwards.
4. Every covalent `test.sh` in this registry folds a one-cysteine peptide bonded
   to a Michael acceptor and runs this checker on the result. A new
   covalent-capable entry gets the same case.
