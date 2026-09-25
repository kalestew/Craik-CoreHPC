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

## Templates: fixed in chai1_2, and the hit range is kalign's to decide

Measured 2026-09-24, in both images, with networking disabled.

**`chai1_2.sif` fixes this and templates now load.** What follows is what
`chai1_1.sif` did, kept because the second half of it is still true.

Chai-1's template input is a **search result**, not a structure:
`--template-hits-path` takes a BLAST-m8 table and `--use-templates-server`
fetches one. Given a hit, `parse_m8_to_template_hits` resolves the structure
itself and then realigns it to the query with **kalign**:

```
AssertionError: kalign is required for templates, but was not found in PATH.
Try 'apt install kalign'?
```

`command -v kalign` found nothing in `chai1_1.sif`, so templates could not run
there at all. `chai1_2.def` installs **kalign 3.4.0** from Debian trixie and the
rebuild invalidates this tool's prediction cache by design (`spec_id` folds in
`container_digest`).

The major version is load-bearing in one direction. `chai_lab` runs
`kalign -i in -o out --nthreads 1`, and `--nthreads` arrived in kalign 3. The
kalign that bioconda still ships as `kalign`, and that `colabfold_1.5.5.sif`
carries, is **2.04**, and it rejects that command line — measured against
colabfold's own binary. kalign 3.4.0 also accepts the older `-format fasta` form
that protenix uses, so 3.x is a superset and both tools take it.

The failure is silent: `kalign_query_to_reference` catches `CalledProcessError`
and returns `None`, the hit is dropped, and the fold exits zero having used no
templates. `%test` therefore calls `chai_lab`'s own function and asserts on the
alignment it returns, not on `command -v kalign`.

Two other template facts worth having before that rebuild, both read from the
installed package rather than from documentation:

- **The CIF cache is offline-able, and the naming is exact.** The loader calls
  `rcsb.download_cif_file(hit_identifier.upper(), directory=...)`, which resolves
  `<dir>/<PDBID>.cif.gz` and downloads **only if that path does not exist**. The
  directory is not a flag: it is `<output_dir>/templates`, fixed in `chai1.py`.
  Staging `8VRA.cif.gz` there under exactly that upper-case name is what makes a
  templated fold possible on a compute node. Lower-case, or `.cif`, and the job
  reaches for `files.rcsb.org` and hangs.
- **The hit table is tab-delimited, and the restraints file next door is not.**
  `parse_m8_file` passes `delimiter="\t"`; the restraints reader passes no `sep`
  at all and therefore takes commas. The two files this one tool consumes
  disagree, and getting the restraints one wrong is what killed job 1976695.

### The hit range is a fixpoint of kalign's alignment, not a span you choose

`subject_start`/`subject_end` are counted over the template chain's **modelled**
residues — the loader strips gap characters out of gemmi's polymer sequence
before slicing — which is a different basis from the AlphaFold 3 dialect's, and
for a cryo-EM Fab the two differ by more than a hundred residues.

That is necessary and not sufficient. The loader slices
`seq[subject_start:subject_end]`, realigns **that slice** to the query with
kalign, and then `TemplateHit.__post_init__` refuses the hit unless the
alignment consumes the slice from its first residue to its last:

```
ValueError: query_pdb_id='H' <> pdb_id='8vr9' yields discrepant start/end
indices: 1 116 != 0 117 - 1.
```

So the admissible range is whatever kalign says it is. Measured on a
three-member related set, 15 chain hits: **11 began at the first modelled
residue and 4 did not**, because kalign left the template's leading residue
unaligned. Writing the obvious `subject_start=1` made Chai-1 reject those four
outright; correcting only those four made all 15 load.

Being *rejected* rather than silently dropped is the only piece of luck on this
surface — everywhere else on it, a template that cannot be reconciled just
vanishes. It also means the span cannot be derived on the coordinator: it has to
be computed in this image, where kalign is, in the same way the ligand atom
mapping is derived where RDKit is.
