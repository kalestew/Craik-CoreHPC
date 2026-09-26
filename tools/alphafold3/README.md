# AlphaFold 3

| | |
|---|---|
| Status | planned — weights staged (974 MB, sha256 verified 2026-09-21), no image, no databases |
| Image to be | `alphafold3_3.sif`; no recipe in this directory yet |
| GPU | yes. Which `--gres` to ask for is settled when the image exists and its arch flags are measured ([`../README.md`](../README.md#which-gpu)) |
| Weights | `af3.bin.zst`, 974 MB at `$AF3_WEIGHTS` (`$CHPC_LAB/data/alphafold3`), installed from [`assets.tsv`](assets.tsv) by `chpc-assets`. Genetic databases at `$AF3_DATABASES` (`$CHPC_LAB/data/alphafold3/databases`): **not fetched** |
| Licence | code Apache-2.0; parameters non-commercial, obtained by request from Google DeepMind — and the restriction reaches the structures, not just the file |
| Upstream | <https://github.com/google-deepmind/alphafold3>, no pin yet |

## Not built yet

The model parameters are on the share and verified against their sha256. That
is the whole of it: there is **no image**, and inference will not run.

**The blocker is not the image.** The parameters are the small half. AF3 needs
genetic databases — BFD, MGnify, UniRef90, UniProt, PDB seqres and the RNA sets
— which upstream fetches with `fetch_databases.sh` and which run to **hundreds
of gigabytes**, two orders of magnitude larger than the weights.

**Use instead today**, all of them built here, and none of them restricting what
may be done with the structures: [`../boltz`](../boltz) (MIT),
[`../chai1`](../chai1) (Apache-2.0), [`../protenix`](../protenix) and
[`../intellifold`](../intellifold) (Apache-2.0).

To build it:

1. Fetch the databases on the login node — compute nodes have no internet —
   into `$CHPC_LAB/data/alphafold3/databases`, which is where `AF3_DATABASES`
   points. Budget the share first.
2. Write `alphafold3_3.def` from upstream's Dockerfile on an
   `nvcr.io/nvidia/pytorch` base, as the other GPU images here do, and keep the
   weights and the databases outside the image.
3. `chpc-assets install alphafold3` if the parameters are not already on the
   share; `chpc-tool doctor alphafold3` reports weights and databases
   separately, because weights-without-databases is the state this entry is
   expected to sit in for a while.
4. Measure the image's arch flags and set `GPU_MAX_CC` before anyone submits a
   job.
5. Do not flip `STATUS` past `planned` until `chpc-tool exec alphafold3 -- ...`
   has run a real inference. A container that starts and cannot find a database
   looks exactly like a working one right up until someone submits real work.

Build and publish: [`../README.md`, Add a tool](../README.md#add-a-tool).

## Do not miss

- **The parameters licence restricts the outputs, not just the file.** The
  Model Parameters Terms of Use are non-commercial, and the restriction
  attaches to structures produced with them. If AF3-derived coordinates are
  ever used here, record where they came from.
- **No covalent bond between or within polymer entities.** AF3 cannot build a
  tetrahedral-intermediate or acyl-enzyme state; `../placer` is the tool for
  that. Ligand-to-polymer bonds *are* supported, through `bondedAtomPairs`,
  which is the haptenated-residue case — do not read the first sentence as
  ruling that out.
- **A `smiles` ligand cannot carry a bond.** There is no atom name to bond to.
  Bring it as a registered CCD code or as a `userCCD` block, whose atom names
  you assign yourself.
- **Every predictor addresses a bond in a different vocabulary**, and each one
  folds happily when the address is wrong:
  [`../covalent-bonds.md`](../covalent-bonds.md).
- **Not a variant-ranking oracle.** Co-folding models barely respond to point
  mutations; the evidence is in Traps.

---

## Provenance

Nothing has been built and nothing has been run.

Verified 2026-09-21: `af3.bin.zst` on the share matches the sha256 recorded in
[`assets.tsv`](assets.tsv). Nothing else about this entry has been tested,
because there is nothing to test it with.

There is no `test.sh` yet. When one is written it has to run a real inference
rather than a start-up check, for the reason in step 5 above: the interesting
failure is a container that launches, finds no database and says so in a log
nobody reads.

### The licence restricts the outputs, not just the file

The Model Parameters Terms of Use are non-commercial, and the restriction
attaches to **structures produced with them**, not only to the weights. For a
therapeutic programme that outlives the run by years: a structure that enters
a filing or a partnership is the part that matters, not the copy of
`af3.bin.zst`. If AF3-derived coordinates are ever used here, record where they
came from, because the provenance is the thing that will be asked about later.

## Build notes

Nothing is built, so these are decisions rather than history.

Two separate payloads, and conflating them is the easy mistake: the model
parameters are ~1 GB and are carried in `assets.tsv`; the genetic databases are
hundreds of GB and are deliberately *not* listed there. A manifest is a shopping
list for files a person carries, and these are not that.

Budget the share before starting: `/mnt/fac/CX500146_DS1` had 4.9 TB free at the
time of writing, so the databases fit, but they are not a small decision.

Keep the weights and databases **outside** the image and on FAC — a weights
refresh should not force a rebuild, and a hundreds-of-GB image is not a thing.
`APPTAINER_BIND` from `chpc.env` already exposes `/mnt/fac` inside every
container.

## Traps

Four findings, all recorded in this lab's own planning documents, and none of
them a matter of opinion:

**AF3 forbids covalent bonds between or within polymer entities.** It cannot
build a tetrahedral-intermediate or acyl-enzyme state. PLACER was chosen over it
for precisely this — `--bonds` takes an arbitrary covalent bond, `--residue_json`
a custom tetrahedral residue.

This paragraph used to say "arbitrary covalent bonds" and stop there, which is
how it was first written, for the cathepsin G work where every bond of interest
was enzyme-to-substrate. Copied into a project whose bond is a peptide cysteine
to a small molecule, it says the opposite of the truth and steers you off the
one tool family that handles that case cleanly. Upstream `docs/input.md` is
narrow and explicit: *"Defining covalent bonds between or within polymer
entities is not currently supported."* Ligand-to-polymer bonds are supported,
through `bondedAtomPairs`, addressed as `[entity_id, residue_id, atom_name]`.

**A `smiles` ligand cannot carry a bond, and the fix is `userCCD`.** Upstream:
*"This also explains why SMILES ligands don't support bonds: there is no atom
name that could be used to define the bond. This shortcoming can be addressed by
using the user-provided CCD format."* So there are two routes to a bonded custom
ligand, not one:

| Route | How | When |
|---|---|---|
| Registered CCD | `ligand.ccdCodes: ["MOV"]` | the adduct is in the wwPDB CCD |
| `userCCD` | top-level `userCCD` (or `userCCDPath`) mmCIF string, referenced by `ligand.ccdCodes: ["LIG-1"]` | anything else, including anything you have only as SMILES |

A `userCCD` block needs `_chem_comp` identity fields, `_chem_comp_atom` with
`type_symbol`, `charge` and ideal coordinates, and `_chem_comp_bond` with
`value_order` and the aromatic flag. Upstream names no converter, so generating
one from SMILES is ours to write and to test.

Prefer `userCCD` over the registered code when both exist. The atom names in a
`userCCD` are **assigned by whoever writes the block**, which is the whole
problem solved at the root: the bond endpoint stops being a name inherited from
a registry that a second vocabulary happens to reuse.

**Co-folding models barely respond to point mutations.** Mutating *every*
binding-site residue to glycine left more than half of AF3's correct poses
unchanged (Masters et al., *Nat Commun* 2025). That disqualifies it as a
variant-ranking oracle, which is the use it most invites.

**On protein–peptide complexes with no binding-site match in training, none of
AF3, Boltz-1 or Chai-1 produced atomically accurate structures** (Guan &
Keating, *Protein Sci* 2025).
