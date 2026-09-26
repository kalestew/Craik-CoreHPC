# Foldseek

| | |
|---|---|
| Status | verified — `chpc-tool test foldseek` passed (self-hit identity 1.000 over 60 residues, E = 1.06e-09); the date and node of that run are not recorded in this entry |
| Image | `foldseek_10.sif`, 46 MB; recipe [`foldseek_10.def`](foldseek_10.def) |
| GPU | CPU (`salloc -p cpu`) |
| Weights | none. Databases belong under `$CHPC_LAB/data/foldseek`; **none is installed yet** |
| Licence | GPL-3.0 |
| Upstream | release `10-941cd33`, prebuilt `foldseek-linux-avx2` |
| Base | `debian:12-slim` |
| Built | 2026-09-17, kanderson6, CoreHPC login node (86 s) |

## Run it

```bash
salloc -p cpu -c 8 --mem 16G -t 2:00:00
mkdir -p /mnt/scratch/user/$USER/foldseek/run1 && cd "$_"   # query.pdb here; the same path is valid inside the container
chpc-tool exec foldseek -- foldseek easy-search query.pdb "$CHPC_LAB/data/foldseek/<db>" res.m8 tmp --threads "$SLURM_CPUS_PER_TASK"   # (untested: no database is installed yet)
```

The program and its arguments are what `test.sh` runs; the database path is
where one will live once someone builds it (Do not miss). As a job: copy
`templates/slurm/tool-gpu.sbatch`, switch it to `--partition=cpu` and drop
the `--gres` and `nvidia-smi` lines as its header says, and set the tool, the
work directory and the command after `--` to the values above. The method,
the `eval` idiom and the CPU form: [`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

The query is one PDB or mmCIF file, or a directory of them. Backbone atoms are
enough: the self-test's fixture is a generated 60-residue backbone from
[`../_template/make_test_pdb.sh`](../_template/make_test_pdb.sh) with only
N/CA/C/O per residue. The target is a Foldseek database prefix (the files
`<db>`, `<db>_ss`, `<db>_ca`, ...), which `foldseek databases` or
`foldseek createdb` writes.

Output is `res.m8`, tab-separated, one hit per line, in the default
`convertalis` format: query, target, `fident` (column 3), alignment length
(column 4), mismatches, gap opens, query start/end, target start/end, E-value
(column 11), bit score. `test.sh` reads columns 3, 4 and 11 of the first line.
Hits are listed per query, best first (untested against a real database). The
`tmp` directory is Foldseek's own scratch and is safe to delete afterwards.

Before trusting a number: `fident` is sequence identity over the aligned
region, not structural similarity; for a structure-level ranking add
`--format-output` with `alntmscore` or `lddt` to the columns (untested). The
E-value depends on the database size, so a hit against a tiny custom database
is not comparable to one against the PDB.

## Do not miss

- **No database is installed.** Nothing under `$CHPC_LAB/data/foldseek` yet,
  so the first real search waits on someone building one on the **login
  node**, the only node with internet
  ([`docs/02`](../../docs/02-storage-and-data.md#internet-access)):
  `chpc-tool exec foldseek -- foldseek databases PDB "$CHPC_LAB/data/foldseek/pdb" tmp`
  (untested), after checking the share has room. Point `easy-search` at that
  prefix.
- **`--exhaustive-search 1` is not a production flag.** `test.sh` passes it
  because a synthetic 60-residue fixture cannot clear the prefilter; against a
  real database it disables the prefilter and aligns everything. Leave it out.
- **`--threads` is what Slurm gave you.** Pass `"$SLURM_CPUS_PER_TASK"`; the
  default is whatever the node reports, not your allocation.

---

## Provenance

Built 2026-09-17 by kanderson6 on the CoreHPC login node (86 s).

`chpc-tool test foldseek`: generates a 60-residue mixed-topology backbone and
searches it against itself, asserting identity 1.000 over 60 residues
(E = 1.06e-09). Exercises PDB parsing, 3Di conversion, structural alignment and
output conversion. The date and node of the passing run were not recorded in
this entry; whoever next runs it on a compute node should add them to the
Status row.

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
