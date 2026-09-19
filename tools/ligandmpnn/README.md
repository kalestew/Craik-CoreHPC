# LigandMPNN

| | |
|---|---|
| Built | 2026-09-19, kanderson6, CoreHPC login node (977 s) |
| Image | `ligandmpnn_1.sif`, 3.49 GB — weights included (~1 GB) |
| Recipe | [`ligandmpnn_1.def`](ligandmpnn_1.def) |
| Upstream | `dauparas/LigandMPNN` @ `26ec57ac` |
| Base | `pytorch/pytorch:2.14.0-cuda13.2-cudnn9-runtime` |
| Licence | MIT |
| GPU | yes — cu132, so **any** `gpu` node including Blackwell |

Weights are baked in: `get_model_params.sh` fetches them from release
artefacts, they are frozen, and a compute node has no internet to fetch them
from. The recipe counts the result (≥ 8 non-empty `.pt`) because `wget -q`
writes a zero-byte file on a 404 and hides it.

## What the test proves

`chpc-tool test ligandmpnn`: designs sequences for a generated 40-residue
backbone with `--model_type ligand_mpnn`, asserting ≥ 3 FASTA records and
that at least two are *distinct*. Measured: 3 records, 3 distinct sequences.

The distinctness check matters — a temperature-0.1 run returning the same
string twice usually means the model never loaded and something echoed the
input back.

`ligand_mpnn` rather than `protein_mpnn` is deliberate: the ProteinMPNN path
would pass on an image where only the ProteinMPNN weights downloaded, which
is exactly the failure worth catching, since `get_model_params.sh` fetches
the two sets separately.

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
- **The vendored openfold predates numpy 2 and the recipe rewrites it.**
  `openfold/np/residue_constants.py` used `np.int`, removed in numpy 1.24,
  against a base that ships numpy 2. Those aliases *were* the Python
  builtins, so substituting them is exactly equivalent — it is what upstream
  openfold did. The recipe greps afterwards to prove no alias survived
  **and** that `np.int64`/`np.float32` were not collateral damage.
- `python` must be spelled out: `ENTRY` is only prepended in front of a flag,
  not a script path, so `chpc-tool exec ligandmpnn -- /opt/…/run.py` fails
  with a bare `FATAL: permission denied`.
