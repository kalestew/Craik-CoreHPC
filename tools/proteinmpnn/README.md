# ProteinMPNN

| | |
|---|---|
| Status | verified 2026-09-17 on an L40S (`ggpu1-09`, `chpc-tool test proteinmpnn`); also verified on an RTX PRO 6000 (Blackwell) |
| Image | `proteinmpnn_1.0.sif`, 3.37 GB; recipe [`proteinmpnn_1.0.def`](proteinmpnn_1.0.def) |
| GPU | `--gres=gpu:1`, any node (the image carries `sm_120`) |
| Weights | in the image (~73 MB, shipped in the repo): vanilla, soluble (`--use_soluble_model`) and CA-only sets |
| Licence | MIT |
| Upstream | `dauparas/ProteinMPNN` @ `8907e667` (the repo's last commit, 2024-08-14 — it is effectively frozen) |
| Base | `pytorch/pytorch:2.14.0-cuda13.2-cudnn9-runtime` → torch 2.14.0+cu132, numpy 2.5.2 |
| Built | 2026-09-17, kanderson6, CoreHPC login node |

## Run it

```bash
srun -p gpu --gres=gpu:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/proteinmpnn/run1 && cd "$_"   # your PDBs go in in/; the same path is valid inside the container
chpc-tool exec proteinmpnn -- python /opt/ProteinMPNN/helper_scripts/parse_multiple_chains.py --input_path=in --output_path=parsed.jsonl
chpc-tool exec proteinmpnn -- python /opt/ProteinMPNN/protein_mpnn_run.py --jsonl_path parsed.jsonl --out_folder out --num_seq_per_target 8 --sampling_temp 0.1 --batch_size 1 --seed 37
```

Two steps: the parser turns a directory of PDBs into one JSONL, the runner
designs from it. `--num_seq_per_target 8` is a production count (untested: the
self-test asks for 2); everything else is the self-test's line. No `eval` is
needed, the entry exports nothing a command line uses. For the soluble model
add `--use_soluble_model` to the second line (untested).

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines
to the values above, with both `chpc-tool exec` lines in place of EDIT 4
(`--gres=gpu:1` is fine for this image). The method, the `eval` idiom and
which GPU to ask for: [`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

`--input_path` is a **directory** of PDB files, not a file: every PDB in `in/`
becomes one line of `parsed.jsonl` and one design target. Backbone atoms
(N, CA, C, O) are enough; the self-test feeds it a generated 40-residue chain
A from `_template/make_test_pdb.sh`.

Output is `out/seqs/<name>.fa`, one FASTA per input PDB. The first record is
the native sequence, the rest are the designs in sampling order, not ranked.
Each design header carries ProteinMPNN's own `score` (a negative
log-likelihood, lower is better) and `seq_recovery` (untested here: the
self-test checks only that the records exist). Neither is a fold-quality
prediction; refold what you keep. Runs of `X` in a design are gap characters
for residue numbers missing from the chain, not designed positions (Traps).

## Do not miss

- **Spell out `python`.** `ENTRY` is not prepended before a script path, so
  `chpc-tool exec proteinmpnn -- /opt/ProteinMPNN/protein_mpnn_run.py` dies
  with `FATAL: permission denied` and no hint about an interpreter (Traps).
- **`--input_path` takes a directory.** Point it at `in/`, as the self-test
  does, not at a PDB.
- **`--use_soluble_model` selects the soluble weights.** All three weight sets
  ship in the image; the call site picks, nothing in `tool.conf` does.
- **Never index a design by chain position.** The parser emits one character
  per integer residue number from a chain's first to its last, gaps included,
  so position N of a design is not residue N of your chain (Traps).
- **Check the FASTA, not the exit status.** `protein_mpnn_run.py` has argument
  combinations that print a traceback and still exit 0.

---

## Provenance

Built 2026-09-17 by kanderson6 on the CoreHPC login node.

`chpc-tool test proteinmpnn`, run in a GPU job on `ggpu1-09` (L40S), 2026-09-17:
parses a generated 40-residue backbone with `helper_scripts/parse_multiple_chains.py`
and designs two sequences with `protein_mpnn_run.py`, asserting the FASTA exists
and holds three records. It checks the **output file**, not the exit status —
`protein_mpnn_run.py` has argument combinations that print a traceback and still
exit 0.

Also run against the real thing: `models/complexes/human_igg1.pdb` from
IgGase_eng, 243 positions, two sequences in 0.97 s on an L40S, ~48% sequence
recovery.

Runs on **every** GPU in the cluster, including the RTX Pro 6000 (Blackwell,
sm_120) — verified. The cu13.2 base is what buys that; the older CUDA stacks in
`placer`, `rfdiffusion`, `chai1` and `colabfold` do not, and those entries say so
([`../README.md`](../README.md#which-gpu), "Which GPU").

## Traps

- **`chpc-tool exec proteinmpnn -- /opt/.../script.py` does not work.** `ENTRY`
  is only prepended when the first argument starts with a dash, so apptainer
  tries to execute the `.py` itself and fails with `FATAL: permission denied` —
  no mention of a missing interpreter. Spell out `python`:
  `chpc-tool exec proteinmpnn -- python /opt/ProteinMPNN/protein_mpnn_run.py …`.
- **ProteinMPNN does not index the residues it can see.**
  `parse_multiple_chains.py` walks every integer from a chain's first to its last
  residue number, emitting one character per insertion-code variant and a gap
  character for each missing number — visible as `X` runs in the output.
  A consumer must map through the project's own replay of that rule, never a
  chain index.
