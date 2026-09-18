# The tool registry

One directory per tool, describing **how that tool is made available on CoreHPC** —
whether it is a container, a native build, a conda environment or a licensed binary.
`lab/bin/chpc-tool` reads these and answers the four questions a project has:

```bash
chpc-tool list                      # what exists, and whether it is actually built
chpc-tool export proteinmpnn        # the variables a project's site.conf needs
chpc-tool exec proteinmpnn -- python -c 'import torch'
chpc-tool doctor                    # is each tool really there, and really working
```

A project embeds this repo as a submodule and reads the registry; it does not
restate tool paths of its own. That is the whole point: the next project on
CoreHPC gets the catalogue for free.

## What belongs here, and what does not

**Here:** where a tool lives, how it is launched, what weights or licences it needs,
what its recipe is, how to tell whether it works.

**Not here:** how many samples to draw, which structure to run it on, which partition
to submit to. Those are project choices and campaign policy. The dividing line is that
a second project should be able to use a `tool.conf` unchanged.

Scheduler values in particular never appear in this directory. They live in the
`#SBATCH` headers of the submitting project's job scripts, which are the only things
`sbatch` ever sees.

## An entry is not an image

Most entries here are `STATUS=planned`: the catalogue records a tool the lab expects
to want, with its licence, upstream and intended packaging, before anyone has built
it. That is deliberate — an entry costs minutes, an image costs an afternoon and a
few GB of the share.

`chpc-tool list` prints the status, and `chpc-tool doctor` fails loudly on a tool that
claims to be built and is not. Nothing here should ever imply an image exists when it
does not.

| STATUS | Meaning |
|---|---|
| `planned` | described only. No image, no install. `doctor` reports it and moves on. |
| `built` | the image or install exists on the share, but nothing has run through it yet |
| `verified` | `test.sh` has passed on a compute node, and the date is in the entry's README |

## Files in an entry

| File | Required | What it is |
|---|---|---|
| `tool.conf` | always | the declaration. Plain shell, sourced. |
| `README.md` | once `STATUS` leaves `planned` | provenance: what was built, by whom, when, what `test.sh` proved, and any trap |
| `<name>_<version>.def` | containers | the Apptainer recipe. Build with `chpc-tool build`. |
| `assets.tsv` | if it needs weights or a licence | payloads by sha256; see `chpc-assets` |
| `test.sh` | for `verified` | a self-test of about 30 seconds, run inside the tool |

A `planned` entry needs no README: `UPSTREAM`, `LICENSE` and a `NOTE=` line in
`tool.conf` carry everything there is to say about a tool nobody has built. The
README is where the *build* gets recorded, so it is owed at the moment someone
does the build, not before.

## `tool.conf`

Plain shell, sourced by name. There is no lookup table anywhere in `chpc-tool`,
because `/bin/bash` on the lab Macs is 3.2 and has no associative arrays; one file per
tool sidesteps that entirely. Keep it POSIX-ish for the same reason.

```sh
NAME=proteinmpnn            # defaults to the directory name
VERSION=1.0
KIND=container              # container | native | conda | venv | module
STATUS=planned              # planned | built | verified
LICENSE=MIT
UPSTREAM=https://github.com/dauparas/ProteinMPNN
UPSTREAM_REF=               # the exact commit the image was built from; set when built

# --- container kinds ---
IMAGE=proteinmpnn_1.0.sif   # bare name resolves under $CHPC_CONTAINERS; absolute also works
GPU=1                       # 1 passes --nv. Set 0 for a CPU-only image and mean it.
APPDIR=/opt/ProteinMPNN     # where the code lives INSIDE the image
ENTRY=python                # default command when `chpc-tool exec` is given none

# --- native / conda kinds ---
PREFIX=$CHPC_SOFTWARE/rosetta314    # install root
ENV_YML=                            # conda: the recipe, usually supplied by the project

tool_exports() {            # optional: the variables a project's site.conf wants
  echo "SIF_PROTEINMPNN=\"$(_image_path)\""
  echo "PROTEINMPNN_DIR=\"$APPDIR\""
}

tool_doctor() {             # optional: a check beyond "does the file exist"
  :                         # return 0 ok, 1 broken; print one line either way
}
```

Both functions are optional. `tool_exports` is a shell function rather than a
declarative mapping because the interesting cases are not one-to-one: FoldX exports a
path to a *binary*, Rosetta exports three variables including a build-triple suffix,
and PLACER exports a checkout path that is needed whatever the runtime.

Helpers available inside both functions: `_image_path` (resolves `IMAGE` against
`$CHPC_CONTAINERS`), `_prefix` (expands `PREFIX`), `_refdata <tool>`
(`$CHPC_REFDATA/<tool>`), and `die`.

## Adding a tool

```bash
cp -r _template mytool && $EDITOR mytool/tool.conf mytool/README.md
chpc-tool show mytool            # check it parses and resolves
chpc-tool build mytool           # containers: on the login node
chpc-tool publish mytool         # copy to the share, wrapper, staging, all eight steps
chpc-tool doctor mytool
```

Then commit it here and bump the submodule pin in the project that needed it.

## Why the definitions live in this repo and not in a project

`lab/README.md` has said so since the layout was bootstrapped — step 8 of publishing a
container is *"Commit the `.def` and the wrapper to this repo."* Until now there was
nowhere to put them, so `IgGase_eng` grew a `pipelines/slurm/containers/` that was
going to hold the same files. Two homes for one recipe is how the lab ends up with two
slightly different RFdiffusion images. This directory is that one home.
