# ColabFold

| | |
|---|---|
| Built | 2026-09-18, kanderson6, CoreHPC login node (1428 s) |
| Image | `colabfold_1.5.5.sif`, 3.10 GB — no weights |
| Recipe | [`colabfold_1.5.5.def`](colabfold_1.5.5.def) |
| Upstream | `ghcr.io/sokrypton/colabfold:1.5.5-cuda12.2.2` |
| Weights | 5.0 GB on FAC, via [`fetch-weights.sh`](fetch-weights.sh) |
| Licence | MIT (code); AlphaFold2 parameters CC-BY-4.0 |
| GPU | yes — **not on Blackwell** (cuda12.2) |

A pull rather than a build: upstream publishes a working CUDA image and
there is nothing to add. The `.def` exists anyway so the image has
provenance in git and can be reproduced after a scratch purge, which a bare
`apptainer pull` in somebody's shell history cannot.

AlphaFold2 parameters are CC-BY-4.0 — usable commercially and
redistributable within the lab, unlike AlphaFold3 — so this is a plain
download and not a `chpc-assets` payload.

## What the test proves

`chpc-tool test colabfold`: folds a 31-residue peptide with
`--msa-mode single_sequence --model-type alphafold2_ptm --num-models 1`,
asserting 31 CA atoms, finite coordinates, and a mean pLDDT in `(0, 100]`.
Measured on an L40S: mean pLDDT **91.3**.

The pLDDT assertion checks that a real confidence was computed, not that
the model is good — single-sequence mode on a short peptide is expected to
score poorly, and 91.3 here reflects an easy helical sequence.

## Two things bite on a cluster

- **`--data` is mandatory.** `colabfold.download.default_data_dir` is
  `/cache/colabfold`, *inside the image*, which is read-only. Without
  `--data "$COLABFOLD_DATA"` colabfold tries to write parameters into a
  squashfs. The registry exports that variable; jobs must pass it through.
- **The default MSA modes need the internet.** `mmseqs2_uniref_env` and
  `mmseqs2_uniref` query `api.colabfold.com`, and compute nodes reach a
  proxy that denies it (doc 02) — the job fails partway in, after the
  weights have loaded. Either precompute MSAs on the login node and pass
  `--msa-directory`, or accept `--msa-mode single_sequence`. The lab's own
  `mmseqs2` image can build the MSAs if a local database is ever installed.

## Traps

- **Fetch with `fetch-weights.sh`, not by hand.** `colabfold_batch` checks
  for a `download_..._finished.txt` marker that only colabfold's own
  downloader writes. Pulling the parameter tarballs directly leaves the
  marker absent, and colabfold silently re-downloads into the read-only
  default at the start of the first real job. `tool_doctor` checks for the
  marker, not just for `.npz` files.
- cuda12.2 predates `sm_120`, so use `--gres=gpu:nvidia_l40s:1` or an H100,
  never a bare `--gres=gpu:1` (doc 05).
