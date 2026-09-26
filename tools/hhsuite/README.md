# HH-suite

| | |
|---|---|
| Status | verified (`chpc-tool test hhsuite`: `hhalign` hit at Probab=100.00 over 73 aligned columns; CPU, date not recorded) |
| Image | `hhsuite_3.sif`, 102 MB; recipe [`hhsuite_3.def`](hhsuite_3.def) |
| GPU | CPU (`-p cpu`) |
| Weights | none. Databases for `hhsearch`/`hhblits` (UniRef30, PDB70): none on the share; they would go in `$CHPC_LAB/data/hhsuite` |
| Licence | GPL-3.0 |
| Upstream | release `v3.3.0`, prebuilt `hhsuite-3.3.0-AVX2-Linux.tar.gz` |
| Base | `debian:12-slim` |
| Built | 2026-09-18, kanderson6, CoreHPC login node (96 s) |

## Run it

```bash
salloc -p cpu -c 8 --mem 16G -t 2:00:00
mkdir -p /mnt/scratch/user/$USER/hhsuite/run1 && cd "$_"   # q.a3m and t.a3m here; the same path is valid inside the container
chpc-tool exec hhsuite -- /opt/hhsuite/bin/hhalign -i q.a3m -t t.a3m -o out.hhr -cpu "$SLURM_CPUS_PER_TASK"
```

`-cpu "$SLURM_CPUS_PER_TASK"` matches the allocation (untested: the self-test
passes `-cpu 2`). No `eval` is needed; the entry exports only the image path.
The full path is what the self-test runs. The bare name works too,
`chpc-tool exec hhsuite -- hhalign …`, because the recipe's `%environment`
puts `/opt/hhsuite/bin` and `/opt/hhsuite/scripts` on `PATH` inside the image.

As a job: copy `templates/slurm/tool-gpu.sbatch` with `--partition=cpu` and no
`--gres` (drop its `nvidia-smi` line too), and set the other EDIT lines to the
values above. The method and the `eval` idiom:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

`hhalign` takes two A3M files, a single sequence each at minimum; the
self-test's query is

```
>query
MKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQAPILSRVGDGTQDNLSGAEKAVQVKVKALPDAQFEVVHSLAKWKR
```

and its template shares the ~60-residue core with different flanks. A deeper
alignment in either file becomes the profile HMM.

The image carries the whole suite, not just the entry point: `hhsearch` (the
`ENTRY`), `hhblits`, `hhalign`, `hhmake`, `hhfilter`, `hhconsensus`, plus the
perl scripts `addss.pl` and `reformat.pl`. Only `hhalign` runs without a
database (Do not miss).

Output is `out.hhr`: a hit list, then one block per hit starting `No 1`, whose
summary line carries `Probab=`, `Aligned_cols=` and the rest (the self-test
reads those two from the first hit). Hits are in HH-suite's own order, best
first (untested beyond one hit). Before trusting a `Probab=`: an `.hhr` with
no `No 1` block is well-formed and exits 0, so check for a hit before parsing
one out; and with single-sequence inputs each "profile" is one sequence, so
the probability is a pairwise statement, not a family one.

## Do not miss

- **`hhsearch` and `hhblits` need a database that is not on the share.**
  UniRef30 is ~90 GB uncompressed, PDB70 ~60 GB, and neither is in the image or
  at `$CHPC_LAB/data/hhsuite`. `hhalign` needs none. Budget the share before
  fetching one, on the login node (Traps).
- **No hit is still exit 0.** `hhalign` writes a hit-less `.hhr` and succeeds;
  `grep -q 'No 1' out.hhr` before reading `Probab=`.
- **Leave `HHLIB` alone.** It and the `PATH` additions are set inside the image
  by the recipe's `%environment`, on purpose not by `tool.conf`; the perl
  scripts find their data files through it (Build notes).
- **The build is AVX2.** Fine on every CoreHPC node; not a portable image.

---

## Provenance

Built 2026-09-18 by kanderson6 on the CoreHPC login node (96 s), from the
prebuilt AVX2 release tarball.

`chpc-tool test hhsuite`: aligns two sequences sharing a ~60-residue core via
`hhalign`, asserting a hit at `Probab >= 90` (measured: 100.00 over 73 aligned
columns). Exercises A3M parsing, HMM construction, Viterbi alignment and `.hhr`
output.

`hhalign` is deliberate — it is the one tool in the suite that needs no
database, so the test covers what the *image* is responsible for without
depending on a 90 GB download that is a deployment question. The flanks of the
two test sequences differ on purpose; a pair of identical sequences would pass
even if the aligner were replaced by a diagonal.

## Build notes

- **`HHLIB` is set in the def's `%environment`, not in `tool.conf`.** The perl
  scripts locate their data files through it and fail with a bare `Cannot open`
  on a build-directory path when it is unset. It belongs in the image because
  `tool_exports` emits `export`, so anything declared there lands in the host
  job environment on its way in — and `HHLIB` is too generic a name to put
  loose in a job script that also runs other tools.
- The tarball is the **AVX2** build. Every CoreHPC node is AMD EPYC or Xeon
  Platinum with AVX2, so this is safe here, but it is not a portable image.

## Traps

- **`hhblits` and `hhsearch` are useless without a database, and the databases
  are the expensive part.** UniRef30 is ~90 GB uncompressed and PDB70 ~60 GB;
  neither is in the image and neither is on the share yet. FAC is 5 TB for the
  whole lab, so check `df -h /mnt/fac/CX500146_DS1` and talk to the lab before
  downloading one. Fetch on the **login node** — compute nodes get a proxy that
  denies these hosts (doc 02).
