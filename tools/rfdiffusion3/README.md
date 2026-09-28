# RFdiffusion3 (rc-foundry)

| | |
|---|---|
| Status | verified 2026-09-27 on `ggpu1-10` (NVIDIA L40S) in 1 m 50 s, and on `ccpu1-04` (CPU) in 8 m 42 s — `chpc-tool test rfdiffusion3` designs a 60-residue backbone and then a 120-residue de novo scaffold around the P1B7 sotorasib-modified cysteine, with the covalent bond intact on both |
| Image | `rfdiffusion3_0.2.0.sif`, 3.65 GB, no weights inside; recipe [`rfdiffusion3_0.2.0.def`](rfdiffusion3_0.2.0.def) |
| GPU | `--gres=gpu:nvidia_l40s:1` or `--gres=gpu:nvidia_h100_nvl:1` (`GPU_MAX_CC=9.0`). Never a bare `--gres=gpu:1`. **Runs on CPU too**, correctly; the same test takes 1 m 50 s on an L40S against 8 m 42 s on 16 CPU cores |
| Weights | 5.7 GB at `$FOUNDRY_CHECKPOINT_DIRS` (`$CHPC_LAB/data/rfdiffusion3`) for the default `rfd3 rf3`; 14.6 GB if you ask for `all`. Fetched by [`fetch-weights.sh`](fetch-weights.sh) on the login node |
| Licence | BSD-3-Clause, code and weights; commercial use permitted |
| Upstream | `rosettacommons/foundry:0.2.0-slim`, `rc-foundry==0.2.0` |

## Run it

