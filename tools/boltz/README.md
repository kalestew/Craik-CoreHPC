# Boltz-2

| | |
|---|---|
| Built | `boltz_2` 2026-09-19, kanderson6, CoreHPC login node (747 s) · `boltz_2_gcc` **not yet built** |
| Image | `boltz_2_gcc.sif` — `boltz_2.sif` was 4.08 GB, no weights; gcc adds ~130 MB |
| Verified | `boltz_2` 2026-09-19 on an H100 NVL (cc 9.0) **and** an RTX PRO 6000 (cc 12.0), **kernels off in all but name** — see below · `boltz_2_gcc` **not yet** |
| Recipe | [`boltz_2_gcc.def`](boltz_2_gcc.def) · previous [`boltz_2.def`](boltz_2.def) |
| Upstream | `boltz[cuda]==2.2.1` (PyPI) |
| Weights | 5.0 GB on FAC, via [`fetch-weights.sh`](fetch-weights.sh) |
| Base | `python:3.12-slim` (torch 2.14.0+cu130) |
| Licence | MIT |
| GPU | any `gpu` node **without** the kernels (measured on all three classes). With them: **never run on any device**, because until this rebuild no image could compile them. |

Base is `python:3.12-slim` rather than a `pytorch/pytorch` tag because boltz
2.2.1 pins `numpy<2.0` *and* `python<3.13`, and the current pytorch images
ship 3.13. Letting pip resolve torch inside a 3.12 base is the only
combination that satisfies all three.

## The 2026-09-25 rebuild: a C compiler

`boltz_2.sif` has no C compiler, and boltz's cuequivariance kernels are
**Triton**, which JIT-compiles them at first use — inside the job, on the
compute node. So any prediction large enough to reach the kernel path died in
about four seconds with

```
triton/runtime/build.py
  RuntimeError: Failed to find C compiler.
```

having written nothing. Measured on an L40S 2026-09-22: 31 aa and 71 aa fold,
142 aa does not, one chain or two — the boundary is total token count and lies
between them. Corroborated independently by array `1928395` in IgGase-eng,
which lost all five tasks in under a minute each to the same error.
`--no_kernels` is the supported escape hatch, costs speed only, and is what
every Boltz-2 fold in this lab has used so far.

`boltz_2_gcc.def` adds `gcc` and `libc6-dev`. Not `build-essential`: Triton
compiles a C launcher, not C++, and `cc` is what it looks for. (openfold3 needs
the bigger set because DeepSpeed's op builder also wants `nvcc` and `ninja`.)

Two things come with it, both learned from openfold3, which hit this first:

- **`%post` builds a real shared object**, rather than checking `command -v
  gcc`. Triton compiles its launcher *against `Python.h`*, so a base that ships
  the interpreter without its headers fails at exactly the same place, at
  exactly the same point in a job, as a base with no compiler at all.
- **`TRITON_CACHE_DIR=/tmp/triton-cache`**, for the same reason
  `NUMBA_CACHE_DIR` exists. The default is `~/.triton/cache`: one directory on
  a 20 GiB shared home that every concurrent array task writes into at once.
  The `gpu` partition allows 8 GPUs per user and array tasks count
  individually, so that is the normal case, not the edge one. `/tmp` is
  node-local NVMe, so it is also the cache that actually gets *reused* — eight
  tasks on one node compile once between them instead of eight times.

### What "verified on Blackwell" does and does not mean

The `any gpu node` claim on this entry has always rested on job `1899088`
(`ggpu1-19`, compute capability 12.0). That job folded **the 31-mer** — below
the boundary above, so it never reached a Triton kernel. It measured *torch* on
sm_120, which is real and still true, and it measured nothing about
cuequivariance.

That is not a Blackwell-specific gap, and it is worth being exact about how
wide it is: because 31 aa and 71 aa never reach a kernel and 142 aa died
building one, **the cuequivariance Triton path has never successfully run on
any device here** — not on an L40S, not on an H100. No image that could
compile it existed until this one. So `test.sh` case 2 is the first evidence of
any kind, and the Blackwell run is the second. `test.sh` case 2 on
`--gres=gpu:nvidia_rtx_pro_6000:1` settles it. If it fails, this entry gains
its first `GPU_MAX_CC` and boltz stops being the one tool in the registry that
runs anywhere — which is a real cost under a 21-job cap, and is why it is worth
measuring before a campaign rather than during one.

### The baseline to beat

Job `1986189`, L40S: the full 658-token covalent peptide-MHC plus Fv at
`--use_potentials --no_kernels --diffusion_samples 5 --recycling_steps 3
--sampling_steps 200 --seed 1`, MSAs from disk, **240 s wall**, exit 0.

Kernels on is a *different computation*, not simply a faster one — it rides
inside this project's `computation_digest` — so a fold made with them cannot be
cited for one planned without them. Measure the speedup against that number
before re-folding anything against it.

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

Measured, job 1899084 on an H100 NVL:

```
ok: 31 CA atoms in in_model_0.pdb, CA spread 12.92 A
PASS boltz
```

The bare-`pip install boltz` image passed `%post`, `%test` and `--help` and
failed *here*. Nothing cheaper than a real fold would have caught it.

Repeated on a Blackwell node (job 1899088, `ggpu1-19`, compute capability
12.0) with the identical result. That is what makes the "any `gpu` node"
row above a measurement rather than an inference from arch flags — boltz is
the only GPU tool in the registry that has actually been run on Blackwell,
and the only one that does not declare a `GPU_MAX_CC`.

The image adds ~700 MB over the non-`[cuda]` build (3.37 → 4.08 GB); that is
the three `cuequivariance` wheels.

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
- **Triton's cache has the same problem one layer down**, and a worse blast
  radius under an array. `TRITON_CACHE_DIR` is set in `%environment` for the
  reasons above. If a job dies on `libcuda` rather than on a missing compiler,
  that is Triton failing to *link* its launcher, not to build it: a driver bind
  often provides `libcuda.so.1` without the `libcuda.so` symlink. Point
  `TRITON_LIBCUDA_PATH` at the driver directory, or fall back to
  `--no_kernels`.
