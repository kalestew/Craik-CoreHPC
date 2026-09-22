# AlphaFold 3

| | |
|---|---|
| Status | **planned** — weights staged, image not built |
| Weights | `af3.bin.zst`, 974 MB, on FAC at `$CHPC_REFDATA/alphafold3` |
| Verified | 2026-09-21 — sha256 matches the manifest; nothing has been *run* |
| Databases | **not fetched** — hundreds of GB, and the real blocker |
| Upstream | <https://github.com/google-deepmind/alphafold3> |
| Licence | code Apache-2.0; **parameters non-commercial, by request** |
| GPU | yes |

## What is done, and what is not

The model parameters are on the share and verified against their sha256. That
is the whole of it. There is **no image**, and inference will not run.

The parameters are the small half. AF3 needs genetic databases — BFD, MGnify,
UniRef90, UniProt, PDB seqres and the RNA sets — which upstream fetches with
`fetch_databases.sh` and which run to **hundreds of gigabytes**, two orders of
magnitude larger than the weights. They are deliberately not in `assets.tsv`:
a manifest is a shopping list for files a person carries, and these are not
that. Fetch them on the login node (compute nodes have no internet) into
`$CHPC_REFDATA/alphafold3/databases`, which is where `AF3_DATABASES` points.

Budget the share before starting: `/mnt/fac/CX500146_DS1` had 4.9 TB free at
the time of writing, so the databases fit, but they are not a small decision.

## Read this before using it for anything

Three findings, all recorded in this lab's own planning documents, and none of
them a matter of opinion:

**AF3 forbids arbitrary covalent bonds.** It cannot build a
tetrahedral-intermediate or acyl-enzyme state. PLACER was chosen over it for
precisely this — `--bonds` takes an arbitrary covalent bond, `--residue_json`
a custom tetrahedral residue. If the question involves covalent chemistry, AF3
is the wrong tool and no amount of database is going to fix that.

**Co-folding models barely respond to point mutations.** Mutating *every*
binding-site residue to glycine left more than half of AF3's correct poses
unchanged (Masters et al., *Nat Commun* 2025). That disqualifies it as a
variant-ranking oracle, which is the use it most invites.

**On protein–peptide complexes with no binding-site match in training, none of
AF3, Boltz-1 or Chai-1 produced atomically accurate structures** (Guan &
Keating, *Protein Sci* 2025).

## The licence restricts the outputs, not just the file

The Model Parameters Terms of Use are non-commercial, and the restriction
attaches to **structures produced with them**, not only to the weights. For a
therapeutic programme that outlives the run by years: a structure that enters
a filing or a partnership is the part that matters, not the copy of
`af3.bin.zst`. If AF3-derived coordinates are ever used here, record where they
came from, because the provenance is the thing that will be asked about later.

Boltz-2 (MIT) and Chai-1 (Apache-2.0) carry no such restriction on their
outputs and are both built and verified in this registry.

## When someone builds the image

Start from `nvcr.io/nvidia/pytorch` as the other GPU images do, follow
upstream's Dockerfile, and keep the weights and databases **outside** the
image and on FAC — a weights refresh should not force a rebuild, and a
hundreds-of-GB image is not a thing. `APPTAINER_BIND` from `chpc.env` already
exposes `/mnt/fac` inside every container.

Do not flip `STATUS` past `planned` until `chpc-tool exec alphafold3` has run a
real inference. A container that starts and cannot find a database looks
exactly like a working one right up until someone submits real work.
