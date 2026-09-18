# ProteinMPNN

| | |
|---|---|
| Built | 2026-09-17, kanderson6, CoreHPC login node |
| Image | `proteinmpnn_1.0.sif`, 3.37 GB |
| Recipe | [`proteinmpnn_1.0.def`](proteinmpnn_1.0.def) |
| Upstream | `dauparas/ProteinMPNN` @ `8907e667` (the repo's last commit, 2024-08-14 — it is effectively frozen) |
| Base | `pytorch/pytorch:2.14.0-cuda13.2-cudnn9-runtime` → torch 2.14.0+cu132, numpy 2.5.2 |
| Licence | MIT |
| Weights | in the image (~73 MB of inference weights, shipped in the repo) |

## What the test proves

`chpc-tool test proteinmpnn`, run in a GPU job on `ggpu1-09` (L40S), 2026-09-17:
parses a generated 40-residue backbone with `helper_scripts/parse_multiple_chains.py`
and designs two sequences with `protein_mpnn_run.py`, asserting the FASTA exists
and holds three records. It checks the **output file**, not the exit status —
`protein_mpnn_run.py` has argument combinations that print a traceback and still
exit 0.

Also run against the real thing: `models/complexes/human_igg1.pdb` from
IgGase_eng, 243 positions, two sequences in 0.97 s on an L40S, ~48% sequence
recovery.

## GPU

Runs on **every** GPU in the cluster, including the RTX Pro 6000 (Blackwell,
sm_120) — verified. The cu13.2 base is what buys that; the older CUDA stacks in
`placer`, `rfdiffusion`, `chai1` and `colabfold` do not, and those entries say so.

## Traps

- **`chpc-tool exec proteinmpnn -- /opt/.../script.py` does not work.** `ENTRY`
  is only prepended when the first argument starts with a dash, so apptainer
  tries to execute the `.py` itself and fails with `FATAL: permission denied` —
  no mention of a missing interpreter. Spell out `python`:
  `chpc-tool exec proteinmpnn -- python /opt/ProteinMPNN/protein_mpnn_run.py …`.
  The generated `$CHPC_LAB/bin/proteinmpnn` wrapper *does* prepend it, so
  `proteinmpnn script.py …` is fine.
- **ProteinMPNN does not index the residues it can see.**
  `parse_multiple_chains.py` walks every integer from a chain's first to its last
  residue number, emitting one character per insertion-code variant and a gap
  character for each missing number — visible as the `X` runs in the output above.
  A consumer must map through the project's own replay of that rule, never a
  chain index.
