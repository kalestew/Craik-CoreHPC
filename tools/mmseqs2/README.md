# MMseqs2

| | |
|---|---|
| Built | 2026-09-17, kanderson6, CoreHPC login node (120 s) |
| Image | `mmseqs2_18.sif`, 51 MB |
| Recipe | [`mmseqs2_18.def`](mmseqs2_18.def) |
| Upstream | release `18-8cc5c`, prebuilt `mmseqs-linux-avx2` |
| Base | `debian:12-slim` |
| Licence | GPL-3.0 |
| GPU | no |

## What the test proves

`chpc-tool test mmseqs2`: `easy-search` of a 78-residue sequence against itself,
asserting a self-hit at identity 1.000. Unlike foldseek this needs no
`--exhaustive-search`: a real (non-repeating) amino-acid sequence clears the
prefilter normally.

## Notes

- The AVX2 build is safe here: compute nodes are AMD EPYC 9745 (Zen 5) with both
  AVX2 and AVX-512, verified 2026-09-17.
- This is also what ColabFold uses underneath for MSAs. Databases belong in
  `$CHPC_LAB/data/mmseqs2`, downloaded once on the login node. UniRef90 and
  friends are hundreds of GB — budget the share before starting one.
