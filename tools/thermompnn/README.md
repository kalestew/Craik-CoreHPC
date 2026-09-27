# ThermoMPNN

| | |
|---|---|
| Status | **built** 2026-09-26 — image built and published; `test.sh` needs a GPU node and is **queued**. `verified` when it passes |
| Image | `thermompnn_1.sif` from [`thermompnn_1.def`](thermompnn_1.def); 3.4 GB on a `pytorch/pytorch:2.14.0-cuda13.2-cudnn9-runtime` base |
| GPU | yes. `GPU_MAX_CC` deliberately **empty** — the build asserts all three of our GPU models are covered |
| Weights | **in upstream's git repo**, baked into the image. Nothing on the share, nothing to fetch |
| Licence | MIT |
| Upstream | <https://github.com/Kuhlman-Lab/ThermoMPNN>, pinned at `370f76ec62bd929f7425e311d8df04a0d094990f` |
| Citation | Dieckhaus, Brocidiacono, Randolph & Kuhlman, *PNAS* **121**(6), 2024, [2314853121](https://doi.org/10.1073/pnas.2314853121) |

ThermoMPNN predicts the **change in folding stability** (ddG) for point
substitutions, by transfer learning on top of ProteinMPNN's learned
representation. Given a structure and a chain it does full site-saturation
mutagenesis — every position, every substitution — in one pass.

It is **the third vote in the stability consensus**. Until it exists the
consensus is [`foldx`](../foldx/README.md) plus
[`rosetta`](../rosetta/README.md) `cartesian_ddg` only, which is two votes, not
three, and two methods that disagree leave nothing to do. It also fills a gap
the co-folding entries cannot: co-folding models barely respond to point
mutations (Masters 2025), so a ranking built from their confidence scores is
not a stability ranking. This is the tool that is supposed to respond.

## Run it

Nothing to fetch and nothing staged on FAC — upstream commits its checkpoints and
the image bakes them in.

The remaining step for `verified` is the test, which needs a GPU node:

```bash
chpc-tool test thermompnn            # GPU node -- this is what `verified` means
```

The production command, from [`test.sh`](test.sh) and **not yet run on real
input**:

```bash
salloc -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 1:00:00
chpc-tool exec thermompnn -- python \
    /opt/ThermoMPNN/analysis/custom_inference.py \
    --pdb in.pdb --chain A \
    --model_path /opt/ThermoMPNN/models/thermoMPNN_default.pt --out_dir .   # (untested)
```

Any GPU model works — `nvidia_l40s`, `nvidia_h100_nvl` or `nvidia_rtx_pro_6000`
— and the build asserts that rather than assuming it (Provenance).

Build and publish: [`../README.md`, Add a tool](../README.md#add-a-tool).

## Inputs and outputs

A PDB and a chain in; `ThermoMPNN_inference_<pdbid>.csv` out, one row per
substitution, with columns `Model`, `Dataset`, `ddG_pred`, `position`,
`wildtype`, `mutation`, `pdb`, `chain`.

## Do not miss

Three things about the output will be read wrong if they are not read here
first, and the first one is the expensive one.

- **POSITIVE `ddG_pred` IS DESTABILISING.** Upstream negates the Megascale
  `ddG_ML` when training, so the sign here is the **opposite** of that
  dataset's. Get this backwards and a consensus that averages ThermoMPNN
  against FoldX and Rosetta **cancels instead of agreeing** — and it will look
  like the three methods disagree about everything rather than like one of them
  being inverted. `test.sh` asserts the convention rather than trusting it, by
  checking that substitutions to proline sit above the overall mean.
- **`position` is a 0-BASED INDEX into the parsed chain, not a PDB residue
  number.** Map it back through the structure before quoting a mutation to
  anybody. A PDB whose numbering does not start at 1, or which has gaps — which
  is most of them — will produce mutation names that look right and are not.
- **Monomers only.** Multi-chain inputs are not supported upstream, so a
  complex has to be split and each chain run alone. That also means **no
  interface effects**: a substitution that destabilises a dimer interface is
  invisible here, and this is exactly the class of mutation an engineering
  campaign cares about. Use it for the fold, not for the complex.
- **`local.yaml` ships someone else's absolute paths, and it is committed.**
  Upstream's copy points `thermompnn_dir` and `cache_dir` at `/proj/kuhl_lab`
  and `/nas/longleaf`, a cluster nobody here has. Inference survives it because
  `custom_inference.py` overwrites `thermompnn_dir` at run time; nothing else
  in the file does. The recipe rewrites both platform keys and replaces every
  `data_loc` path with a loud `UNSET-training-data` marker, because leaving a
  stranger's home directory in a config is how somebody spends an afternoon
  debugging a path that was never ours.
- **Training is not set up here, deliberately.** The `data_loc` markers above
  will fail immediately if you try. Training needs the Megascale and FireProt
  datasets, and staging those is a separate decision from having the predictor.

---

## Provenance

**Never run.** `STATUS=planned`; the image is not built. Everything below is
what the recipe and test will establish.

### The build ignores upstream's pins, on purpose

Upstream offers two install routes and they disagree with each other.
`environment.yaml` asks for python 3.10 with **both** `pytorch-cuda=11.7`
**and** `cudatoolkit=11.3`, which are mutually inconsistent; `pyproject.toml`'s
extras pin `torch==2.5.1` against cu121 or cu124. Honouring any of them would
replace the CUDA 13.2 stack this base exists to provide with one several years
older than the node driver, and would cap the image at sm_90 — so it could not
run on the Blackwell nodes at all. Upstream's own README warns that its yaml
"may cause pytorch to install incorrectly (CPU version instead of GPU
version)".

So the recipe follows the same rule as [`ligandmpnn`](../ligandmpnn/README.md):
take the base image's modern CUDA stack, install only the genuine non-torch
dependencies, and **assert the properties a wrong build would get wrong**.
Whether a newer torch changes the *answers* is then not a matter of opinion —
`test.sh` correlates against upstream's own reference output.

### The arch-flag check, and why the obvious form of it is wrong

`torch 2.14.0+cu132` reports:

```
sm_75 sm_80 sm_86 sm_90 sm_100 sm_120
```

There is **no `sm_89`** in that list, and the L40S is sm_89. A first version of
this recipe tested `"sm_89" in flags`, failed the build, and advised capping
`GPU_MAX_CC` — which would have banned the L40S nodes for no reason.

A cubin is **forward-compatible within its major compute capability**: code
compiled for sm_86 runs on any sm_8x device at or above 8.6, which includes the
L40S. It is not backward compatible and never crosses a major version — which
is the entire reason `GPU_MAX_CC` is a *ceiling* rather than a membership test.
The recipe now asks whether each of our three models is covered by some cubin
of its own major version: sm_86 covers 8.9, sm_90 covers 9.0, sm_120 covers
12.0. All three are, so `GPU_MAX_CC` is empty.

### wandb is a dependency of inference, which is not documented anywhere

`analysis/custom_inference.py` imports `train_thermompnn` for `TransferModelPL`,
and `train_thermompnn.py` does `import wandb` at module scope. So a
prediction-only image that reasonably left wandb out fails at import, with a
traceback pointing into the **training** module — which reads like the wrong
entry point was used.

The recipe installs wandb and then muzzles it: `%environment` sets
`WANDB_MODE=disabled` and `WANDB_SILENT=true`, because a compute node has no
internet and, left alone, wandb looks for credentials and tries to reach
`api.wandb.ai` in the middle of a prediction.

### What `test.sh` will prove

**The fixture is upstream's and so is the answer.** The repo ships both
`examples/2OCJ.pdb` and `examples/ThermoMPNN_inference_2OCJ.csv` — the input
and the output its authors got — so the test does not have to invent a
criterion for "a plausible ddG". It re-runs the prediction and compares.

| # | Asserted |
|---|---|
| 1 | a CUDA torch, a visible device, and a real kernel launch — `is_available()` is true on a device the kernels do not cover |
| 2 | 3880 rows, the same mutation list as the reference, in the same order |
| 3 | the predictions vary: standard deviation above 0.5 |
| 4 | **Pearson r > 0.99 against upstream's reference output** |
| 5 | the sign convention: mean ddG for substitutions to proline sits above the overall mean |
| 6 | the spread survives: `I159D − A63I > 6` kcal/mol, the reference's most destabilising against its most stabilising |

Case 4 is the one the entry exists for, and it is the strongest check available
to anything in this registry: a number this image produces, compared with a
number the people who trained the model produced. It is also what settles the
question the build had to take a position on — correlation above 0.99 is what
says that running a different torch and CUDA than upstream pinned did not change
the answers.

Correlation rather than equality, because different torch and cuDNN versions
reorder floating-point reductions; demanding equality would fail on a correct
image, while correlation over 3880 predictions is insensitive to that and
ruinous to anything actually broken. Case 2 guards it: without the same
mutation list in the same order, a correlation would be comparing unrelated
pairs and could still look fine.

### Verified against upstream, 2026-09-26

- MIT licence, read from `LICENSE` at the pinned commit;
- the checkpoints are **committed in the repo**, not downloaded:
  `models/thermoMPNN_default.pt` (38,894,003 bytes) and the vendored ProteinMPNN
  weights `vanilla_model_weights/v_48_{002,010,020,030}.pt` (6,681,301 bytes
  each), with `v_48_020.pt` the default. Both digests the recipe asserts were
  measured from a fresh clone at this ref;
- the non-torch dependencies, read from `pyproject.toml` and from every import
  in the repo: pandas, tqdm, torchmetrics, pytorch-lightning, omegaconf,
  joblib, biopython — and wandb, via the training module;
- the entry point and its four arguments (`--pdb`, `--chain`, `--model_path`,
  `--out_dir`), and that output is `ThermoMPNN_inference_<pdbid>.csv`;
- the reference output's shape: 3880 rows and the column list above;
- that `local.yaml` is committed with `/proj/kuhl_lab` and `/nas/longleaf`
  paths, and that `custom_inference.py` overwrites only `thermompnn_dir`.

**Not** verified, and left to the first run: how long a 154-residue chain takes
on each GPU model, and whether the `position` column's 0-based indexing is
relative to the parsed chain or to the file. `test.sh` compares against the
reference rather than interpreting the column, so the distinction does not
affect the test — but it affects anyone reading the CSV, which is why it is
called out under "Do not miss" rather than left here.
