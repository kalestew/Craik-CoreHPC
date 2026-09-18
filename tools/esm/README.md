# ESM-2

| | |
|---|---|
| Built | 2026-09-18, kanderson6, CoreHPC login node (1045 s) |
| Image | `esm_2.sif`, 5.15 GB — weights included |
| Recipe | [`esm_2.def`](esm_2.def) |
| Upstream | `fair-esm==2.0.0` (PyPI) |
| Models | `esm2_t33_650M_UR50D`, `esm2_t30_150M_UR50D`, + contact-regression heads |
| Base | `pytorch/pytorch:2.14.0-cuda13.2-cudnn9-runtime` |
| Licence | MIT |
| GPU | yes — CUDA 13.2 base, so **any** `gpu` node including sm_120 |

## What the test proves

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

## Why the weights are baked in

The opposite of what `rfdiffusion` and `boltz` do here, for three reasons:

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
- `ENTRY=python`, so `chpc-tool exec esm -- -c "…"` works, but a bare script
  path does not get an interpreter prepended. Spell out `python` when handing
  it a `.py`.
