# MMseqs2

| | |
|---|---|
| Status | verified (`chpc-tool test mmseqs2`: self-hit at identity 1.000; CPU, date not recorded) |
| Image | `mmseqs2_18.sif`, 51 MB; recipe [`mmseqs2_18.def`](mmseqs2_18.def) |
| GPU | CPU (`-p cpu`) |
| Weights | none. Databases: none installed yet; they belong in `$CHPC_LAB/data/mmseqs2` |
| Licence | GPL-3.0 |
| Upstream | release `18-8cc5c`, prebuilt `mmseqs-linux-avx2` |
| Base | `debian:12-slim` |
| Built | 2026-09-17, kanderson6, CoreHPC login node (120 s) |

## Run it

```bash
salloc -p cpu -c 8 --mem 16G -t 2:00:00
mkdir -p /mnt/scratch/user/$USER/mmseqs2/run1 && cd "$_"   # q.fa and targets.fa here; the same path is valid inside the container
chpc-tool exec mmseqs2 -- mmseqs easy-search q.fa targets.fa res.m8 tmp --threads "$SLURM_CPUS_PER_TASK"
chpc-tool exec mmseqs2 -- mmseqs easy-search q.fa "$CHPC_LAB/data/mmseqs2/<db>" res.m8 tmp --threads "$SLURM_CPUS_PER_TASK"   # (untested) once a database exists
```

The first line is the self-test's form, which searches `q.fa` against itself
with `--threads 2`: `easy-search` takes a FASTA as the target as readily as a
prebuilt database (`--threads "$SLURM_CPUS_PER_TASK"` is untested). The second
is the form for a database, and **no database is installed yet** (2026-09-25):
`<db>` is a placeholder until someone downloads one on the login node (Do not
miss). No `eval` is needed; the entry exports only the image path.

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

- **There is no database on the share yet.** `$CHPC_LAB/data/mmseqs2` is where
  one goes, downloaded once on the login node (`mmseqs databases`, from the
  recipe's `%help`); a compute node cannot fetch
  ([doc 02](../../docs/02-storage-and-data.md#internet-access)). UniRef90 and
  friends are hundreds of GB — budget the share before starting one.
- **This is what ColabFold uses underneath.** A local database here is what
  would let the `colabfold` entry build MSAs without the internet (its README).

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
