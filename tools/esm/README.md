# ESM-2

| | |
|---|---|
| Status | verified 2026-09-26 on an L40S (`ggpu1-08`, job 2000973), 12 s, and 2026-09-26 on `gcpu2-33` (CPU, job 2000974), 11 s: `chpc-tool test esm`, logits (1, 33, 33), mean logP -0.440 on both. An earlier pass on `ccpu1-01` went undated |
| Image | `esm_2.sif`, 5.15 GB — weights included; recipe [`esm_2.def`](esm_2.def) |
| GPU | `--gres=gpu:1`, any node (CUDA 13.2 base, `sm_120` present); CPU works, slower |
| Weights | in the image at `/opt/torch/hub/checkpoints/`: `esm2_t33_650M_UR50D`, `esm2_t30_150M_UR50D` and their contact-regression heads. Nothing under `$CHPC_LAB/data`, nothing fetched at run time |
| Licence | MIT |
| Upstream | `fair-esm==2.0.0` (PyPI), the archived `facebookresearch/esm` |
| Base | `pytorch/pytorch:2.14.0-cuda13.2-cudnn9-runtime` |
| Built | 2026-09-18, kanderson6, CoreHPC login node (1045 s) |

## Run it

There is no command-line program: you hand `python` a script. The block below
is `test.sh` with the production model in place of the small one and the
tensors moved to the GPU when there is one (those two changes are untested;
the test ran the same code on the 150M model on a CPU node).

```bash
srun -p gpu --gres=gpu:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l   # or salloc -p cpu -c 8 --mem 16G -t 2:00:00
mkdir -p /mnt/scratch/user/$USER/esm/run1 && cd "$_"                # the same path is valid inside the container
chpc-tool exec esm -- python - <<'PY'
import torch, esm

model, alphabet = esm.pretrained.esm2_t33_650M_UR50D()   # production; the test uses esm2_t30_150M_UR50D for speed
model.eval()
dev = "cuda" if torch.cuda.is_available() else "cpu"
model = model.to(dev)
bc = alphabet.get_batch_converter()

seq = "MKTAYIAKQRQISFVKSHFSRQLEERLGLIE"
_, _, toks = bc([("p", seq)])
toks = toks.to(dev)

with torch.no_grad():
    out = model(toks, repr_layers=[33])                   # t33 = 33 layers; the test asks for layer 30 of the t30

logits = out["logits"]                                    # (1, len+2, 33): BOS and EOS bracket the sequence
rep = out["representations"][33]                          # (1, len+2, 1280): per-residue embedding
lp = torch.log_softmax(logits[0, 1:-1], dim=-1)
avg = lp[range(len(seq)), toks[0, 1:-1]].mean().item()
print(f"mean logP {avg:.3f}, repr {tuple(rep.shape)}")
PY
```

A script of your own is `chpc-tool exec esm -- python my_script.py`, with
`python` spelled out (Do not miss). As a job: copy
`templates/slurm/tool-gpu.sbatch`, set its four EDIT lines to the values
above (`--gres=gpu:1` is safe for this image) and put the heredoc after the
`--`. The method, the `eval` idiom and which GPU to ask for:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

Input is whatever your script reads: a list of `(name, sequence)` pairs to the
batch converter, one-letter amino-acid strings, no FASTA parser provided. For
per-sequence embeddings from a FASTA without writing Python, `fair-esm`
installs `esm-extract`:
`chpc-tool exec esm -- esm-extract esm2_t33_650M_UR50D in.fasta out --repr_layers 33 --include mean per_tok`
writes one `out/<name>.pt` per record (untested here).

Output is whatever your script prints or saves; nothing is written unless you
write it, and nothing is ranked. The test's reference point, on the 150M model
and the 31-mer above: logits `(1, 33, 33)`, representations `(1, 33, 640)`,
mean log-likelihood **-0.440**, against roughly -3.5 for a model predicting
uniformly. The 650M's hidden size is 1280, so its representations are
`(1, 33, 1280)` (untested).

