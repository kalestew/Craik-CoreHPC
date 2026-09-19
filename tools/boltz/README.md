# Boltz-2

| | |
|---|---|
| Built | 2026-09-19, kanderson6, CoreHPC login node (844 s for the first build) |
| Image | `boltz_2.sif`, 3.37 GB — no weights |
| Recipe | [`boltz_2.def`](boltz_2.def) |
| Upstream | `boltz[cuda]==2.2.1` (PyPI) |
| Weights | 5.0 GB on FAC, via [`fetch-weights.sh`](fetch-weights.sh) |
| Base | `python:3.12-slim` (torch 2.14.0+cu130) |
| Licence | MIT |
| GPU | yes — `sm_120` present, so **any** `gpu` node |

Base is `python:3.12-slim` rather than a `pytorch/pytorch` tag because boltz
2.2.1 pins `numpy<2.0` *and* `python<3.13`, and the current pytorch images
ship 3.13. Letting pip resolve torch inside a 3.12 base is the only
combination that satisfies all three.

## The `[cuda]` extra is not optional

`pip install boltz` produces an image that imports cleanly, passes `--help`,
passes a `%test`, downloads its weights — and cannot predict anything:

```
boltz/model/layers/triangular_mult.py:22
  from cuequivariance_torch.primitives.triangle import ...
ModuleNotFoundError: No module named 'cuequivariance_torch'
```

`cuequivariance_ops_cu12`, `cuequivariance_ops_torch_cu12` and
`cuequivariance_torch` live in boltz's `cuda` extra, and boltz enables those
kernels **by default** — `main.py:1321` is `use_kernels=not no_kernels`. The
import is unguarded and there is no fallback, so the failure arrives mid-batch
on the first real prediction.

This is the clearest example in the registry of why `%test` is not enough.
`%post` cannot see what only the built image sees (the read-only class,
doc 07); `%test` cannot see what only a GPU run sees. The check that caught
this is the one that folds an actual peptide.

`boltz predict --no_kernels` is the escape hatch if the cu12 extra ever stops
pairing with a cu13 torch. It costs speed, nothing else. `%post` imports
`cuequivariance_torch` and the kernel path explicitly so that pairing breaks
the build rather than a job.

## What the test proves

`chpc-tool test boltz`: folds a 31-residue peptide with `msa: empty`,
asserting 31 CA atoms, finite coordinates, and a CA radius of gyration above
3 Å — the check that separates "wrote a PDB" from "ran the diffusion module".

## Traps

- **`BOLTZ_CACHE` must be absolute.** boltz resolves `--cache` against the
  working directory, and several stages here `cd` before running (because
  `cartesian_ddg` and hydra apps write to cwd). A relative cache means a job
  silently uses a different, empty one and tries to download 5 GB from a node
  with no internet. Both the fetch script and the test refuse a relative path.
- **Do not delete `mols.tar` after extraction.** It looks like 1.86 GB of
  duplication next to `mols/`, but `download_boltz2` tests the two
  independently and `boltz predict` calls it on *every* run. Remove the tar
  and every job tries to re-fetch it — while the cache still looks complete
  to anyone counting checkpoints.
- **`--use_msa_server` queries a remote MMseqs2 API** that compute nodes
  cannot reach. Precompute MSAs, or use `msa: empty` for single-sequence.
- **Do not rank peptide substrates with the affinity head** — it is
  ligand-only and capped at 128 atoms.
- **Boltz renumbers every chain from 1** and has no way to express input
  numbering; its constraint references are 1-based offsets into the sequence
  string you supply. Map back to EU numbering explicitly.
- numba caches JIT output beside its source, which a squashfs forbids;
  `NUMBA_CACHE_DIR` is set in `%environment` (doc 07).
