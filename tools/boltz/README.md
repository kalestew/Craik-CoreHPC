# Boltz-2

| | |
|---|---|
| Status | built 2026-09-25: `boltz_2_gcc.sif`, rebuilt with a C compiler; `chpc-tool test boltz` passed on an L40S the same day (job 1997376, `ggpu1-08`, both cases, kernels on); the speedup was measured 2026-09-26 (job 2001087: 225 s with the kernels against 230 s without, same node, same hour, 658 tokens); Blackwell still to measure (Provenance). Its predecessor `boltz_2.sif` was verified 2026-09-19 on an H100 NVL (job 1899084) and an RTX PRO 6000 (job 1899088), kernels off, and qualified at 658 tokens on an L40S (job 1986189, `--no_kernels`). What the gcc image still has to prove: Provenance |
| Image | `boltz_2_gcc.sif`, no weights (`boltz_2.sif` was 4.08 GB; gcc adds about 130 MB); recipe [`boltz_2_gcc.def`](boltz_2_gcc.def). [`boltz_2.def`](boltz_2.def) is kept: every Boltz-2 number this lab holds was produced with it |
| GPU | `--gres=gpu:1`, any node, **with `--no_kernels`** (measured on all three classes). With the kernels on: measured on an L40S only (job 1997376); until Provenance records test case 2 passing on a Blackwell node, a kernels-on run asks for `--gres=gpu:nvidia_l40s:1` or `nvidia_h100_nvl:1` |
| Weights | 5.0 GB at `$BOLTZ_CACHE` (`$CHPC_LAB/data/boltz`), fetched by [`fetch-weights.sh`](fetch-weights.sh) |
| Licence | MIT |
| Upstream | `boltz[cuda]==2.2.1` (PyPI) |
| Base | `python:3.12-slim` (torch 2.14.0+cu130) |
| Built | `boltz_2` 2026-09-19, kanderson6, CoreHPC login node (747 s); `boltz_2_gcc` 2026-09-25, published to the share the same day |

## Run it

```bash
srun -p gpu --gres=gpu:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/boltz/run1 && cd "$_"   # in.yaml here; the same path is valid inside the container
eval "$(chpc-tool export boltz)"                          # $BOLTZ_CACHE in this shell, for the line below
chpc-tool exec boltz -- boltz predict in.yaml --cache "$BOLTZ_CACHE" --out_dir out \
    --use_potentials --no_kernels --diffusion_samples 5 --recycling_steps 3 --sampling_steps 200 \
    --seed 1 --output_format pdb
```

That is the qualified run's command (job 1986189). Against the image's own
defaults it turns potentials on (upstream asks for it), turns the kernels off
(this image cannot build them; "Do not miss"), raises `--diffusion_samples`
from 1 to 5, and seeds, which boltz otherwise does not do at all;
`--recycling_steps 3 --sampling_steps 200` are the defaults written out.
Upstream's AlphaFold-3-parity setting is `--recycling_steps 10
--diffusion_samples 25`, much slower; the recycling half was measured here and
changed nothing.

`--no_kernels` is on that line because the qualified run was on `boltz_2.sif`,
which could not build the kernels. `boltz_2_gcc.sif` can, and has on an L40S
(job 1997376, 2026-09-25: 213 residues in 36 s). It is still on the line
because of what dropping it buys: on the 658-token baseline complex the
kernels saved 5 s of 230 (job 2001087, 2026-09-26, same L40S, same hour) and
changed the confidence in the third decimal, while `--no_kernels` on this
image reproduced the old image's numbers exactly ("The baseline to beat",
under Provenance). Drop it on an L40S if you want the 2%, and know that a
fold made with the kernels cannot be cited for one planned without them; on
any other node class wait until Provenance records case 2 passing there.

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines
to the values above (boltz is its shipped example). The method, the `eval`
idiom and which GPU to ask for:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

**Input** is boltz's YAML. The self-test's, single-sequence:

```yaml
version: 1
sequences:
  - protein:
      id: A
      sequence: MKTAYIAKQRQISFVKSHFSRQLEERLGLIE
      msa: empty