Before trusting a number: the score above reads each position's logit with
that residue visible. The masked pseudo-log-likelihood in the literature masks
one position per forward pass (L passes for a sequence of length L) and comes
out lower; compare like with like, and say which one you computed. The
650M is the model the lab's naturalness scoring is wired for; the 150M is for
smoke tests only.

## Do not miss

- **This is ESM-2 via `fair-esm`, not the PyPI `esm` package.** That one is
  EvolutionaryScale's ESM-3/ESM-C and carries no ESM-2 at all; `pip install
  esm` anywhere near this is the wrong model (Traps).
- **Spell out `python` before a `.py`.** `ENTRY=python` is prepended only in
  front of a flag, so `chpc-tool exec esm -- -c "…"` works but
  `chpc-tool exec esm -- my_script.py` hands apptainer a script to execute
  and fails with `permission denied`, no mention of an interpreter.
- **Nothing is fetched at run time; that is the point of the 5 GB image.**
  `TORCH_HOME=/opt/torch` inside the container points `esm.pretrained.*` at
  the two baked-in checkpoints. Any other `esm.pretrained.*` model (the 3B,
  the 15B) is not in the image and will try to download, which a compute
  node cannot do ([`docs/02`](../../docs/02-storage-and-data.md#internet-access)).
- **Any `gpu` node is fine, and so is the CPU partition.** The image carries
  `sm_120`; a bare `--gres=gpu:1` lands anywhere and runs. The 650M forward
  pass on a CPU node is slower, not wrong.

---

## Provenance

Built 2026-09-18 by kanderson6 on the CoreHPC login node (1045 s).

`chpc-tool test esm`: loads `esm2_t30_150M_UR50D`, runs a forward pass over a
31-residue sequence and asserts the logit and representation shapes, that
every value is finite, and that the mean per-residue log-likelihood is in a
plausible band. Measured on ccpu1-01: logits `(1, 33, 33)`, representations
`(1, 33, 640)`, mean logP **-0.440** — against roughly -3.5 for a model
predicting uniformly, so this catches a model that loaded but is untrained or
mis-wired, not just one that failed to import.

**The test was run on a compute node on purpose.** Compute nodes reach a proxy
that denies everything we need (doc 02), so a pass there is direct evidence
that nothing is fetched at run time — which is the entire justification for
the image being 5 GB.

The 650M is asserted present but not loaded; loading it too would only re-test
torch. `chpc-tool doctor esm` does load it.

## Build notes

Why the weights are baked in: the opposite of what `rfdiffusion` and `boltz`
do here, for three reasons:

- **`esm2_t33_650M_UR50D` is frozen.** A 2022 release that will never be
  revised, so "a weights refresh should not force an image rebuild" — the
  argument for keeping RFdiffusion's 3.7 GiB outside — does not apply.
- **`TORCH_HOME` is a shared name.** fair-esm fetches through `torch.hub`,
  so pointing ESM at a weights directory from the registry would mean
  exporting `TORCH_HOME` into the job environment, redirecting `torch.hub`
  for every *other* tool in the same script. Baking the files in lets ESM
  need no environment at all; `TORCH_HOME=/opt/torch` is set in the def's
  `%environment`, where it cannot leak outward.
- MIT, so redistribution inside a lab image is unencumbered.

## Traps

- **This is ESM-2, not ESM-3 or ESM-C, and the split is now also a rename.**
  `fair-esm` 2.0.0 is the final release of the archived
  `facebookresearch/esm` and the only source of ESM-2 — which is what
  pseudo-likelihood scoring in the literature means. EvolutionaryScale was
  acquired by Chan Zuckerberg Biohub in Nov 2025, so `evolutionaryscale/esm`
  now redirects to `Biohub/esm`; the PyPI package `esm` (3.4.1) carries
  ESM-C/ESM-3 and **no ESM-2**. Its licence is now plain MIT — the old
  non-commercial community licence is gone — but it is still a different
  model and belongs in its own registry entry. Do not conflate them.
