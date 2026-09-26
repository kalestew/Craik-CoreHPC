# MMseqs2

| | |
|---|---|
| Status | verified 2026-09-26 on `gcpu2-33` (CPU, job 2000974): `chpc-tool test mmseqs2`, self-hit at identity 1.000, 1 s |
| Image | `mmseqs2_18.sif`, 51 MB; recipe [`mmseqs2_18.def`](mmseqs2_18.def) |
| GPU | CPU (`-p cpu`) |
| Weights | none. Databases: one directory each under `$MMSEQS2_DB_DIR` (`$CHPC_LAB/data/mmseqs2`), fetched on the login node by [`fetch-db.sh`](fetch-db.sh); `$MMSEQS2_DB_SWISSPROT` is Swiss-Prot. **None for this image as of 2026-09-26**; the 1 TB ColabFold set beside them is `colabfold_search`'s (Do not miss) |
| Licence | GPL-3.0 |
| Upstream | release `18-8cc5c`, prebuilt `mmseqs-linux-avx2` |
| Base | `debian:12-slim` |
| Built | 2026-09-17, kanderson6, CoreHPC login node (120 s) |

## Run it

```bash
salloc -p cpu -c 8 --mem 16G -t 2:00:00
mkdir -p /mnt/scratch/user/$USER/mmseqs2/run1 && cd "$_"   # q.fa and targets.fa here; the same path is valid inside the container
chpc-tool exec mmseqs2 -- mmseqs easy-search q.fa targets.fa res.m8 tmp --threads "$SLURM_CPUS_PER_TASK"
eval "$(chpc-tool export mmseqs2)"                            # $MMSEQS2_DB_SWISSPROT
chpc-tool exec mmseqs2 -- mmseqs easy-search q.fa "$MMSEQS2_DB_SWISSPROT" res.m8 tmp --threads "$SLURM_CPUS_PER_TASK"   # (untested: not fetched yet)
```

The first line is the self-test's form, which searches `q.fa` against itself
with `--threads 2`: `easy-search` takes a FASTA as the target as readily as a
prebuilt database (`--threads "$SLURM_CPUS_PER_TASK"` is untested). The second
is the form for a database; `$MMSEQS2_DB_SWISSPROT` is where `fetch-db.sh`
puts Swiss-Prot, and until someone has run that on the login node `chpc-tool
doctor mmseqs2` warns and the search dies (Do not miss).

As a job: copy `templates/slurm/tool-gpu.sbatch` with `--partition=cpu` and no
`--gres` (drop its `nvidia-smi` line too), and set the other EDIT lines to the
values above. The method and the `eval` idiom:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

A FASTA of queries and a FASTA (or database) of targets; the self-test's is
one 78-residue record, searched against itself:

```
>q
MKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQAPILSRVGDGTQDNLSGAEKAVQVKVKALPDAQFEVVHSLAKWKR
```

Output is `res.m8`, BLAST tab-separated, one hit per line: query, target,
identity as a fraction (column 3, what the self-test reads: `1.000` for the
self-hit), then alignment length, mismatches, gap opens, query and target
start/end, E-value and bit score (MMseqs2's default column set, not checked
here). Hits are grouped per query in MMseqs2's own order (untested). `tmp/` is
the working directory and can be deleted afterwards. Before trusting an
absence: a sequence missing from `res.m8` may have been dropped by the
prefilter rather than aligned and rejected; a real (non-repeating) sequence
clears it at the defaults (Provenance), a low-complexity one may not
(untested).

## Do not miss

- **No database for this image is installed (2026-09-26).** `chpc-tool
  doctor mmseqs2` warns until someone runs [`fetch-db.sh`](fetch-db.sh) on the
  login node, the only node with internet
  ([doc 02](../../docs/02-storage-and-data.md#internet-access)): with no
  arguments it fetches UniProtKB/Swiss-Prot (about 300 MB built) to
  `$MMSEQS2_DB_SWISSPROT`; with a name from `mmseqs databases` (UniRef50,
  PDB, ...) it lands beside it under `$MMSEQS2_DB_DIR`. UniRef90 and NR are
  hundreds of GB; budget the share before starting one. `test.sh` searches
  Swiss-Prot too once it exists.
- **The 1 TB under `$MMSEQS2_DB_DIR/colabfold_uniref30_2302_envdb_202108` is
  not a target for this image.** It is UniRef30 2302 plus the ColabFold
  environmental database, extracted and indexed 2026-09-24 by its own
  `build_dbs.sbatch` with the `mmseqs` inside `colabfold_1.5.5.sif` (release
  15), for `colabfold_search`; an index is read by the binary that wrote it,
  and this image carries release 18. The `colabfold` entry's README is where
  that set is documented.

---

## Provenance

Built 2026-09-17 by kanderson6 on the CoreHPC login node (120 s), from the
prebuilt AVX2 binary.

`chpc-tool test mmseqs2`: `easy-search` of a 78-residue sequence against itself,
asserting a self-hit at identity 1.000. Unlike foldseek this needs no
`--exhaustive-search`: a real (non-repeating) amino-acid sequence clears the
prefilter normally.

## Build notes

- The AVX2 build is safe here: compute nodes are AMD EPYC 9745 (Zen 5) with both
  AVX2 and AVX-512, verified 2026-09-17.