```

`msa: empty` is boltz's explicit single-sequence mode. For a real MSA give its
path instead: the qualified run was fed MSAs from disk, precomputed on the
login node, because `--use_msa_server` cannot reach its server from a compute
node. A covalent bond is a `constraints:` block whose residue references are
1-based offsets into the sequence string you supplied, with every chain
renumbered from 1; the shared story and the geometry checker:
[`../covalent-bonds.md`](../covalent-bonds.md).

**Output** lands under `out/` (`find out -name '*_model_0*'`), one file per
draw named `<input>_model_<i>.pdb`. **Ranked:** boltz sorts the draws on
`confidence_score` and writes the best as `_model_0`, so raising
`--diffusion_samples` improves the model you keep, not just the ensemble.
`--output_format pdb` preserves a covalent bond: the qualified run's PDB
carries 46 connectivity records and the SG–C25 bond is one of them, so a
PDB-only pipeline does not lose the chemistry.

Before trusting a number: `--use_potentials` is a bias, not a guarantee. On
the p1b7_8udr benchmark it moved the covalent SG-to-warhead distance from
1.21–1.44 Å to 1.36–1.72 Å against 1.76 Å in the deposited complex, and did
not move the dock (MHC/VH DockQ 0.025–0.026 either way); two of eight
potentials-on draws were still below the covalent floor (0.81 Å, and 1.359 Å
in job 1986189), physically impossible separations that ipTM rated 0.86–0.89.
Check the geometry of every draw you keep, not only `_model_0`. The affinity
head is ligand-only and capped at 128 atoms; it says nothing about a peptide
substrate.

## Do not miss

- **The kernels need a C compiler in the image, at run time.** `boltz_2_gcc.sif` has one; `boltz_2.sif` did not, and on it anything above about 128 tokens died four seconds in with `RuntimeError: Failed to find C compiler`, having written nothing (measured 2026-09-22 on an L40S: 31 and 71 residues predict, 142 fail). On that image, or any `-slim` rebuild, `--no_kernels` every time; it costs 2% of wall on a 658-token complex (Provenance) and does not conflict with `--use_potentials`. The kernel path has run on an L40S (job 1997376) and never on a Blackwell node: with a bare `--gres=gpu:1`, keep `--no_kernels` until Provenance says otherwise.
- **A job that dies on `libcuda` rather than on a compiler** is Triton failing to link its launcher, not to build it. Point `TRITON_LIBCUDA_PATH` at the driver directory, or fall back to `--no_kernels` (Traps).
- **`BOLTZ_CACHE` must be absolute, and it is only in your shell after `eval "$(chpc-tool export boltz)"`.** boltz resolves `--cache` against the working directory; a relative or empty value is a different, empty cache and an attempt to download 5 GB from a node with no internet.
- **`--use_msa_server` cannot reach its server** from a compute node. Precompute MSAs on the login node, or `msa: empty`.
- **Every chain is renumbered from 1.** Constraint references are 1-based offsets into the sequence string you supplied; map back to the project's numbering explicitly.
- **Do not rank peptide substrates with the affinity head.** It is ligand-only and capped at 128 atoms.
- **Potentials bias the geometry; they do not guarantee it.** Run the checker on every draw you keep.

---

## Provenance

`boltz_2.sif` built 2026-09-19 by kanderson6 on the CoreHPC login node (747 s);
`boltz_2_gcc.sif` rebuilt 2026-09-25 from [`boltz_2_gcc.def`](boltz_2_gcc.def)
and published to the share the same day. Everything measured below was measured
on `boltz_2.sif` unless it says otherwise.

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
row above a measurement rather than an inference from arch flags. boltz
declares no `GPU_MAX_CC`; neither do esm, ligandmpnn and proteinmpnn, whose
images also carry `sm_120` (`docs/05`, the arch-flags table).

That 31-mer was too small to prove the kernels work. Measured 2026-09-22 on an
L40S: 31 aa and 71 aa predict with the kernels on, 142 aa fails, and so does
every larger input; one chain or two makes no difference (2 × 71 and 1 × 142
both fail, at 142 total tokens), so the boundary is total token count and lies
between 71 and 142. The self-test passed while every real job died. `test.sh`
now carries a second case, 213 residues with the kernels on, that reaches the
kernel path. No run of that case is recorded; on this image, which has no
compiler, it is expected to fail with `Failed to find C compiler` until the
image is rebuilt with gcc, and `chpc-tool doctor boltz` reports the missing
compiler as a caveat rather than a failure. The consolidated trap and its
other three forms: [`docs/07`](../../docs/07-containers-apptainer.md), "A
kernel that compiles at first use needs a compiler in the image".

Qualified 2026-09-25, job 1986189 on an L40S: the full covalent peptide-MHC
plus Fv (658 tokens) at the "Run it" flags, MSAs from disk, container under
`--net --network none`. 240 s wall, 5 models, exit 0. Potentials and
`--no_kernels` do not conflict, and `--output_format pdb` preserves the
covalent bond.

Sampling defaults were read from the built image's click parameters
2026-09-25, not from `--help`, which disagrees with itself (the help string
for `--subsample_msa` says "Default is True" while the parameter default is
False): `recycling_steps 3`, `sampling_steps 200`, `diffusion_samples 1`,
`step_scale` None (the model picks: 1.638 for boltz1, 1.5 for boltz2), `seed`
None, `max_msa_seqs 8192`, `subsample_msa False`, `max_parallel_samples 5`.
`diffusion_samples 1` is the outlier in this registry: chai1, protenix and
alphafold3 all default to 5, as does boltz's own affinity head.

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
cited for one planned without them.

**Measured 2026-09-26, job 2001087, `ggpu1-08` (L40S), `boltz_2_gcc.sif`,
the same `input.yaml` and MSAs, the same flags, the two runs back to back:**

| run | wall | model_0 confidence | ptm | iptm | complex pLDDT |
|---|---|---|---|---|---|
| kernels on | 225 s | 0.9580 | 0.9487 | 0.9352 | 0.9637 |
| `--no_kernels` | 230 s | 0.9618 | 0.9607 | 0.9492 | 0.9650 |
| job 1986189, `boltz_2.sif`, `--no_kernels`, `ggpu1-06` | 240 s | 0.9618 | 0.9607 | 0.9492 | 0.9650 |

So the kernels bought 2% of wall on this complex, and `--no_kernels` on the
gcc image reproduces the old image's fold to four decimals of every
confidence metric: the lab's existing Boltz-2 numbers are reproducible on
`boltz_2_gcc.sif` with the flag kept. Nothing needs re-folding for speed.
The kernels-on log carries cuequivariance's
`Generic kernel expects bias to be float32` warning, which says the
triangle-attention kernel took its generic path; whether a tuned path exists
for this shape was not pursued.

### What the gcc image still has to prove

Three measurements before this entry says `verified` again, per `tool.conf`;
the first two were impossible before, because no image could compile the
kernels:

1. **Done 2026-09-25.** `chpc-tool test boltz` case 2 (213 residues, kernels
   on) passed on `boltz_2_gcc.sif`: job 1997376, `ggpu1-08`, NVIDIA L40S
   sm_89, `kernel path exercised ... 213 CA atoms in big_model_0.pdb, 36 s`,
   both cases PASS, 81 s wall for the whole test. On `boltz_2.sif` the same
   case fails, which is why that image was `verified` with a test that does
   not pass: the case was added after the qualification it postdates.
2. The kernel path on a Blackwell node: case 2 on
   `--gres=gpu:nvidia_rtx_pro_6000:1`. If it fails, this entry gains its first
   `GPU_MAX_CC` and boltz stops being the tool that runs anywhere.
3. **Done 2026-09-26.** The speedup against the baseline above: 225 s with
   the kernels against 230 s without, paired on one L40S (job 2001087), and
   240 s for the original run on `boltz_2.sif`. Two per cent, and a
   different fold in the third decimal of the confidence.

## Build notes

Base is `python:3.12-slim` rather than a `pytorch/pytorch` tag because boltz
2.2.1 pins `numpy<2.0` *and* `python<3.13`, and the current pytorch images
ship 3.13. Letting pip resolve torch inside a 3.12 base is the only
combination that satisfies all three.

### The `[cuda]` extra is not optional

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

The image adds ~700 MB over the non-`[cuda]` build (3.37 → 4.08 GB); that is
the three `cuequivariance` wheels.

### The 2026-09-25 rebuild: a C compiler

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

## Traps

- **`boltz_2.sif` has no C compiler, so on it the kernels cannot JIT.** The
  `[cuda]` extra above makes the kernels importable; building them at first
  use is Triton's job, and Triton shells out to `cc`, which `python:3.12-slim`
  with only `git` and `ca-certificates` does not have. Any prediction above
  about 128 total tokens dies with `RuntimeError: Failed to find C compiler`
  from `triton/runtime/build.py`. `--no_kernels` every time on that image;
  `boltz_2_gcc.sif` exists to fix it (Build notes).
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
- **No seed unless you pass one.** `seed` defaults to None, which is no
  seeding at all; `--seed` is the only way to make two runs comparable.
- numba caches JIT output beside its source, which a squashfs forbids;
  `NUMBA_CACHE_DIR` is set in `%environment` (doc 07).
- **Triton's cache has the same problem one layer down**, and a worse blast
  radius under an array. `TRITON_CACHE_DIR` is set in `%environment` for the
  reasons above. If a job dies on `libcuda` rather than on a missing compiler,
  that is Triton failing to *link* its launcher, not to build it: a driver bind
  often provides `libcuda.so.1` without the `libcuda.so` symlink. Point
  `TRITON_LIBCUDA_PATH` at the driver directory, or fall back to
  `--no_kernels`.
