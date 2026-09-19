# Chai-1

| | |
|---|---|
| Built | 2026-09-18, kanderson6, CoreHPC login node (716 s) |
| Image | `chai1_1.sif`, 3.47 GB — no weights |
| Recipe | [`chai1_1.def`](chai1_1.def) |
| Upstream | `chai_lab==0.6.1` (PyPI) |
| Weights | 6.2 GB on FAC, via [`fetch-weights.sh`](fetch-weights.sh) |
| Base | `python:3.12-slim` (torch 2.6.0+cu124) |
| Licence | Apache-2.0 — **code and weights** |
| GPU | yes — **not on Blackwell**, see below |

Licence note: the old non-commercial Chai Community License was replaced.
v0.6.1 is Apache-2.0 for the weights as well as the code, so this is usable
commercially and nothing here needs `chpc-assets`.

## What the test proves

`chpc-tool test chai1`: folds a 31-residue peptide end to end at
`--num-trunk-recycles 1 --num-diffn-timesteps 20 --num-diffn-samples 1`,
then asserts 31 CA records, numeric coordinates in every Cartesian column,
and a CA radius of gyration above 3 Å. Measured on an L40S: 47 s, 17.3 GB
peak RSS, spread 12.91 Å, pLDDT 82–89.

The spread check is the one that matters — it separates "wrote a CIF" from
"ran the diffusion module". ESM embeddings are left **on** (the default),
because that path is what needs the 5.6 GB trace and is the most likely
thing to be missing.

## Hardware: it cannot use the Blackwell nodes

`chai_lab` requires `torch<2.7`, so this image is torch 2.6.0+cu124.
Measured inside it:

```
torch._C._cuda_getArchFlags() -> sm_50 sm_60 sm_70 sm_75 sm_80 sm_86 sm_90
```

No `sm_120`. Use `--gres=gpu:nvidia_l40s:1` or an H100, never a bare
`--gres=gpu:1`.

Do **not** use `torch.cuda.get_arch_list()` to check this on a CPU node: on
torch 2.6 it returns `[]` when no GPU is present, which is indistinguishable
from a CPU-only build (doc 05).

## Weights: three parts, and the third is easy to miss

`fetch-weights.sh` gets all of it, ~6.2 GB:

1. six TorchScript components via `chai1_component()` — `feature_embedding`,
   `bond_loss_input_proj`, `token_embedder`, `trunk`, `diffusion_module`,
   `confidence_head`
2. `conformers_v1.apkl`
3. **a traced ESM-2 3B, 5.6 GB, from a different URL prefix**

Part 3 is fetched lazily on first use because `--use-esm-embeddings` defaults
to true. Following the component list alone gets a cache that looks complete,
passes a file count, and fails at the first real fold on a node with no
internet. It is easy to miss because chai-lab does **not** depend on
`fair-esm` or `transformers` — neither is installed — so searching the
environment for an ESM dependency finds nothing. It ships its own trace.
The registry's `esm` entry is unrelated and does not satisfy this.

## Traps

- **`CHAI_DOWNLOADS_DIR` must arrive as `APPTAINERENV_CHAI_DOWNLOADS_DIR`.**
  The image sets it as a `/tmp` fallback in `%environment`, and a plain host
  `export` loses to that — even though the image writes it defensively as
  `${VAR:-default}` (doc 07). `chpc-tool` emits both forms. This silently put
  1.3 GB in `/tmp` before it was found.
- Chai's downloader is `requests` with no retry and no resume, and it writes
  to a temp name it only renames on success — so a broken connection near the
  end of the 5.6 GB trace discards the lot. `fetch-weights.sh` uses `curl -C -`
  for that file and chai's own API for the small ones.
- **Do not filter substrate poses on ipTM.** Beta-strand addition is
  confidence-penalised, so an ipTM filter preferentially discards the correct
  extended geometry. ipTM is fine for Track 3 binder designs.
