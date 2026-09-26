# ColabFold

| | |
|---|---|
| Status | verified 2026-09-26 on an L40S (`ggpu1-08`, job 2000973): `chpc-tool test colabfold`, a 31-mer at mean pLDDT 91.3, 39 s |
| Image | `colabfold_1.5.5.sif`, 3.10 GB, no weights; recipe [`colabfold_1.5.5.def`](colabfold_1.5.5.def) |
| GPU | `--gres=gpu:nvidia_l40s:1` or `--gres=gpu:nvidia_h100_nvl:1` (`GPU_MAX_CC=9.0`: cuda12.2 has no `sm_120`). Never a bare `gpu:1` |
| Weights | 5.0 GB at `$COLABFOLD_DATA` (`$CHPC_LAB/data/colabfold`): `alphafold2_ptm` and `alphafold2_multimer_v3`, fetched on the login node by [`fetch-weights.sh`](fetch-weights.sh) |
| Licence | MIT (code); AlphaFold2 parameters CC-BY-4.0 |
| Upstream | `ghcr.io/sokrypton/colabfold:1.5.5-cuda12.2.2` |
| Built | 2026-09-18, kanderson6, CoreHPC login node (1428 s) |

## Run it

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/colabfold/run1 && cd "$_"   # in.fasta here; the same path is valid inside the container
eval "$(chpc-tool export colabfold)"                          # $COLABFOLD_DATA in this shell
chpc-tool exec colabfold -- colabfold_batch --msa-mode single_sequence --data "$COLABFOLD_DATA" in.fasta out
```

That is the self-test's line minus its speed-ups (`--model-type
alphafold2_ptm --num-models 1`); without them `colabfold_batch` applies its own
model-type and model-count defaults against the two parameter sets on the
share. With MSAs precomputed on the login node, replace
`--msa-mode single_sequence` by `--msa-directory <dir>` (untested).

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines
to the values above; its `--gres=gpu:nvidia_l40s:1` default is the right one
here. The method, the `eval` idiom and which GPU to ask for:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

A FASTA, one or more records; the self-test's is

```
>testpep
MKTAYIAKQRQISFVKSHFSRQLEERLGLIE
```

A complex is one record with its chains joined by `:` (untested here).

Output lands in `out/`, a `.pdb` per model (the self-test reads `out/*.pdb`);
ColabFold puts `rank_00N` in the file names and ranks by its own confidence
(untested here: the self-test takes the first file). pLDDT is in the B-factor
column (61-66) of every atom, so a mean over the CA atoms is one `awk` away
(`test.sh`). A high pLDDT says a confidence was computed, not that the model
is right: the self-test's 91.3 reflects an easy helical sequence, and
`single_sequence` mode has seen no MSA.

## Do not miss

- **`--data "$COLABFOLD_DATA"` on every call, after the `eval`.** The default
  parameter path is `/cache/colabfold` inside the read-only image; without the
  flag colabfold tries to write into a squashfs, and without the `eval` the
  variable is empty on your command line.
- **The default MSA modes need the internet.** `mmseqs2_uniref_env` and
  `mmseqs2_uniref` query `api.colabfold.com`, which a compute node cannot reach
  ([doc 02](../../docs/02-storage-and-data.md#internet-access)); the job fails
  after the weights have loaded. Precompute MSAs on the login node and pass
  `--msa-directory`, or run `--msa-mode single_sequence`.
- **`--gres=gpu:nvidia_l40s:1` or an H100, never a bare `gpu:1`.** cuda12.2
  predates `sm_120`; `chpc-tool exec` refuses a Blackwell node before launching.
- **Fetch weights with `fetch-weights.sh` only**, on the login node. Tarballs
  pulled by hand lack the marker colabfold checks for, and it re-downloads into
  the read-only image at the start of the first real job (Traps).

---

## Provenance

Built 2026-09-18 by kanderson6 on the CoreHPC login node (1428 s): a pull of
the upstream image, not a build (Build notes).

`chpc-tool test colabfold`: folds a 31-residue peptide with
`--msa-mode single_sequence --model-type alphafold2_ptm --num-models 1`,
asserting 31 CA atoms, finite coordinates, and a mean pLDDT in `(0, 100]`.
Measured on an L40S: mean pLDDT **91.3**.

The pLDDT assertion checks that a real confidence was computed, not that
the model is good — single-sequence mode on a short peptide is expected to
score poorly, and 91.3 here reflects an easy helical sequence.

`GPU_MAX_CC=9.0` in `tool.conf`: the upstream tag is cuda12.2, which predates
`sm_120` (recipe header), so `chpc-tool exec` refuses a Blackwell node up
front instead of dying at the first kernel launch.

## Build notes

A pull rather than a build: upstream publishes a working CUDA image and
there is nothing to add. The `.def` exists anyway so the image has
provenance in git and can be reproduced after a scratch purge, which a bare
`apptainer pull` in somebody's shell history cannot.

AlphaFold2 parameters are CC-BY-4.0 — usable commercially and
redistributable within the lab, unlike AlphaFold3 — so this is a plain
download and not a `chpc-assets` payload.

## Traps

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
- **Fetch with `fetch-weights.sh`, not by hand.** `colabfold_batch` checks
  for a `download_..._finished.txt` marker that only colabfold's own
  downloader writes. Pulling the parameter tarballs directly leaves the
  marker absent, and colabfold silently re-downloads into the read-only
  default at the start of the first real job. `tool_doctor` checks for the
  marker, not just for `.npz` files.
- cuda12.2 predates `sm_120`, so use `--gres=gpu:nvidia_l40s:1` or an H100,
  never a bare `--gres=gpu:1` (doc 05).
