# Foldseek

| | |
|---|---|
| Built | 2026-09-17, kanderson6, CoreHPC login node (86 s) |
| Image | `foldseek_10.sif`, 46 MB |
| Recipe | [`foldseek_10.def`](foldseek_10.def) |
| Upstream | release `10-941cd33`, prebuilt `foldseek-linux-avx2` |
| Base | `debian:12-slim` |
| Licence | GPL-3.0 |
| GPU | no |

## What the test proves

`chpc-tool test foldseek`: generates a 60-residue mixed-topology backbone and
searches it against itself, asserting identity 1.000 over 60 residues
(E = 1.06e-09). Exercises PDB parsing, 3Di conversion, structural alignment and
output conversion.

## Traps

- **The test passes `--exhaustive-search 1`, and that is not a workaround.**
  Foldseek's prefilter scores a *combined* amino-acid + 3Di k-mer against a
  threshold tuned for real structural databases. A generated fold is too regular
  to clear it — a pure helix reduces to the 3Di string `DVVV…VVVD`, and
  poly-alanine is equally degenerate in the sequence half — so the query fails to
  match **itself** and reports `0 sequences passed prefiltering`. That reads as a
  broken tool and is a synthetic fixture meeting a heuristic. Testing the
  prefilter honestly needs a real database.
- Databases are not in the image and are the expensive part. `foldseek databases
  PDB $CHPC_LAB/data/foldseek tmp` on the **login node**; check the share has room
  first — FAC is 5 TB for the whole lab.
