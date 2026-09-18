# HH-suite

| | |
|---|---|
| Built | 2026-09-18, kanderson6, CoreHPC login node (96 s) |
| Image | `hhsuite_3.sif`, 102 MB |
| Recipe | [`hhsuite_3.def`](hhsuite_3.def) |
| Upstream | release `v3.3.0`, prebuilt `hhsuite-3.3.0-AVX2-Linux.tar.gz` |
| Base | `debian:12-slim` |
| Licence | GPL-3.0 |
| GPU | no |

Carries the whole suite, not just the entry point: `hhsearch` (the `ENTRY`),
`hhblits`, `hhalign`, `hhmake`, `hhfilter`, `hhconsensus`, plus the perl
scripts `addss.pl` and `reformat.pl`. Reach anything other than `hhsearch` by
naming it — `chpc-tool exec hhsuite -- hhalign …` works, because the def puts
`/opt/hhsuite/bin` and `/opt/hhsuite/scripts` on `PATH` inside the image.

## What the test proves

`chpc-tool test hhsuite`: aligns two sequences sharing a ~60-residue core via
`hhalign`, asserting a hit at `Probab >= 90` (measured: 100.00 over 73 aligned
columns). Exercises A3M parsing, HMM construction, Viterbi alignment and `.hhr`
output.

`hhalign` is deliberate — it is the one tool in the suite that needs no
database, so the test covers what the *image* is responsible for without
depending on a 90 GB download that is a deployment question. The flanks of the
two test sequences differ on purpose; a pair of identical sequences would pass
even if the aligner were replaced by a diagonal.

## Traps

- **`hhblits` and `hhsearch` are useless without a database, and the databases
  are the expensive part.** UniRef30 is ~90 GB uncompressed and PDB70 ~60 GB;
  neither is in the image and neither is on the share yet. FAC is 5 TB for the
  whole lab, so check `df -h /mnt/fac/CX500146_DS1` and talk to the lab before
  downloading one. Fetch on the **login node** — compute nodes get a proxy that
  denies these hosts (doc 02).
- **`HHLIB` is set in the def's `%environment`, not in `tool.conf`.** The perl
  scripts locate their data files through it and fail with a bare `Cannot open`
  on a build-directory path when it is unset. It belongs in the image because
  `tool_exports` emits `export`, so anything declared there lands in the host
  job environment on its way in — and `HHLIB` is too generic a name to put
  loose in a job script that also runs other tools.
- The tarball is the **AVX2** build. Every CoreHPC node is AMD EPYC or Xeon
  Platinum with AVX2, so this is safe here, but it is not a portable image.
