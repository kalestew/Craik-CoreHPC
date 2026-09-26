# LigandMPNN

| | |
|---|---|
| Status | verified 2026-09-26 on an L40S (`ggpu1-08`, job 2000973): `chpc-tool test ligandmpnn`, 3 FASTA records, 3 distinct sequences, 10 s |
| Image | `ligandmpnn_1.sif`, 3.49 GB — weights included (~1 GB); recipe [`ligandmpnn_1.def`](ligandmpnn_1.def) |
| GPU | `--gres=gpu:1`, any node (cu132, `sm_120` present); passes on CPU too, slower |
| Weights | in the image at `/opt/LigandMPNN/model_params/` (`$LIGANDMPNN_DIR/model_params`), fetched at build by upstream's `get_model_params.sh`. Nothing under `$CHPC_LAB/data` |
| Licence | MIT |
| Upstream | `dauparas/LigandMPNN` @ `26ec57ac` |
| Base | `pytorch/pytorch:2.14.0-cuda13.2-cudnn9-runtime` |
| Built | 2026-09-19, kanderson6, CoreHPC login node (977 s) |

## Run it

```bash
srun -p gpu --gres=gpu:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/ligandmpnn/run1 && cd "$_"   # in.pdb here, ligand as HETATM; the same path is valid inside the container
chpc-tool exec ligandmpnn -- python /opt/LigandMPNN/run.py \
    --model_type ligand_mpnn \
    --checkpoint_ligand_mpnn /opt/LigandMPNN/model_params/ligandmpnn_v_32_010_25.pt \
    --pdb_path in.pdb --out_folder out \
    --number_of_batches 1 --batch_size 8 --temperature 0.1 --seed 37   # --batch_size 8 is the test's 2 raised for real use (untested at 8)
```

Everything but the batch size is `test.sh` line for line. As a job: copy
`templates/slurm/tool-gpu.sbatch` and set its four EDIT lines to the values
above (`--gres=gpu:1` is safe for this image). The method, the `eval` idiom and
which GPU to ask for: [`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

Input is one PDB. The ligand, substrate or covalent intermediate goes in the
same file as `HETATM` records; that is what this tool sees and plain
ProteinMPNN does not. The self-test's fixture is a generated 40-residue
backbone with no ligand at all, from
[`../_template/make_test_pdb.sh`](../_template/make_test_pdb.sh), so a
backbone-only file runs. Which residues to redesign or hold fixed are
upstream's `--redesigned_residues` / `--fixed_residues` flags, space-separated
`<chain><number>` labels (untested here).

Output is `out/seqs/<name>.fa`, `<name>` being the PDB's basename: the first
record is the input sequence, then one record per design, `--batch_size` times
`--number_of_batches` of them (the test asserts `1 native + 2 designs`).
Records are in sampling order, not ranked; upstream writes the per-design
`overall_confidence` and `ligand_confidence` into each header (untested here),
and the corresponding backbones land in `out/backbones/` (untested here).

Before trusting a sequence: a run with no ligand in the file is not an error
and looks identical to one that saw the ligand. The run's log reports how many
ligand atoms it parsed (untested); read it before believing a subsite design
was conditioned on anything. Two designs that are the same string at
temperature 0.1 usually mean the model never loaded (Provenance).

## Do not miss

- **The checkpoint is `ligandmpnn_v_*.pt`, never `ligandmpnn_sc_*`.** The
  `sc` file is the side-chain packer, a different network; loading it into
  `--checkpoint_ligand_mpnn` dies with `Unexpected key(s): W_v_sc,
  W_torsions, ...`, which reads as a corrupt download and is the wrong file
  (Traps).
- **Spell out `python`.** `ENTRY=python` is prepended only in front of a
  flag, not a script path, so `chpc-tool exec ligandmpnn -- /opt/LigandMPNN/run.py`
  fails with a bare `FATAL: permission denied` and no mention of an
  interpreter.
- **The ligand is `HETATM` records in the input PDB.** A missing ligand is
  silent: the test itself runs on a bare backbone. Check the parsed atom count
  in the log (untested).
- **Any `gpu` node is fine.** The image carries `sm_120`; a bare
  `--gres=gpu:1` lands anywhere and runs.

---

## Provenance

Built 2026-09-19 by kanderson6 on the CoreHPC login node (977 s).

`chpc-tool test ligandmpnn`: designs sequences for a generated 40-residue
backbone with `--model_type ligand_mpnn`, asserting ≥ 3 FASTA records and
that at least two are *distinct*. Measured: 3 records, 3 distinct sequences.
Passed 2026-09-26 on an L40S (`ggpu1-08`, job 2000973), 10 s; an earlier pass went
unrecorded.

The distinctness check matters — a temperature-0.1 run returning the same
string twice usually means the model never loaded and something echoed the
input back.

`ligand_mpnn` rather than `protein_mpnn` is deliberate: the ProteinMPNN path
would pass on an image where only the ProteinMPNN weights downloaded, which
is exactly the failure worth catching, since `get_model_params.sh` fetches
the two sets separately.

## Build notes

Weights are baked in: `get_model_params.sh` fetches them from release
artefacts, they are frozen, and a compute node has no internet to fetch them
from. The recipe counts the result (≥ 8 non-empty `.pt`) because `wget -q`
writes a zero-byte file on a 404 and hides it.

- **The vendored openfold predates numpy 2 and the recipe rewrites it.**
  `openfold/np/residue_constants.py` used `np.int`, removed in numpy 1.24,
  against a base that ships numpy 2. Those aliases *were* the Python
  builtins, so substituting them is exactly equivalent — it is what upstream
  openfold did. The recipe greps afterwards to prove no alias survived
  **and** that `np.int64`/`np.float32` were not collateral damage.

## Traps

- **`ligandmpnn_*.pt` is not one model family.** `model_params/` also holds
  `ligandmpnn_sc_v_32_002_16.pt`, the **side-chain packing** network — a
  different architecture belonging to `--checkpoint_path_sc`, not
  `--checkpoint_ligand_mpnn`. It sorts first, so a glob of `ligandmpnn_*.pt`
  picks it and `run.py` loads side-chain weights into the sequence-design
  model:

  ```
  RuntimeError: Error(s) in loading state_dict for ProteinMPNN:
    Unexpected key(s): W_v_sc, W_torsions, features.W_XY_project_down1 ...
  ```

  which reads as a corrupt download and is the wrong file. Match
  `ligandmpnn_v_*.pt`, or name `ligandmpnn_v_32_010_25.pt` outright.
- `python` must be spelled out: `ENTRY` is only prepended in front of a flag,
  not a script path, so `chpc-tool exec ligandmpnn -- /opt/…/run.py` fails
  with a bare `FATAL: permission denied`.