Two things are not optional, and both are about `ckpt_path` and hydra rather
than about design. They are explained under [Do not miss](#do-not-miss).

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/rfd3/run1 && cd "$_"
eval "$(chpc-tool export rfdiffusion3)"

# unconditional: a 200-residue monomer, 8 designs
chpc-tool exec rfdiffusion3 -- rfd3 design \
    inputs=null +specification.length=200 out_dir=out ckpt_path="$RFD3_CKPT"

# from a spec file: motifs, ligands, binders, symmetry
chpc-tool exec rfdiffusion3 -- rfd3 design \
    inputs=my-design.yaml out_dir=out ckpt_path="$RFD3_CKPT"
```

`RFD3_CKPT` comes from `chpc-tool export`; `exec` also sets
`FOUNDRY_CHECKPOINT_DIRS` inside the container. A job script is
`templates/slurm/tool-gpu.sbatch` with its four EDIT lines set to the above
([`../README.md`](../README.md#run-a-tool-on-your-inputs)).

**Upstream's full documentation is inside the image**, and it is good:

```bash
chpc-tool exec rfdiffusion3 -- sh -c 'cp -r /app/foundry/models/rfd3/docs .'
```

That gives you `input.md` (every `InputSpecification` field, the contig
mini-language, the CLI arguments), `examples/` with five worked JSON specs,
`input_pdbs/` with ten fixtures, and four tutorials. An earlier version of this
README said upstream documented no config keys and shipped only notebooks. That
was wrong — the docs were in the image the whole time.

## Inputs and outputs

One YAML or JSON file, mapping a design name to its constraints. Every field is
tabulated in upstream's `input.md`; the ones that come up most:

| Field | What it does |
|---|---|
| `input` | path to a PDB or CIF. Relative to your working directory |
| `contig` | indexed motif, `"A40-60,70,A120-170,/0,B3-45"`. Bare numbers are designed, `/0` is a chain break |
| `unindex` | motif whose **sequence position the model chooses**. What you want for an active site or an adduct |
| `length` | `"min-max"` or a single number, for the designed part |
| `ligand` | by CCD component name, `"MOV"` or `"NAI,ACT"` |
| `select_fixed_atoms` | dict of component to atoms: `ALL`, `BKBN`, `TIP`, or explicit names. `""` unfixes |
| `select_hotspots` | residues the design must contact. For binders |
| `partial_t` | Å of noise for partial diffusion, 5–15. Redesign around what is there |

Output per design is a pair, `<file>_<designname>_<batch>_model_<n>.cif.gz` and
`.json`. The JSON is worth reading before the structure: it carries the exact
specification used, the sampled contig, and **upstream's own design metrics** —
`n_chainbreaks`, `n_clashing.*`, `radius_of_gyration`, `helix_fraction`,
`insertion_rmsd`, `max_ca_deviation`. [`test.sh`](test.sh) asserts against those
rather than inventing criteria, and your own filtering should start there too.

Defaults give **8 designs** (`diffusion_batch_size=8`, `n_batches=1`) at 200
diffusion timesteps.

**This is not RFdiffusion, and not RFdiffusion2.** Three separate registry
entries on purpose: RFdiffusion3 has no repository of its own, ships as the
`rfd3` model inside `RosettaCommons/foundry`, and has a different CLI, different
weights and a different licence lineage from v1. v1 stays because the round-0
exosite track is written against its hydra config. foundry also provides `rf3`
(structure prediction) and `mpnn`; this entry exposes `rfd3`, and the others
would be separate entries with their own status and doctor check. `rf3` is the
one being worked towards: its weights are already fetched by default here, its
checkpoint is exported as `RF3_CKPT`, and a covalent input is prepared at
[`../../examples/p1b7/rf3.json`](../../examples/p1b7/rf3.json). It has not been
run, so it has no entry and no status.

## Covalent modifications

RFdiffusion3 handles them, and the way it handles them is the most important
thing on this page.

**There is no way to declare a covalent bond to RFdiffusion3.** No
`covalent_bonds`, no `bondedAtomPairs`, nothing in upstream's `input.md`. This
is a fact about `rfd3` and not about `rc-foundry`: the `rf3` predictor in this
same image accepts a declared `bonds` list, so do not carry this paragraph
across to it. See [`../covalent-bonds.md`](../covalent-bonds.md). The support is a transform,
`FlagAndReassignCovalentModifications`, that runs unconditionally in the
inference pipeline and works off **the bond list the parser produced from your
input file**. For every bond with one end in a polymer and the other in a
non-polymer it reassigns the whole bonded residue into the ligand's PN unit,
marks both for atomization, and flags them `is_covalent_modification`.

So the bond is whatever your file said. Measured on the deposited 8UDR
(2026-09-26, inside this image):

```
parsed 6393 atoms, chains ['A', 'B', 'C', 'D', 'E', 'F']
bond: MOV C25 -- CYS C6 SG  1.765 A
flagged 47 atoms = 41 ligand + 6 in the bonded cysteine
cysteine PN unit reassigned {'C_1'} -> {'F_1'}
```

Exactly one bond crosses the ligand boundary, it is the warhead carbon to the
sulfur, and it is at the deposited distance. Nothing had to be declared.

**The consequence is a trap with no warning.** Hand rfd3 a structure whose
`_struct_conn` record is missing — stripped by a converter, lost in a
PDB-format round trip, absent because you built the file yourself — and it sees
a free ligand floating near a cysteine. It will design happily, the metrics will
look fine, and nothing anywhere will say the adduct was not treated as one. This
is the failure that quarantined 1,726 Chai-1 results
([`../covalent-bonds.md`](../covalent-bonds.md)), reached by a different route.
**Check the output geometry every time**, which is what [`test.sh`](test.sh)
stage 4 does.

A committed, working example is
[`../../examples/p1b7/rfd3.yaml`](../../examples/p1b7/rfd3.yaml): scaffold a new
120-residue protein around the sotorasib-modified KRAS G12C cysteine.

## Do not miss

- **Pass `ckpt_path` as an absolute path. `ckpt_path=rfd3` does not work.**
  The image ships `/app/foundry/.env` pinning
  `FOUNDRY_CHECKPOINT_DIRS='/test-weights:/root/.foundry/checkpoints'`, and
  dotenv beats the environment, so a name resolves against `/test-weights` and
  dies with `AssertionError: Invalid checkpoint: rfd3. And could not find
  checkpoint in default installation location: /test-weights/rfd3_latest.ckpt`.
  `chpc-tool export rfdiffusion3` publishes `RFD3_CKPT` and `RF3_CKPT` for
  this. It is also the answer to why `foundry list-installed` reports nothing.
- **`specification.length=200` needs a leading `+`.** `specification` is an
  empty dict in `rfdiffusion3.yaml`, so hydra refuses to override a key that
  does not exist: `Could not override 'specification.length'. To append to your
  config use +specification.length=200`. Upstream's `input.md` writes it
  without the `+`. This applies to every `specification.*` override, not to
  `out_dir`, `inputs`, `ckpt_path` or `inference_sampler.*`.
- **It runs on the CPU, correctly, and tells you at ERROR level.**
  `No GPUs/XPUs/MPS available - Setting accelerator to 'cpu'`. Measured on
  `ccpu1-04` with 16 cores: a 60-residue design at 200 timesteps and a
  120-residue one with a 47-atom motif, together, took 8 m 42 s including
  loading 5.7 GB of checkpoints. No GPU timing has been taken here yet, so no
  ratio is quoted. What matters is that **nothing fails**: an sbatch that lost
  its `--gres` still produces correct designs, and only the wall clock
  complains.
- **Never read the `GPU information:` line as evidence of a GPU.**
  `cuequivariance_ops/triton/cache_manager.py` catches a pynvml failure and
  falls back to `default_map["NVIDIA RTX A6000"]`, then **prints** it. On a CPU
  node with no driver at all the log says
  `GPU information: NVIDIA RTX A6000, 8, 6, 45, 84, 300, 2100`. That is a
  hard-coded default, not your hardware.
- **`WRITABLE_TMPFS=1` is already set in `tool.conf`, and it is required.**
  Without it foundry dies mid-download with `OSError: [Errno 30] Read-only file
  system: '/app/foundry/.tmp_jyowbq10'` — an error that names neither `.env`
  nor dotenv nor configuration. The full story is in Traps; the thing to know
  is that a published `$CHPC_LAB/bin/rfdiffusion3` wrapper does not set the
  overlay, so use `chpc-tool exec`.
- **Pass `--checkpoint-dir` explicitly to `foundry install`.**
  `FOUNDRY_CHECKPOINT_DIRS` is a *search* path for reading; `install` on its
  own still defaults to `~/.foundry/checkpoints`, and home is 20 GiB here
  against ~14 GB of checkpoints.
- **L40S or H100 only.** torch 2.7.1+cu126 has no `sm_120`, so the Blackwell
  nodes `ggpu1-[13-19]` are out. `chpc-tool exec` refuses them up front; the
  `--gres` line is what decides where the job lands.
- **`unindex` renumbers your motif, differently every draw.** The cysteine
  given as `C6` came back as `A107` on one 120-residue design and `A119` on the
  next — that is what `unindex` means, the model choosing where in the new
  sequence to put it. Find it by geometry, never by residue number, and never
  assume two designs in the same batch agree.

---

## Provenance

### Verified 2026-09-26: a design runs, and it holds the covalent bond

`chpc-tool test rfdiffusion3` runs four stages at upstream's production
defaults, 200 diffusion timesteps and nothing turned down to make it quick.
Stage 2 designs a 60-residue monomer from nothing; stages 3 and 4 are the P1B7
case. Measured output of stage 4:

```
num_residues        120
ligand clashes      0   (min distance 3.42 A)
insertion_rmsd      0.474 A
MOV C25 -- nearest SG  1.770 A  (CYS A119)
ligand atoms nearest that SG: C25 1.77, C24 2.62, C23 3.72
chains in the output: ['A', 'F']
```

A de novo 120-residue backbone, with no chain breaks and no clashes anywhere
including against the ligand, holding a sotorasib adduct whose bond to the
designed cysteine is 1.770 Å against the deposited 1.765 Å. The nearest ligand
heavy atom to that sulfur is `C25` — the warhead carbon — and the second
nearest is 2.6 Å away, so the attachment is the intended one and not a
neighbouring carbon that happened to drift close.

The `insertion_rmsd` of 0.474 Å is upstream's own measure of how faithfully the
fixed motif was reproduced. The whole test took 8 m 42 s on `ccpu1-04` with 16
cores, almost all of it the two 200-timestep designs. No GPU timing has been
taken here, so this page quotes none.

Stage 2, the unconditional design, on the same run:

```
num_residues        60  (asked for 60)
n_chainbreaks       0
clashes bb/sc       0 / 0
radius_of_gyration  9.91 A
helix / loop        0.38 / 0.40
max_ca_deviation    0.051 A
CA-CA spacing       3.772 - 3.851 A over 59 bonds
```

The CA–CA assertion is the one that cannot be satisfied by a plausible-looking
metrics dictionary: a trans peptide fixes consecutive CA–CA at 3.80 Å, and that
is chemistry rather than a threshold chosen here.

### And on a GPU, 2026-09-27

The 8-GPU per-user cap was fully committed when the CPU run was made, so the
same test was queued and ran later on `ggpu1-10`:

```
node=ggpu1-10   NVIDIA L40S, 8.9, 595.71.05
accelerator: CUDA -- NVIDIA L40S (sm_89), torch 2.7.1+cu126 cuda 12.6
num_residues 60,  n_chainbreaks 0,  clashes 0/0,  Rg 9.84 A
max_ca_deviation 0.049 A,  CA-CA spacing 3.768 - 3.849 A
num_residues 120, ligand clashes 0 (min 3.25 A), insertion_rmsd 0.747 A
MOV C25 -- nearest SG  1.770 A  (CYS A16)
ok: both designs ran on CUDA (no accelerator fallback in either log)
```

**1 m 50 s against 8 m 42 s on 16 CPU cores**, and the last line is the one the
GPU run adds: stage 1 saw a CUDA device, so the test then required that neither
design fell back, and neither did. The covalent bond comes out at 1.770 Å on
both accelerators, which is the answer to the only question the CPU run left
open — whether the CUDA kernels in this torch build produce the same designs.

Stage 1 decides the accelerator, prints it, and names it again in the final `ok`
line precisely so that these two runs can be told apart in a log six months from
now.

### What was actually blocking this, and it was not the science

The entry sat at `built` since 2026-09-18 with a README saying there was no
known-good command because `rfd3 --help` documented no config keys and upstream
shipped notebooks rather than commands. The second half of that was wrong.
`/app/foundry/models/rfd3/docs/` is inside the image and contains `input.md`
with every field tabulated, five worked examples with their JSON and input PDBs,
and four tutorials. The CLI is a typer wrapper that passes its arguments
straight to hydra, so `--help` genuinely says nothing; the documentation was one
`find` away and the earlier conclusion came from asking the wrong thing.

Two real blockers, both trivial once seen: `ckpt_path=rfd3` resolving against
the image's baked `/test-weights` because dotenv beats the environment, and
hydra refusing `specification.length` without a `+` because `specification` is
an empty dict. Both are in [Do not miss](#do-not-miss).

### The 2026-09-18 build record

Built by kanderson6 on the CoreHPC login node (1172 s), from upstream's own
`0.2.0-slim` image rather than a pip install into a pytorch base.

Hardware, measured inside the image rather than inferred from the tag:

```
torch 2.7.1+cu126
torch._C._cuda_getArchFlags() -> sm_50 sm_60 sm_70 sm_75 sm_80 sm_86 sm_90
```

No `sm_120`. The newest tool in the registry, on the newest CUDA base of any
GPU tool here, still cannot run on `ggpu1-[13-19]` — CUDA 12.6 predates
Blackwell, and "recent tool" is not "recent enough CUDA".

Taken on trust: that what `foundry install` downloads is what upstream intends.
The fetch asserts on the artefacts — at least two checkpoint files, none empty
— because upstream publishes no checksums to assert against.

## Build notes

Built on upstream's own slim image rather than pip-installing `rc-foundry` into
a pytorch base. Two reasons: foundry pins python >=3.12,<3.13 together with
cuequivariance CUDA-12 wheels, a combination that is fiddly to reproduce and
that upstream has already solved; and `slim` (3.47 GB) is the variant *without*
checkpoints, which is what we want — the weights belong on FAC, where
refreshing them does not mean rebuilding an 18 GB image. `%post` therefore
asserts what we depend on (the four console scripts, python 3.12) instead of
reinstalling it, so a future tag that moves them fails the build rather than a
design job.

### Weights

```bash
tools/rfdiffusion3/fetch-weights.sh              # rfd3 + rf3, 5.7 GB
tools/rfdiffusion3/fetch-weights.sh rfd3na       # add the nucleic-acid model
tools/rfdiffusion3/fetch-weights.sh --fixture    # only the 8UDR test fixture
```

Default is `rfd3 rf3`, **not `all`**. `all` is 14.6 GB and also pulls foundry's
own ProteinMPNN, LigandMPNN and SolubleMPNN — which this registry already
carries as separate entries with their own pinned commits. Two copies of the
same weights under different provenance is how a result stops being
reproducible.

Valid names, from `foundry list-available`: `rfd3` `rfd3na` `rf3`
`proteinmpnn` `ligandmpnn` `solublempnn` `rf3_preprint_921`
`rf3_preprint_124` `all`.

`base-models` is valid too — it is what upstream's README recommends — but it
appears in **neither** `foundry install --help` nor `list-available`, so the
CLI gives no sign it exists. `download_checkpoints.py:175` expands it to
`rfd3 rfd3na proteinmpnn ligandmpnn rf3`. I initially concluded from the CLI
that it was not a real target; it is, and the documentation was right where the
tool's own help was silent.

The fetch also places `8UDR.cif.gz` beside the checkpoints, because the
covalent stages of `test.sh` need it and the share carries `tools/` but not
`examples/`. One copy lives in git, under `examples/p1b7/reference/`;
`--fixture` copies it across without downloading anything. `tool_doctor`
reports its absence as a FAIL, since the test cannot run without it.

## Traps

- **`ckpt_path=rfd3` resolves inside the image, not on the share.**
  `/app/foundry/.env` pins `FOUNDRY_CHECKPOINT_DIRS='/test-weights:...'` and
  python-dotenv overrides the environment we export, so a checkpoint *name*
  looks in `/test-weights` and the error names a path nobody configured. Pass
  `$RFD3_CKPT`. The same override explains `foundry list-installed` reporting
  no checkpoints on an installation inference resolves perfectly well.
- **`WRITABLE_TMPFS=1` is required, and the error that proves it names
  nothing useful.** `foundry` persists its checkpoint directory by calling
  `dotenv.set_key()` on `/app/foundry/.env`, inside the read-only image.
  python-dotenv rewrites atomically, so it creates a sibling temp file and
  you get

  ```
  OSError: [Errno 30] Read-only file system: '/app/foundry/.tmp_jyowbq10'
  ```

  mid-download, with no mention of `.env`, dotenv, or configuration. Two
  plausible fixes do **not** work: changing the working directory (apptainer
  does inherit the host's, and `find_dotenv()` walks up from the calling
  module's path, not cwd), and binding a writable `.env` over the file (the
  temp file is a *sibling*, so the directory must be writable, not the file).
  The overlay is in memory and discarded at exit, which is correct here: the
  write is 2.5 KB of config nobody needs to keep.
- **A covalent bond cannot be declared, only supplied.** See
  [Covalent modifications](#covalent-modifications). A structure missing its
  `_struct_conn` record gives a free ligand and a silently wrong design.
- **`GPU information: NVIDIA RTX A6000` is printed on machines with no GPU.**
  `cuequivariance_ops` falls back to a hard-coded default map when pynvml
  fails, and prints the fallback. Read
  `Setting accelerator to 'cpu'` instead, or `torch.cuda.is_available()`.
- **`APPDIR` is `/app/foundry`, not `/opt/foundry`.** It is upstream's `uv`
  project root, with the real environment under `.venv/`.
- `--checkpoint-dir` is passed explicitly by the fetch script.
  `FOUNDRY_CHECKPOINT_DIRS` is a *search* path for reading; `install` on its
  own still defaults to `~/.foundry/checkpoints`, and home is 20 GiB here.
