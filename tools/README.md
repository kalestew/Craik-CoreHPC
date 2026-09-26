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

You need a shell on a compute node with `chpc-tool` on `PATH` (root README,
"First hour on CoreHPC", steps 4 and 6). The example is Boltz-2, which runs on
any node of the `gpu` partition; seven tools do not, see "Which GPU".

```bash
# 1. A GPU node.
srun -p gpu --gres=gpu:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l

# 2. Inputs on scratch. The same path is valid inside the container, so
#    nothing is copied in or out.
mkdir -p /mnt/scratch/user/$USER/boltz/p1 && cd /mnt/scratch/user/$USER/boltz/p1
cat > in.yaml <<'EOF'
version: 1
sequences:
  - protein:
      id: A
      sequence: MKTAYIAKQRQISFVKSHFSRQLEERLGLIE
      msa: empty
EOF

# 3. Is it there, and what does it need?
chpc-tool doctor boltz          # one row: OK, the weight cache path, and a caveat about --no_kernels
chpc-tool show boltz            # image path, gpu yes, the exports, and the entry's note

# 4. The tool's variables in THIS shell, so you can write them on a command line.
eval "$(chpc-tool export boltz)"
echo "$BOLTZ_CACHE"             # /mnt/fac/CX500146_DS1/data/boltz

# 5. Run. After `--` comes the command exactly as the tool's own docs give it.
chpc-tool exec boltz -- boltz predict in.yaml --cache "$BOLTZ_CACHE" --out_dir out --no_kernels

# 6. Output is where you said, on scratch. Keep what matters on FAC.
find out -name '*model_0*'
cp -r out /mnt/fac/CX500146_DS1/results/myproject/p1/
```

Three things in that block are the whole method:

- **`chpc-tool exec <tool> -- <program> <args>`.** `exec` finds the image,
  adds `--nv` for a GPU tool, mounts scratch and FAC, exports the tool's
  weight and cache paths into the container, and refuses a GPU the image has
  no kernels for. Write the program after `--` every time; "The CLI" below
  says why `chpc-tool exec boltz predict ...` is not the same command.
- **`eval "$(chpc-tool export <tool>)"`** before you type a tool's variable
  (`$BOLTZ_CACHE`, `$COLABFOLD_DATA`, `$RFDIFFUSION_MODELS`) on a command
  line. `exec` already exports them *inside* the container; the `eval` puts
  them in *your* shell, where the command line is expanded. Without it the
  variable is empty and the tool falls back to its own default, which for
  Boltz is downloading weights from a node with no internet.
- **The tool's own caveats.** `--no_kernels` above comes from the `NOTE=` in
  `tools/boltz/tool.conf`, which `chpc-tool show boltz` prints: the previous
  image had no C compiler, so any prediction over about 128 tokens died
  without it, and the rebuilt image has not yet been measured with the
  kernels on. Every entry has such a note; read it, and the entry's
  `README.md` ("Do not miss"), before the first real run.

Where things are: inputs and outputs on `/mnt/scratch/user/$USER` (purged at
30 days); weights and databases at `$CHPC_LAB/data/<tool>`, already fetched
for every built tool, and `doctor` says so if one is missing; images at
`$CHPC_LAB/containers` with a faster copy on group scratch, chosen per image;
final results at `$CHPC_LAB/results/<project>/`. Between a laptop and any of
those it is Globus: `chpc-globus.sh push ./p1 "$CHPC_USER_SCRATCH/boltz/p1"`
in, `chpc-globus.sh pull "$CHPC_LAB/results/myproject/p1" ./` out (doc 02);
`scp` through the bastion is not permitted. A CPU tool (foldseek,
mmseqs2, hhsuite, dockq, pymol; rosetta and foldx are native installs) is the
same sequence from `salloc -p cpu -c 8 --mem 16G -t 2:00:00`.

### As a batch job

`templates/slurm/tool-gpu.sbatch` is steps 1 to 6 as a job script. Copy it,
edit the four lines marked EDIT (tool, work directory, `--gres`, the command
after `--`), create `logs/`, submit:

```bash
cp /mnt/fac/CX500146_DS1/slurm/tool-gpu.sbatch ~/jobs/boltz_p1.sbatch   # from a checkout: corehpc/templates/slurm/tool-gpu.sbatch
$EDITOR ~/jobs/boltz_p1.sbatch
mkdir -p logs && sbatch ~/jobs/boltz_p1.sbatch
squeue -u $USER
ls logs/
```

Stage the inputs into the work directory the script names before you submit
(from a laptop, `chpc-globus.sh push`; on the cluster, `cp` from FAC).
The job sources `chpc.env` itself, runs the same `eval` and the same
`chpc-tool exec`, and prints which GPU it landed on at the top of its log. See
`docs/04-batch-jobs.md` for sizing, arrays and monitoring.

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
`planned` is a description and nothing else. On 2026-09-25 that was 14, 6 and
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
| boltz | none | `--gres=gpu:1` with `--no_kernels` (measured on all three classes). With the kernels on, nothing has run on a Blackwell node yet: ask for `nvidia_l40s` or `nvidia_h100_nvl` until its README says otherwise |
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

`tools/<tool>/README.md` opens with a header table (status and the GPU model
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
`tool.conf` carry everything there is to say about a tool nobody has built.
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
