# The tool registry

One directory per tool, describing how that tool is made available on CoreHPC:
a container, a native build, a conda environment, an Lmod module or a licensed
binary. `chpc-tool` reads these entries and runs the software from the lab's
FAC share. A project embeds this repo as a submodule and reads the registry; it
never restates a tool path of its own, so the next project on CoreHPC gets the
whole catalogue for free.

This file is the guide to running the tools and to adding one. The reference
for `tool.conf`, the design notes and the traps sit below "Add a tool"; nothing
there is needed to run something.

## Run a tool on your inputs

For your first run, use **[the P1B7 / 8UDR walkthrough](../docs/11-p1b7-walkthrough.md)**.
It explains the terminal, prepares the actual input files, and takes you
through submission, logs, output checks, and saving your results. The
per-tool guides continue with the same complex:
[Boltz-2](boltz/README.md#run-it), [Chai-1](chai1/README.md#run-it), and
[Protenix](protenix/README.md#run-it). The example bundle is checked into
[`examples/p1b7/`](../examples/p1b7/README.md); another project's checkout is
not required.

### Send a tool job from your laptop

Set up [direct project-folder access in Globus](../docs/02-storage-and-data.md#laptop-to-cluster)
first. From a local CoreHPC checkout, preview and then submit the P1B7 example:

```bash
source ./env.sh &&
chpc-globus.sh doctor "$CHPC_REPO/examples/p1b7" &&
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch --dry-run -- boltz
```

```bash
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch -- boltz
```

This sends the selected folder through Globus, waits for success, then
submits its batch script with SSH. `-- chai1` and `-- protenix` use the other
tutorial tools; adding `template` selects that tool's template mode. The
[full laptop walkthrough](../docs/11-p1b7-walkthrough.md#submit-from-your-laptop-with-globus)
explains the receipt, monitoring, and downloading results directly back into
your project. By default it uses the shared lab installation; `--corehpc`
selects an existing cluster checkout instead.

For your own tool, put the batch script and every local file it needs in a
self-contained job folder, then pass that folder and the script's relative
path to `chpc-submit.sh`. Use `chpc-globus.sh push`/`pull` alone when you only
want to transfer files. Keep local data and scripts out of SSH command
payloads: transfer the files, then execute the staged script.

### Work from a cluster shell

The short version below assumes you have already connected with `ssh chpc`
and cloned this repo at `~/corehpc` following that walkthrough. **Paste this
on the login node:**

```bash
export COREHPC="$HOME/corehpc"
source "$COREHPC/env.sh" &&
export WORK="$CHPC_USER_SCRATCH/tutorials/p1b7-boltz-$(date +%Y%m%d-%H%M%S)" &&
mkdir -p "$WORK" &&
cp -R "$COREHPC/examples/p1b7/." "$WORK/" &&
cd "$WORK" &&
printf '%s\n' "$WORK" | tee "$HOME/p1b7-last-workdir.txt" &&
git -C "$COREHPC" rev-parse HEAD > corehpc-commit.txt &&
python3 check_inputs.py &&
bash run.sh boltz --dry-run
```

`WORK` is your own run directory; the timestamp keeps repeated tutorials
separate. `cp` copies the included inputs there. `check_inputs.py` checks the
bundle's sequences and declared chemistry without running a prediction.
`--dry-run` prints the command the runner will use. Stop if either check
fails. An input check is not a prediction or a check of predicted geometry.

**Still on the login node, request a compute shell:**

```bash
srun --account=hpc_core --partition=gpu --gres=gpu:nvidia_l40s:1 \
    --cpus-per-task=8 --mem=64G --time=04:00:00 --pty bash -l
```

Slurm may print that it is waiting for resources. Wait for a new prompt.
The L40S selection is usable by all three tutorial tools. This is an initial
resource request, not a measured requirement for the full Fab example.

**At the new prompt, on the compute node:**

```bash
hostname
printf 'Job: %s\n' "$SLURM_JOB_ID"
source "$COREHPC/env.sh" &&
cd "$WORK" &&
chpc-tool doctor boltz &&
bash run.sh boltz
```

Read the command and output path printed by the runner. It uses the shared
weights and local inputs, then checks the predicted covalent geometry.
[The Boltz guide](boltz/README.md#run-it) explains the exact underlying
`chpc-tool exec` command, flags, output files, and optional reference template.
When finished, `exit` releases the interactive allocation and returns to the
login node. Follow the [save-results steps](../docs/11-p1b7-walkthrough.md#save-your-results)
before leaving your only copy on scratch.

### What the command means

You will see these two lines inside most GPU workflows:

```bash
eval "$(chpc-tool export boltz)"
chpc-tool exec boltz -- boltz predict boltz.yaml --cache "$BOLTZ_CACHE" --out_dir out/manual-boltz --no_kernels --use_potentials --seed 1 --diffusion_samples 5
```

This is an explanation of the runner's building blocks, not another required
run. The first line loads the Boltz-specific settings into **your current
shell**. In the second line:

- `chpc-tool` is our lab's launcher, not the prediction program itself.
- `exec boltz` selects the installed Boltz container, weights, filesystem
  mounts, and GPU compatibility checks.
- `--` ends the launcher's arguments. The second `boltz` is the program to
  run inside the container; always include it.
- `predict boltz.yaml` names the task and its input file. It is found relative
  to the directory printed by `pwd`, unless you give an absolute path.
- `--cache "$BOLTZ_CACHE"` points to the existing shared weights. The preceding
  `eval` is necessary because your shell expands `$BOLTZ_CACHE` before the
  container starts.
- `--out_dir` chooses a new output folder. Other options are tool-specific;
  the Boltz README explains the geometry and sampling choices.

A **container** packages software and dependencies; you do not install them
on your account. Scratch and FAC appear at the same paths inside it. A
**model weight** file holds trained model parameters. An **MSA** is an alignment
of related sequences, and a **template** is a known structure supplied as
additional information. They are different inputs. The first tutorial uses
single sequences to run without an online MSA service; it is an onboarding
exercise, not a qualified production protocol.

Inputs and intermediate outputs belong on scratch. Shared weights and
reference databases are under `$CHPC_LAB/data/`; images are under
`$CHPC_LAB/containers`, with a faster per-image scratch copy when available.
Final results belong under `$CHPC_LAB/results/`. Do not edit shared weights
or run I/O-heavy calculations directly on FAC.

For a CPU-only tool, request a CPU **shell** instead:

```bash
srun --account=hpc_core --partition=cpu --cpus-per-task=4 \
    --mem=8G --time=01:00:00 --pty bash -l
```

A bare `salloc` reserves resources but does not itself move your shell off
the login node. See [interactive jobs](../docs/03-interactive-jobs.md).

### As a batch job

A batch job keeps running after you disconnect. For the P1B7 example, **on
the login node**, after staging the bundle as above:

```bash
cd "$WORK" &&
mkdir -p logs &&
JOB_ID=$(sbatch --parsable p1b7.sbatch boltz) &&
printf '%s\n' "$JOB_ID" | tee last-job-id.txt &&
squeue -j "$JOB_ID"
```

The included script requests a GPU and calls the same runner. Use `chai1` or
`protenix` in place of `boltz` after reading that tool's walkthrough. A job
number means Slurm accepted the request, not that the prediction finished.
[The shared walkthrough](../docs/11-p1b7-walkthrough.md#watch-a-batch-job)
explains pending jobs, logs, failures, cancellation, and reconnecting.

For your own workflow later, copy
[`templates/slurm/tool-gpu.sbatch`](../templates/slurm/tool-gpu.sbatch) and
edit its four marked lines: GPU, tool, working directory, and program command.
Create `logs/` **before** submitting: Slurm opens the log before executing the
script. Stage the inputs into its working directory first. The
[batch-job guide](../docs/04-batch-jobs.md) explains how to create and edit a
script, as well as resource sizing and arrays.

## The CLI

`chpc-tool --help` prints the verb list. The first seven are for anyone running
software; the last four are for whoever builds and publishes it ("Add a tool").
Every verb resolves the registry beside the script it was invoked from, so
`corehpc/lab/bin/chpc-tool` in a project sees that project's pinned entries,
and the copy on the share sees the share's. Once `chpc.env` or `env.sh` has
been sourced in an interactive shell, Tab completes the verbs, the tool names
and the `--`.

**`chpc-tool list`** — every entry, one line: name, version, kind, status,
GPU, licence. `STATUS` is the thing to read: `verified` has passed its
self-test on a compute node here; `built` exists on the share but has not;
`planned` is a description and nothing else. On 2026-09-26 that was 15, 5 and
13 of 33.

**`chpc-tool show <tool>`** — the entry, resolved: the image path actually in
use, whether it takes a GPU and up to which compute capability, the default
program (`entry`), where the code lives inside the image, the variables it
exports, and the entry's `note`: the runtime caveats. Read the note before the
first run. `chpc-tool show --env <tool>` prints the same entry as `KEY='value'`
lines for a script or a program, without the note (doc 07 has the shape).

**`chpc-tool doctor [<tool>...]`** — is it really there and really working:
one row per entry, `OK`, `FAIL` or `----` (not checked: planned, or not
answerable from this machine), with the path it found or the reason it did
not, then a count. It runs each entry's own check, so a missing weight cache,
a purged scratch mirror (`[not in the scratch mirror -- run
chpc-stage-containers]`) or a stale `chpc.env` on the share show up here and
nowhere else. Run it with no arguments on your first day and after every
quarterly purge.

**`chpc-tool exec <tool> -- <program> <args>...`** — run a command through the
tool's runtime. For a container that is `apptainer exec`, plus `--nv` when
the entry says `GPU=1`, plus the scratch and FAC binds, plus the entry's
exports as environment variables inside, plus a refusal if the node's GPU is
newer than the image's kernels ("Which GPU"). For a native install it puts
`$PREFIX/bin` on `PATH` and runs the command; for a module kind it loads the
modules first. A conda entry (`python-bio`) has no `exec` form: use `export`
and call the interpreter it names.

Write the program after `--` every time, exactly as the tool's documentation
would have you type it at a shell inside the container:

```bash
chpc-tool exec boltz -- boltz predict in.yaml --cache "$BOLTZ_CACHE" --out_dir out
chpc-tool exec colabfold -- colabfold_batch --msa-mode single_sequence --data "$COLABFOLD_DATA" in.fasta out
chpc-tool exec proteinmpnn -- python /opt/ProteinMPNN/protein_mpnn_run.py --help
chpc-tool exec dssp -- mkdssp --version
chpc-tool exec boltz -- bash                 # a shell inside the container; exit to leave
chpc-tool exec boltz -- nvidia-smi           # is the GPU visible in there?
```

Every entry names a default program (`ENTRY` in its tool.conf) that `exec`
prepends when you give no command, or when the first word after the tool
starts with `-`: `chpc-tool exec boltz` and `chpc-tool exec boltz --help`
both run `boltz`. That is the trap. `chpc-tool exec boltz predict in.yaml`
does **not** run `boltz predict`; it tries to run a program called `predict`
and fails with an executable-not-found error. The `-- <program>` form has no
such ambiguity and is the only form used in these docs.

**`chpc-tool export <tool>...`** — the entry's variables as `export NAME=value`
lines. Two uses. In your shell, before a command line that mentions one:

```bash
eval "$(chpc-tool export colabfold)"
chpc-tool exec colabfold -- colabfold_batch --data "$COLABFOLD_DATA" --msa-mode single_sequence in.fasta out
```

And in a project's `site.conf` or job script, the same `eval` with every tool
the project uses, so `SIF_BOLTZ`, `BOLTZ_CACHE`, `RFDIFFUSION_MODELS` and the
rest are set once from the registry instead of typed. Each variable is also
emitted as `APPTAINERENV_<NAME>`, which is the only form that overrides a name
the image's own `%environment` sets (doc 07).

**`chpc-tool path <tool>`** — the resolved `.sif` (or install prefix) on one
line, for a script that must call `apptainer` itself. Prefer this over
interpolating `$CHPC_CONTAINERS/<name>.sif` by hand: the variable cannot
express the per-image fallback from the scratch mirror to FAC; `path` can.

Maintainer verbs: **`chpc-tool test <tool>`** runs the entry's `test.sh` on a
compute node (what `verified` means); **`chpc-tool build <tool>`** builds a
container from its `.def` on the login node; **`chpc-tool publish <tool>`**
copies a built image to the share; **`chpc-tool wrapper <tool>`** rewrites
`$CHPC_LAB/bin/<tool>`. All four are in "Add a tool".

## Which GPU

The `gpu` partition is three GPU generations, and a bare `--gres=gpu:1` lands
on any of them. Seven of the lab's images are built on CUDA older than 12.8
and have no kernels for the Blackwell nodes (`ggpu1-[13-19]`, RTX PRO 6000,
compute capability 12.0); on those nodes they die at the first kernel launch
with `CUDA error: no kernel image is available for execution on the device`,
intermittently, depending on what was free (`docs/05-partitions-and-hardware.md`).
The registry records the limit as `GPU_MAX_CC`, `chpc-tool show` prints it,
and `chpc-tool exec` checks `nvidia-smi` before launching anything, so the
failure is immediate and named:

```
rfdiffusion cannot run on this GPU.
  device compute capability : 12.0  (NVIDIA RTX PRO 6000 ...)
  image supports up to      : 9.0
```

The `--gres` line is the real fix, because it decides where the job lands.
As of 2026-09-25:

| Tools | `GPU_MAX_CC` | Ask for |
|---|---|---|
| chai1, colabfold, intellifold, placer, protenix, rfdiffusion, rfdiffusion3 | 9.0 | `--gres=gpu:nvidia_l40s:1` or `--gres=gpu:nvidia_h100_nvl:1`. Never a bare `gpu:1`. |
| esm, ligandmpnn, proteinmpnn | none (the image carries `sm_120`) | `--gres=gpu:1`, any node |
| boltz | none | `--gres=gpu:1`, any node, kernels on or off: the kernel path has run on an L40S (job 1997376) and on an RTX PRO 6000 Blackwell (job 1997377, 2026-09-26) |
| openfold3 (built, not yet verified) | 12.0 | `--gres=gpu:1` |

`nvidia_l40s` and `nvidia_h100_nvl` are the two models our QoS can reach. The
interactive form is

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
```

and `templates/slurm/tool-gpu.sbatch` defaults to `nvidia_l40s` for the same
reason: it is safe for every tool, at the cost of a narrower queue for the
three that did not need it. Which GPU a job actually got is the first line of
its log (the template prints `nvidia-smi`), and the `Status` row of a tool's
README says which model its self-test ran on.

## Reading a tool's README

The Boltz, Chai, and Protenix READMEs open with a complete P1B7 walkthrough;
their installation/build records follow it. Other entries generally open
with a header table (status and the GPU model
the self-test ran on, image, which `--gres` to ask for, weights, licence,
upstream pin), then three sections a first run needs: **Run it**, a
copy-pasteable block with production defaults; **Inputs and outputs**, what
the input file is, where output lands and whether it is ranked; **Do not
miss**, the two to five flags or habits that silently ruin a run on this
cluster. Below a rule is the record for whoever maintains the entry:
**Provenance** (when and by whom it was built, what `chpc-tool test` proves,
measured and dated), **Build notes** (the recipe decisions and the failures
that shaped them) and **Traps** (everything else that bit). The `NOTE=` line
in `tool.conf`, which `chpc-tool show` prints, is the one-paragraph version of
"Do not miss". A `planned` entry has **Not built yet** in place of "Run it":
what blocks it and what to use meanwhile.

## Add a tool

An entry starts as a description and earns its status:

| STATUS | Meaning |
|---|---|
| `planned` | described only. No image, no install. `doctor` reports it and moves on. |
| `built` | the image or install exists on the share, but nothing has run through it yet |
| `verified` | `test.sh` has passed on a compute node, and the date is in the entry's README |
| `external` | **a terminus, not a rung.** The tool is deliberately not installed here, because it is not installable here: a web service whose only local form is a protocol nobody has written. `doctor` prints it under "not checked" and there is nothing to build. |

`external` exists because `planned` was lying about two entries. `funclib` and
`pross` are Weizmann web servers, and a local install of either is a Rosetta
protocol that would have to be written from scratch. Carried as `planned` they
read as a queue of pending builds, and the honest answer to "when is the image
coming" is never. A status column that says so is worth more than a NOTE three
paragraphs long that nobody reaches. An `external` entry still owes a README:
the point is to record how the lab actually uses the tool, and what a local
install would take, so the next person does not re-derive it.

Files in an entry:

| File | Required | What it is |
|---|---|---|
| `tool.conf` | always | the declaration. Plain shell, sourced. Every key is in "Reference: tool.conf". |
| `README.md` | once `STATUS` leaves `planned` | the build record, in the shape "Reading a tool's README" describes; start from `_template/README.md` |
| `<name>_<version>.def` | containers | the Apptainer recipe, named after `IMAGE`; `chpc-tool build` pairs the two and refuses to guess when several `.def` files match none |
| `test.sh` | for `verified` | a self-test of about 30 seconds, run by `chpc-tool test` in a scratch directory with the entry's exports set |
| `fetch-weights.sh` | tools with freely licensed weights | downloads them to the path `tool_exports` names, on the login node (8 entries have one; copy `boltz/fetch-weights.sh`) |
| `fetch-db.sh` | search tools | the same for a database: `foldseek/fetch-db.sh` and `mmseqs2/fetch-db.sh` take a database name from the tool's own `databases` list and land it where `tool_exports` points |
| `assets.tsv` | licensed payloads | files by sha256, installed by `chpc-assets`; the payload itself never enters git |

A `planned` entry needs no README: `UPSTREAM`, `LICENSE` and a `NOTE=` line in
`tool.conf` carry everything there is to say about a tool nobody has built. An
`external` entry does owe one, because there is something to say: which web
service, what it is used for, and what a local install would actually involve.
The README is where the *build* gets recorded, so it is owed at the moment
someone does the build, not before.

1. **Declare it, and commit.**

   ```bash
   mkdir tools/mytool && cp tools/_template/tool.conf tools/_template/README.md tools/mytool/
   $EDITOR tools/mytool/tool.conf     # NAME VERSION KIND LICENSE UPSTREAM NOTE; IMAGE GPU ENTRY for a container
   sh -n tools/mytool/tool.conf       # it is sourced shell: quote any value with a space or a metacharacter
   chpc-tool show mytool              # parses and resolves
   ```

   Not `cp -r`: `_template/` also holds `make_test_pdb.sh` and
   `check_covalent_bond.sh`, which the tests of nine entries call in place as
   `$TOOLDIR/../_template/...`. A planned entry is worth a commit on its own.

2. **Recipe and build** (containers; the login node is the only node with
   internet).

   ```bash
   cp templates/apptainer/pytorch-ngc.def tools/mytool/mytool_1.0.def   # or minimal.def, conda-env.def; IMAGE=mytool_1.0.sif
   chpc-tool build mytool             # -> $CHPC_USER_SCRATCH/apptainer/mytool_1.0.sif
   ```

   Doc 07 is the list of ways a green build produces a broken image; the
   `%post` and `%test` assertions it asks for are not optional. A native,
   conda or module kind has nothing to build here: install under `$PREFIX`
   (or `chpc-assets install` for a licensed binary), or set `MODULE`.

3. **Weights and licences.** `tool_exports` names where they live, under
   `$CHPC_REFDATA/mytool` (`_refdata mytool`). Freely licensed weights: a
   `fetch-weights.sh` that does `eval "$(chpc-tool export mytool)"` and
   downloads to that path, run once on the login node. Licensed payloads:
   `assets.tsv` and `chpc-assets install mytool --from <dir>`, where `<dir>`
   is on the cluster: from a laptop, `chpc-globus.sh push` it to your scratch
   first (doc 02). Then a
   `tool_doctor` that checks the payload is there, so `doctor` can say so
   after the next purge.

4. **Test on a compute node, before publishing.** The built image is in your
   scratch, not on the share, so point the resolver at it for these commands:

   ```bash
   srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
   CHPC_CONTAINERS=$CHPC_USER_SCRATCH/apptainer chpc-tool exec mytool -- mytool --version
   CHPC_CONTAINERS=$CHPC_USER_SCRATCH/apptainer chpc-tool exec mytool -- python -c "import torch; print(torch._C._cuda_getArchFlags())"
   $EDITOR tools/mytool/test.sh       # ~30 s; asserts a property a wrong answer cannot satisfy (see Traps)
   CHPC_CONTAINERS=$CHPC_USER_SCRATCH/apptainer chpc-tool test mytool     # PASS mytool
   ```

   If the arch flags stop at `sm_90`, set `GPU_MAX_CC=9.0`; if `sm_120` is
   present, leave it empty. Set `STATUS=built`, `UPSTREAM_REF` to the exact
   commit, tag or image digest, and fill in `README.md` from the template:
   the header table, "Run it" with production defaults, what the test
   proves, the traps you hit.

5. **Publish** (login node, plain environment).

   ```bash
   chpc-tool publish mytool           # image (mode 644) and .def to $CHPC_LAB/containers, $CHPC_LAB/bin/mytool wrapper, README row, scratch mirror
   chpc-tool doctor mytool            # OK, and no "not in the scratch mirror"
   ```

   `publish` is for containers. A native install is already on the share;
   `doctor` is the check. `lab/README.md` says what `publish` does on the
   share and how to keep the share's copy of this repo current.

6. **`STATUS=verified`**, with the date and GPU model in the README's Status
   row; commit to this repo; bump the submodule pin in each project that
   needs the tool. Never modify a published `.sif`: a new version is a new
   filename, and the old one stays until nothing pins it.

## Reference: tool.conf

Plain shell, sourced by name. There is no lookup table anywhere in `chpc-tool`,
because `/bin/bash` on the lab Macs is 3.2 and has no associative arrays; one file per
tool sidesteps that entirely. Keep it POSIX-ish for the same reason.

```sh
NAME=proteinmpnn            # defaults to the directory name
VERSION=1.0
KIND=container              # container | native | conda | venv | module
STATUS=planned              # planned | built | verified   (see Add a tool)
LICENSE=MIT
UPSTREAM=https://github.com/dauparas/ProteinMPNN
UPSTREAM_REF=               # exact commit, tag or image digest the build came from; set when built
NOTE=""                     # runtime caveats a user must read before the first run. One quoted
                            # string; this file is SOURCED, so an unquoted backtick or $ runs.
                            # `chpc-tool show` prints it.

# --- KIND=container ---
IMAGE=proteinmpnn_1.0.sif   # bare name: the scratch mirror if it holds it, else $CHPC_LAB/containers;
                            # an absolute path is used as given
GPU=1                       # 1 passes --nv. Set 0 for a CPU-only image and mean it.
GPU_MAX_CC=                 # highest compute capability the image has kernels for (9.0 = no
                            # Blackwell). exec refuses a newer device up front. Empty = no limit.
WRITABLE_TMPFS=0            # 1 passes --writable-tmpfs, for a tool that writes config inside its
                            # own image. Never for data; see the trap below.
APPDIR=/opt/ProteinMPNN     # where the code lives INSIDE the image
ENTRY=python                # prepended by exec when given no command, or a first argument that
                            # starts with `-`. Not before a path or a subcommand (see the trap).

# --- KIND=native | conda | venv ---
PREFIX=$CHPC_SOFTWARE/rosetta314    # install root; exec puts $PREFIX/bin on PATH (native)
ENV_YML=                            # conda: the recipe, usually supplied by the project
ENV_NAME=                           # conda: environment name (python-bio: ${CHPC_PYENV:-bio})
SUFFIX=                             # native: binary-name suffix (rosetta: default.linuxgccrelease)

# --- KIND=module ---
MODULE=                     # Lmod modules, loaded one at a time in order: "Sali dssp/2.2.1"

tool_exports() {            # optional: the variables a project's site.conf wants
  echo "SIF_PROTEINMPNN=\"$(_image_path)\""
  echo "PROTEINMPNN_DIR=\"$APPDIR\""
}

tool_doctor() {             # optional: a check beyond "does the file exist"
  :                         # return 0 ok, 1 broken; print one line either way
}

tool_precheck() {           # optional: runs BEFORE doctor looks at any path
  :                         # return 0 carry on, 2 "not checked", 1 broken
}
```

All three functions are optional. `tool_exports` is a shell function rather than a
declarative mapping because the interesting cases are not one-to-one: FoldX exports a
path to a *binary*, Rosetta exports three variables including a build-triple suffix,
and PLACER exports a checkout path that is needed whatever the runtime.

`tool_precheck` exists for entries whose location depends on something the *caller*
supplies. `python-bio`'s `PREFIX` contains `$CHPC_PYENV`, so with none set, doctor
looked for a generic `bio` env that nothing was ever asked to create, and reported
the registry's only `FAIL`. Returning 2 puts the row in "not checked", next to the
planned tools, with a message naming what to pass. The rule it encodes: **a false
FAIL costs more than a missing row**, because it is what teaches people to skim past
doctor's output — and then a real one goes unread.

Helpers available inside all three functions: `_image_path` (resolves
`IMAGE`: the scratch mirror if readable, else `$CHPC_LAB/containers`),
`_prefix` (expands `PREFIX`), `_refdata <tool>` (`$CHPC_REFDATA/<tool>`),
`die`, and `$TOOLDIR` (the entry's directory).

## Design notes

### What belongs here, and what does not

**Here:** where a tool lives, how it is launched, what weights or licences it needs,
what its recipe is, how to tell whether it works.

**Not here:** how many samples to draw, which structure to run it on, which partition
to submit to. Those are project choices and campaign policy. The dividing line is that
a second project should be able to use a `tool.conf` unchanged.

Scheduler values in particular never appear in this directory. They live in the
`#SBATCH` headers of the submitting project's job scripts, which are the only things
`sbatch` ever sees.

### An entry is not an image

Thirteen of 33 entries are `STATUS=planned` (2026-09-25): the catalogue records a tool the lab expects
to want, with its licence, upstream and intended packaging, before anyone has built
it. That is deliberate — an entry costs minutes, an image costs an afternoon and a
few GB of the share.

`chpc-tool list` prints the status, and `chpc-tool doctor` fails loudly on a tool that
claims to be built and is not. Nothing here should ever imply an image exists when it
does not.

### Why the definitions live in this repo and not in a project

The rule has stood since the share was bootstrapped, and step 6 of "Add a tool"
is *commit to this repo*. Until this directory existed there was nowhere to put
them, so `IgGase_eng` grew a `pipelines/slurm/containers/` that was
going to hold the same files. Two homes for one recipe is how the lab ends up with two
slightly different RFdiffusion images. This directory is that one home.

### Reading an entry from something that is not a shell

That last line is only true if a project can actually *read* an entry. A
`tool.conf` is sourced shell and its values are produced by shell, so the only
faithful reader of one is a shell — which leaves anything else copying the
registry's values into a second file that goes stale the first time an image is
rebuilt. `chpc-tool show --env` is the way out: one shell-quoted assignment per
line, one record per entry, with the image resolved per image rather than
composed from a directory. See doc 07 for the shape and the reasoning.

### The published wrapper

`chpc-tool publish` writes `$CHPC_LAB/bin/<tool>` from `lab/bin/run-in-container`.
Since 2026-09-26 that wrapper is `chpc-tool exec <tool> -- <ENTRY> "$@"` under
a shorter name, so `boltz predict in.yaml` on the login node gets everything
`exec` gives: the exports, the `GPU_MAX_CC` refusal, the mirror-to-FAC
fallback, `--writable-tmpfs` where declared. The one difference is that a
wrapper always prepends `ENTRY`, because a command named after a tool takes
that tool's arguments; `exec` prepends it only before a flag. The wrapper reads
the registry at run time through `chpc-tool`, so a rebuilt image needs no new
wrapper. `chpc-tool exec` stays the form the docs teach, because it is the one
that works identically from a project's pinned submodule off the share.

## Traps before you write an entry

**`ENTRY` is prepended for a flag, not for a script path.** `chpc-tool exec`
prepends `ENTRY` when it is given no command at all, or when the first argument
starts with a dash — so `chpc-tool exec dssp --version` means `mkdssp --version`.
It does **not** prepend it in front of a path, because a path is a perfectly good
command and `run_tool` passes whole command lines through. The consequence is
that with `ENTRY=python`,

```bash
chpc-tool exec proteinmpnn -- /opt/ProteinMPNN/protein_mpnn_run.py --help
```

makes apptainer try to execute the `.py` itself and fails with a bare
`FATAL: permission denied`, which says nothing about a missing interpreter.
Spell the interpreter out. The generated `$CHPC_LAB/bin/<tool>` wrapper is the
other way round — it always prepends `ENTRY`, because a wrapper named after a
tool takes that tool's arguments, and then hands over to `chpc-tool exec`
("The published wrapper", above).

**A `test.sh` needs a fixture with real variety, not a minimal one.**
`_template/make_test_pdb.sh` generates the backbone the tests use, and it
alternates helix with extended segments *and* cycles residue names. Both matter:
foldseek's prefilter scores a combined amino-acid + 3Di k-mer, so a pure helix
(one 3Di state) or a poly-alanine chain (one residue type) fails to match
**itself** and looks exactly like a broken tool. Anything doing structural or
profile search has the same sensitivity.

**A heredoc body starts on the line after the `<<`, which breaks the obvious
way to write "run this python and report failure".** This does not work:

```sh
"$CHPC_TOOL" exec esm -- python - > esm.log 2>&1 <<'PY' || {
    echo "failed"; tail -25 esm.log; exit 1; }      # eaten as python
import torch
PY
```

The `{ … }` continuation is consumed as the first line of the heredoc, so the
brace never closes and the shell reports `syntax error: unexpected end of file`
pointing at the **last line of the file** — nowhere near the mistake. Use `if !`
instead, which ends the command line at the `<<`:

```sh
if ! "$CHPC_TOOL" exec esm -- python - > esm.log 2>&1 <<'PY'
import torch
PY
then
    echo "failed"; tail -25 esm.log; exit 1
fi
```

**A `%` at the start of a line inside a heredoc is an Apptainer SECTION
HEADER.** Apptainer's definition parser looks only at the first non-whitespace
character of each line, and it does not know or care that the line is inside a
`%post` heredoc. So a python line continuation beginning with the format
operator:

```python
    assert hits, ("missing %s under %s -- the plugin cannot load"
                  % (stem, lib))          # <- parsed as a section header
```

kills the build before it starts, with

```
FATAL: ... while parsing definition: ... invalid section(s) specified:
```

naming **nothing at all** after the colon, because the section name it found
was empty. Nothing in that message points at a heredoc, a python line, or a
`%`. Keep the operator at the end of its line — `"..." % (a, b)` — and the
problem does not exist. The same applies to a shell heredoc containing a line
that starts with `%`, and to a Markdown or text block embedded in `%help`.

`grep -n '^[[:space:]]*%' tools/*/*.def` finds every instance, and returns only
the real section headers when the recipes are clean.

**`WRITABLE_TMPFS=1` is for config, never for data.** Some tools insist on
writing inside their own installation, which a read-only `.sif` forbids
(doc 07). Where that write is small and disposable, an in-memory overlay is
the honest fix. `rfdiffusion3` is the case: `foundry` persists its checkpoint
directory with `dotenv.set_key()` into `/app/foundry/.env`, and python-dotenv
rewrites atomically — so it creates a *sibling* temp file and needs the
**directory** writable, not the file. Binding a writable `.env` over it does
not work; that is worth knowing before you try it, because it looks like it
should.

The flag is the wrong answer whenever the write is real output or weights.
Those go on the share through `CHPC_REFDATA`, because a tmpfs overlay is
per-process, discarded at exit, and counts against the job's memory.

**Quote anything with a space or a shell metacharacter.** A `tool.conf` is
sourced, so `UPSTREAM_REF=v3.3.0 (tarball)` is a syntax error, and before the
check in `_load` it surfaced as a bare `line 8: syntax error near unexpected
token '('` from inside an `eval` in a job script. `chpc-tool` now names the
tool and says how to quote it, but the cheap habit is
`sh -n tools/*/tool.conf tools/*/test.sh` before you commit.

**Assert the property you care about, not the import.** The expensive failures
in this registry all share one shape: the natural check passes while the thing
is broken.

| Recipe | `import` says | Actually |
|---|---|---|
| placer, after `conda install openbabel` | `import torch` ok | torch had been replaced with a **CPU** build |
| placer, missing `libXext` | `import openbabel` ok, version prints | **no format registered** — every `read` returns an empty molecule |
| boltz, without the `[cuda]` extra | `import boltz` ok, `--help` ok | dies mid-batch on the first real prediction |
| rosetta, binaries only | binary runs, prints usage | linked to libraries on **scratch**, which is purged |

So write the assertion against the property, and prefer one that a wrong
answer cannot satisfy:

```python
assert torch.version.cuda == "12.1"          # not: import torch
assert c.SetInFormat("pdb")                  # not: import openbabel
```

Caring is not a mechanism — the placer recipe already carried a comment
warning that conda could replace its torch, three paragraphs above the line
that did it. Put the rule in an `assert`, in `%post` *and* in `%test`, because
those two run against different filesystems (doc 07).
