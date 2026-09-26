# 7. Containers with Apptainer (and sharing them across the lab)

Apptainer 1.5.2 (formerly Singularity; `singularity` still works as an
alias) is installed on every CoreHPC node, no module needed. It runs as your own user, mounts `$HOME`, `/tmp` and the
current directory by default, and needs no root to run. It is the right
way to package software for the lab: one `.sif` file on FAC, one wrapper
script, everybody gets the identical environment in their job scripts.

## Vocabulary

| Thing | Meaning |
|-------|---------|
| `.sif` | immutable single-file image; what you run and share |
| `.def` | definition file; recipe to build a `.sif` (keep it in git, next to the image) |
| sandbox | writable directory image for development (`--sandbox`) |
| `apptainer pull` | fetch an existing image (Docker Hub, NGC, GHCR, quay, library) into a `.sif` |
| `apptainer build` | build a `.sif` from a `.def`, a Docker image, a tar, or a sandbox |
| `--nv` | expose NVIDIA GPUs + driver libs inside the container |
| `--bind` | mount host paths inside the container |

## One-time environment setup (per user)

Apptainer caches layers and builds under `~/.apptainer` by default, which
kills the 20 GiB home quota. Put this in `~/.bashrc` (or source `lab/chpc.env`):

```bash
export APPTAINER_CACHEDIR=/mnt/scratch/user/$USER/apptainer/cache
export APPTAINER_TMPDIR=/mnt/scratch/user/$USER/apptainer/tmp
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"
```

Both are volatile scratch; that is fine, they are caches.

## Getting images: the easy path (pull)

Only the login node has internet, so pull there:

```bash
cd /mnt/scratch/user/$USER/apptainer
apptainer pull pytorch_24.01.sif docker://nvcr.io/nvidia/pytorch:24.01-py3
apptainer pull samtools.sif docker://quay.io/biocontainers/samtools:1.20--h50ea8bc_0
apptainer pull colabfold.sif docker://ghcr.io/sokrypton/colabfold:1.5.5-cuda12.2.2
apptainer pull rocky.sif library://library/default/rockylinux:9   # if the library endpoint is reachable
```

Test on a compute node, then promote to the lab share (below).

## Building your own image

### Option A: build on the login node (usual case)

Verified 2026-09-17: unprivileged builds work on the login node with the
plain command (user namespaces are allowed; an Ubuntu 22.04 image with
`apt-get install python3` in `%post` built in 85 s). `--fakeroot` is NOT
available (no `/etc/subuid` entry) and fails; do not use it. Apptainer
instead injects a `fakeroot` shim into `%post`, which needs glibc, so
Alpine/musl-based images fail with `exec /.singularity.d/libs/fakeroot
failed: a shared library is likely missing`; add
`--ignore-fakeroot-command` for those (verified). The login node's proxy
variables are inherited by the build, so `apt`, `pip`, `conda` inside
`%post` reach the internet there and only there. Keep builds modest; the
login node kills heavy processes, so compile large code in a sandbox in an
interactive job instead (Option C).

### What "modest" is, in numbers

Building here is not a workaround, it is the only option: `%post` needs
the network and the login node is the only node that has it (doc 02). So
the question is never *whether* to build here, only whether a given recipe
is small enough. The budget, read off the user slice 2026-09-18:

| Limit | Value | What happens at it |
|---|---|---|
| `cpu.max` | `400000 100000` = **4 CPUs** | hard ceiling; a parallel build just thrashes |
| `memory.high` | **8 GiB** | *soft*: kernel throttles and reclaims — the build crawls |
| `memory.max` | **16 GiB** | hard: OOM kill |
| `pids.max` | 8192 | |

The rule that follows: **a `%post` that only fetches is fine at any size;
a `%post` that computes is not.** `apt-get` of prebuilt debs, `pip` of
prebuilt wheels, `curl`, `git clone` are all I/O against a 4-CPU cap, and
the only real CPU burst is the squashfs compression at the end, which is
bounded by image size. Measured on this cluster: foldseek 86 s, mmseqs2
120 s, pymol 267 s, ProteinMPNN (3.37 GB) a few minutes. None came near a
kill.

Two things genuinely do push against the 8 GiB soft limit, and both are
solvers rather than compilers:

- **`conda install`** — the classic depsolver is the heaviest thing most
  recipes ever run. Force the C++ solver with `CONDA_SOLVER=libmamba`
  (or call `mamba`); it is both faster and dramatically lighter.
- **`pip` backtracking** — an unsatisfiable or under-pinned requirement set
  makes pip download and unpack candidate after candidate. Pin exactly, and
  prefer `--no-deps` plus explicit dependencies over letting pip explore.

Anything that runs `make -j` belongs in Option C, and `-j` should be at
most 4 even there if you stay on the login node.

```bash
cd $CHPC_LAB/containers/defs      # keep .def files with the images
apptainer build ../mytool_1.0.sif mytool_1.0.def
# Alpine / musl base images only:
apptainer build --ignore-fakeroot-command ../mytool_1.0.sif mytool_1.0.def
```

`templates/apptainer/build.sh` does this, and retries with
`--ignore-fakeroot-command` **only** when the log actually says
`libs/fakeroot failed`. Apptainer prints that suggestion after any failed
`%post`, so retrying on it blindly doubles the wall time of every genuine
recipe error — ten minutes each, on a login node capped at 4 CPUs, to
reproduce a failure you already have.

Minimal definition file (`templates/apptainer/minimal.def`):

```
Bootstrap: docker
From: ubuntu:22.04

%post
    apt-get update && apt-get install -y --no-install-recommends python3 python3-pip && rm -rf /var/lib/apt/lists/*
    pip3 install --no-cache-dir numpy

%environment
    export LC_ALL=C.UTF-8

%runscript
    exec "$@"

%labels
    Author Craik Lab
    Version 1.0

%help
    Run: apptainer exec mytool_1.0.sif python3 script.py
```

Other useful sections: `%files src dst` (copy files in at build time),
`%test` (run after build), `Bootstrap: localimage` / `From: base.sif`
(layer on top of an existing sif, e.g. the NGC PyTorch image).

Conda inside a container (`templates/apptainer/conda-env.def`) uses a
Miniforge base and `environment.yml`, which is the most reproducible way to
freeze a Python stack for the lab.

### Option B: build on your Mac with Docker, ship the tarball

Useful when the recipe needs real root, lots of CPU, or you already have a
Dockerfile. Apple Silicon must target `linux/amd64` (all CoreHPC nodes are
x86_64).

```bash
docker buildx build --platform linux/amd64 -t mytool:1.0 .
docker save mytool:1.0 -o mytool_1.0.tar
scripts/chpc-stage.sh mytool_1.0.tar /mnt/scratch/user/$USER/apptainer/
# on the login node:
apptainer build mytool_1.0.sif docker-archive:///mnt/scratch/user/$USER/apptainer/mytool_1.0.tar
```

(Or push the Docker image to GHCR/Docker Hub and `apptainer pull docker://...` on the login node.)

### Option C: develop in a sandbox, then freeze

```bash
# login node (internet): create the writable sandbox from a base
apptainer build --sandbox mytool_dev docker://ubuntu:22.04
# compute node (CPU): compile / install interactively
salloc -p cpu -c 16 --mem 32G -t 4:00:00
apptainer shell --writable mytool_dev                 # (--fakeroot is not available on CoreHPC)
# ... apt-get/pip/make (anything needing internet must be fetched on the login node first) ...
exit; exit
# login node: freeze it
apptainer build mytool_1.0.sif mytool_dev
```

Sandboxes are directories with many small files; keep them on scratch and
delete them once frozen. Always regenerate the `.def` so the build is
reproducible; a sif from a sandbox is a snapshot, not a recipe.

## A plain `export` does not always reach the container

Apptainer passes the host environment in, so this usually works and everyone
assumes it always does. It does not. If the image's own `%environment` sets
the same name, **the image wins** — and it wins even when the image was
written defensively as `${VAR:-default}`, because at the point that line runs
the host value is not in scope. Measured on Apptainer 1.5.2, 2026-09-18:

| How you pass it | Inside the container |
|---|---|
| `export VAR=/host` | `/tmp/default` — **silently lost** |
| `export APPTAINERENV_VAR=/host` | `/host` |
| `apptainer exec --env VAR=/host` | `/host` |
| `export VAR=/host`, name unset in image | `/host` |

The last row is why this is so easy to miss: most variables *do* pass through,
so the mechanism looks reliable until you meet a tool whose image sets a
fallback for the very name you are trying to override.

It cost us 1.3 GB. `chai1`'s image sets `CHAI_DOWNLOADS_DIR` to
`/tmp/chai-downloads` as a last-resort fallback; the registry pointed it at
the FAC share; the container used `/tmp` anyway. Nothing errored — the weights
just landed somewhere per-node that gets wiped, which on a compute node with
no internet means every job re-downloads and then fails.

`chpc-tool` now emits and exports both forms for everything in
`tool_exports`, so a registry value overrides an image default. If you call
`apptainer` directly, prefix by hand or use `--env`.

## The commonest way a recipe passes `%post` and fails anyway

A `.sif` is a **read-only** squashfs, but `%post` runs against a writable
sandbox. So any package that writes inside its own installed location works
perfectly while you build it and fails the moment it is an image. Three of the
entries in `tools/` hit this, each differently:

| Tool | What it writes | Symptom | Fix |
|---|---|---|---|
| boltz | numba JIT cache, from `@numba.njit(cache=True)` at module scope | `RuntimeError: cannot cache function '_prepare_msa_arrays_inner': no locator available` — at *import*, before any input | `NUMBA_CACHE_DIR=/tmp/numba-cache` in `%environment` |
| rfdiffusion | `schedules/` for its IGSO3 tables, mkdir'd inside the package | permission error on first run | pass `inference.schedule_directory_path` |
| chai1 | model downloads, default inside `site-packages` | tries to download into a read-only path | `CHAI_DOWNLOADS_DIR` |
| rfdiffusion3 | `tempfile(dir=os.getcwd())` staging | `OSError: [Errno 30] Read-only file system: '/app/foundry/.tmp_…'` mid-download | `cd` somewhere writable first |

That last one is a variant worth naming separately, because nothing in the
recipe or the command mentions the offending path. Apptainer sets the
container's working directory to the host's — but when the host's cwd does
not exist inside the container it falls back to the image's Docker `WORKDIR`,
which is usually somewhere in the read-only layer. Any tool that writes
relative to `.` then fails in a way that points at the image rather than at
your shell. `cd` to a bound, writable directory before running, or pass
`apptainer --pwd`.

**`%test` is what catches these, and `%post` structurally cannot.** `%test`
runs against the built image, so it is the only part of a recipe that sees the
real filesystem semantics. That is the argument for putting a genuine
import-and-run in `%test` rather than a `--version` check: for this whole class
of bug, `%post` will tell you everything is fine.

Two habits that avoid the class entirely:

- Point anything cache-like at `/tmp` with an overridable default —
  `export FOO_CACHE="${FOO_CACHE:-/tmp/foo}"`. On CoreHPC `/tmp` is local
  NVMe on every compute node (doc 05) and per-node, so concurrent jobs do not
  share one file.
- Point anything data-like at the registry, not at `/tmp` and not at a path
  baked into the image. `CHPC_REFDATA` exists for exactly this, and a share
  path compiled into a recipe makes that recipe wrong for the next lab.

## Four more ways a green build produces a broken image

Three added 2026-09-25 from building `tools/protenix`, `tools/intellifold` and
`tools/openfold3`; the fourth consolidates what four entries had each written
about the same failure. Each cost a rebuild; none was visible in `%post`.

### `pip install --upgrade pip` cannot work on an Ubuntu 24.04 base

```
ERROR: Cannot uninstall pip 24.0, RECORD file not found.
       Hint: The package was installed by debian.
```

Noble marks its interpreter externally managed (PEP 668) and ships pip through
dpkg with no `RECORD`, so pip cannot replace itself whatever flag it is given.
`--break-system-packages` works for ordinary packages and cannot work for that
one, which is the awkward part: the recipe looks consistent and fails on
exactly one line, minutes into a build.

Use a virtual environment -- `python3.12 -m venv /opt/venv` -- and then remember
the two things that follow from it:

- put `/opt/venv/bin` on `PATH` in **`%environment`**, or the console scripts
  the image exists to run are not found and the failure reads as a broken
  install;
- put it on `PATH` in **`%post` too**. `tools/protenix` installed `ninja`
  correctly and still died with `RuntimeError: Ninja is required to load C++
  extensions`, because torch verifies ninja by *running* `ninja --version` as a
  subprocess -- importable is not enough -- and nothing had added the venv's
  bin directory to the build shell's `PATH`.

### A CUDA `-devel` base can shadow the CUDA wheels pip installs

`tools/intellifold` is built on `nvidia/cuda:12.8.1-cudnn-devel-ubuntu24.04`,
so `/usr/local/cuda/lib64` holds CUDA 12.8's `libcusparse.so.12` and the Docker
image puts that directory at the front of `LD_LIBRARY_PATH`. jax 0.9.1's cuda12
plugin is built against the **12.9** wheels pip installs beside it under
`site-packages/nvidia/*/lib`. The 12.8 copies win, the plugin fails its version
probe, and jax says:

```
Jax plugin configuration error: ... cusparseGetProperty(MAJOR_VERSION, &major)
  failed: The cuSPARSE library was not found.
RuntimeError: Unknown backend: 'gpu' requested, but no platforms that are
  instances of gpu are present. Platforms present are: cpu
```

The second line is what an operator sees, and it is a **lie about the
hardware**: both failing jobs were on H100 nodes whose `nvidia-smi` had printed
the device two lines earlier. Prepend the wheel directories in `%environment`:

```sh
for _d in /opt/venv/lib/python3.12/site-packages/nvidia/*/lib; do
    [ -d "$_d" ] && LD_LIBRARY_PATH="$_d:${LD_LIBRARY_PATH:-}"
done
export LD_LIBRARY_PATH
```

### An import is not a `%test` when the thing you are testing is lazy

The section above says `%test` is what catches a read-only-filesystem bug and
`%post` structurally cannot. There is a second class it only catches if the
test does real work: **anything initialised lazily**.

`python -c "import jax"` passed on all three builds of the image above, because
jax does not load its CUDA plugin until something asks for a device. The check
that catches it needs no GPU:

```sh
python - <<'PY'
import jax
try: jax.devices("gpu")
except Exception as exc: message = str(exc)
else: message = ""
for bad in ("was not found", "cannot open shared object", "libcu"):
    if bad in message and "cuInit" not in message:
        raise SystemExit("broken image, not a missing device: " + message)
PY
```

On a login node the two outcomes are distinguishable and only one is a bug:

| message | meaning |
|---|---|
| `The cuSPARSE library was not found` | the image cannot load its CUDA libraries |
| `cuInit(0) failed: Unknown CUDA error 303` | there is simply no driver here, which is correct |

The same shape applies to anything that JIT-compiles on first use.
`tools/protenix` imports a module that calls `torch.utils.cpp_extension` on a
`.cu` source **at import time, with no fallback**, so it needs `nvcc` in the
image and not merely `cc` -- and a `-slim` base passes a plain
`import protenix` and dies on the first real job.

### A kernel that compiles at first use needs a compiler in the image

`boltz_2.sif` is built from `python:3.12-slim` with only `git` and
`ca-certificates`. Its cuequivariance kernels are Triton, which JIT-compiles
them at first use, so every prediction above about 128 total tokens dies four
seconds in with `RuntimeError: Failed to find C compiler` from
`triton/runtime/build.py`, having written nothing. The self-test passed the
entire time, because a 31-mer never reaches the kernel path. Measured
2026-09-22 on an L40S: 31 and 71 residues predict, 142 fail, and so does every
larger input. Job array 1928395 in a sibling project lost all five tasks in
under a minute each to exactly that error.

The trap has more than one form, and which one an image has decides what it
must carry:

| Form | Compiles with | Needs in the image | Registry examples |
|---|---|---|---|
| Triton kernels (cuequivariance) | `cc` shelled out at first use | a C compiler, or a documented off switch | boltz: `boltz_2.sif` had none, so `--no_kernels`; `boltz_2_gcc.def` adds `gcc` and `libc6-dev` and its `%post` builds a launcher against `Python.h` rather than checking `command -v gcc` |
| `torch.utils.cpp_extension` on a `.cu` source | `nvcc` at import | a `-devel` base, not `-runtime` | protenix: `build-essential` plus nvcc, asserted in `%post` and `%test` |
| DeepSpeed JIT ops | `nvcc`, a C++ compiler, `ninja` at first use | the same | openfold3: full toolchain, `-devel` base |
| XLA (jax) | LLVM in-process, but reaches for `ptxas`/`nvlink` | the CUDA toolkit, so `-devel` | intellifold: toolchain kept, `XLA_FLAGS` default set in `%environment` |
| nothing | -- | nothing; `%post` prints whether numba, cython or triton are present so a future fast path shows up in the build log | dockq |

Three rules follow. Assert `cc` (and `nvcc` where an import needs it) in
`%post` **and** `%test`, and have `tool_doctor` probe the built image for it,
so a rebuild from a slimmer base is noticed rather than discovered by a job.
Point `NUMBA_CACHE_DIR`, `TRITON_CACHE_DIR`, `TORCHINDUCTOR_CACHE_DIR` and
`TORCH_EXTENSIONS_DIR` at `/tmp` in `%environment`, because a `.sif` is a
read-only squashfs and anything that caches beside its own source refuses at
import time inside one. And size the self-test to reach the kernel path: the
check that catches this is a real prediction above the token threshold, not an
import, not `--help`, not a short peptide.

## `%post` writing to `/tmp` is writing to the build machine

Apptainer binds the **host's** `/tmp` into `%post`. So a recipe that stages
something in `/tmp` is not putting it in the image — it is putting it on the
login node, where it stays after the build ends.

The first build works, because `/tmp/<thing>` does not exist yet. Then the
build fails for an unrelated reason, leaves its scratch behind, and every
rebuild after that dies on something that looks nothing like a bind:

```
git clone https://github.com/baker-laboratory/PLACER /tmp/PLACER
fatal: destination path '/tmp/PLACER' already exists and is not an empty
directory
```

`tools/placer` hit exactly this. Nothing in the recipe or the error mentions
`/tmp` being shared, and the obvious reading — "git is confused" or "the
previous build did not clean up after itself *inside the image*" — sends you
looking in the wrong filesystem. Worse, a recipe that *succeeds* this way has
silently depended on host state, so it builds on your machine and not on a
colleague's.

Stage build-time scratch somewhere that is genuinely inside the image —
`/opt/<tool>-selfcheck` is the convention here — and `rm -rf` it first so the
step is idempotent regardless. Note this cuts the opposite way from
`NUMBA_CACHE_DIR` above: `/tmp` is right for a **runtime** cache, precisely
*because* it is the host's (local NVMe, per-node), and wrong for **build**
scratch for exactly the same reason.

## Nothing in a pinned-torch image goes through a conda solve

The pytorch base images are conda images, so `conda install` is right there
and looks like the supported way to add a C++ dependency. It is not, and the
failure is not the one you would brace for.

`tools/placer` needed openbabel, which genuinely has no official PyPI wheel.
One `conda install -c conda-forge openbabel=3.1.1`, with conda-forge at top
priority, did this:

```
pytorch   2.3.1-py3.10_cuda12.1_cudnn8.9.2_0 --> 2.0.1-py3.10_cpu_0
pytorch-mutex                       1.0-cuda --> 1.0-cpu
mkl                                 2023.1.0 --> 2025.0.0
numpy                                 1.26.4 --> 2.2.5
```

The solver is not adding a package, it is re-solving the whole environment,
and `pytorch-mutex` lets it satisfy the constraints with a **CPU build**.

It surfaced as `libtorch_cpu.so: undefined symbol: iJIT_NotifyEvent`, which is
the mkl-2025/torch mismatch and reads like a packaging bug — so the tempting
fix is to pin mkl. That fix is wrong twice over. The symbol was a symptom, and
had mkl stayed compatible the build would have **succeeded** and shipped a
CUDA image whose torch had no CUDA. The crash was the lucky outcome.

So:

- Prefer a pip wheel, even an unofficial repackaging of the upstream source,
  over a conda solve in an image whose torch is pinned. `openbabel-wheel` is
  openbabel's own 3.1.1 built for manylinux; it installs in seconds where the
  solve took an hour, and cannot touch torch.
- If conda is genuinely unavoidable, install into a **separate prefix** and
  reach it by `PYTHONPATH`, so the solver has no opportunity to rewrite the
  environment torch lives in.
- Either way, **assert it afterwards.** Care is not a mechanism:

  ```python
  assert torch.version.cuda == "12.1", f"not a cu121 torch: cuda={torch.version.cuda}"
  ```

  A CPU build reports `torch.version.cuda is None`, so this fails the build on
  exactly the substitution above. Every recipe here that pins a torch now
  carries it.

The reason this is written up rather than filed as one tool's bug: the placer
recipe *already contained the warning*. Three paragraphs above the offending
line, a comment explains that installing e3nn through conda "can replace the
cu121 torch this entire stack is pinned to". The reasoning was correct and was
applied to one package. A rule that lives in a comment next to one install
line is not a rule.

## Running containers

For a tool in the registry, `chpc-tool exec <tool> -- <program> <args>` does
everything in this section for you (`tools/README.md`, "Run a tool on your
inputs"). What follows is the raw form it wraps.

```bash
apptainer exec image.sif <command>             # run one command
apptainer run image.sif [args]                  # run the %runscript
apptainer shell image.sif                       # interactive shell inside
apptainer inspect image.sif                     # labels, help, def file (--deffile)
apptainer exec --nv image.sif nvidia-smi        # GPU
```

### Bind mounts (important on CoreHPC)

`$HOME`, `/tmp` and `$PWD` are bound automatically. `/mnt/scratch` and
`/mnt/fac` are NOT: the site config binds only `/etc/localtime` and
`/etc/hosts` (verified; `user bind control = yes`, `mount home = yes`).
Add them explicitly, and use the same path inside as outside so scripts
work identically with and without the container:

```bash
apptainer exec --nv --bind /mnt/scratch,/mnt/fac image.sif python train.py
```

`lab/chpc.env` exports `APPTAINER_BIND=/mnt/scratch,/mnt/fac`, so after
sourcing it (or `env.sh`) the `--bind` flag is unnecessary. Passing both
still works but logs `WARNING: ... destination is already in the mount
point list` twice per job; the templates therefore rely on the variable
and only the manual examples above spell out `--bind`.

`--containall` isolates `$HOME` and env vars (cleaner, avoids your
`~/.local` Python packages leaking into the container); `--cleanenv` just
drops host env vars. `--pwd /path` sets the working directory.

### In a SLURM job

```bash
#!/bin/bash
#SBATCH -p gpu --gres=gpu:1 -c 8 --mem 32G -t 4:00:00
source "${CHPC_ENV:-/mnt/fac/CX500146_DS1/chpc.env}"     # sets APPTAINER_BIND, CHPC_CONTAINERS
srun apptainer exec --nv $CHPC_CONTAINERS/pytorch_24.01.sif python train.py
```

Mix host steps and container steps freely; each `srun` is a job step. MPI
inside a container works with `srun apptainer exec mpi_app.sif ./binary`
provided the container's MPI matches the host's (OpenMPI 5 / PMIx); NGC
images generally do.

## Sharing containers across the lab (our convention)

Layout on FAC (persistent, canonical) with a hot copy on group scratch:

```
$CHPC_LAB = /mnt/fac/CX500146_DS1                the share root; lab/chpc.env sets it
$CHPC_LAB/containers/<tool>_<version>.sif     immutable; never overwrite, bump the version
$CHPC_LAB/containers/defs/<tool>_<version>.def a COPY of the recipe; the original is in git, at tools/<tool>/
$CHPC_LAB/containers/README.md                one line per image: what, version, who built, date, how to run
$CHPC_LAB/bin/<tool>                          wrapper: chpc-tool exec <tool> -- <entry> "$@" (tools/README.md, "The published wrapper")
/mnt/scratch/group/CX500146_DS1/containers/    rsync'd copy for fast start-up (lab/bin/chpc-stage-containers)
```

**Which of the two a job gets.** `lab/chpc.env` points `CHPC_CONTAINERS` at the
scratch mirror when that DIRECTORY exists, else at `$CHPC_LAB/containers`. That
choice is made once, for every image at once, and it cannot notice that the
mirror is missing the particular image you asked for — which happens on a
schedule, because group scratch is purged at 30 days while the FAC copy stays.

`chpc-tool` therefore resolves **per image**: it prefers the mirror, and falls
back to `$CHPC_LAB/containers` for any image the mirror lacks. `exec`, `test`,
`doctor` and the `SIF_*` variables `chpc-tool export` emits all go through that
one path, so all four degrade to the slower correct copy instead of failing.
`doctor` says so when it happens — `[not in the scratch mirror -- run
chpc-stage-containers]` — because a silent fallback is how a purge goes
unnoticed until somebody wonders why jobs got slower.

A script that interpolates `$CHPC_CONTAINERS/<image>.sif` by hand does NOT get
that fallback; one variable cannot express a per-image answer. Prefer
`chpc-tool path <tool>` or the `SIF_*` from `chpc-tool export`.

**Reading an entry from something that is not a shell.** A `tool.conf` is
sourced shell and its values are produced by shell, so the only faithful reader
of one is a shell. That leaves a Python or Go consumer two bad choices —
reimplement bash's quoting rules, or copy the registry's values into a second
file that goes stale the first time an image is rebuilt. `show --env` is the
third:

```console
$ chpc-tool show --env boltz
NAME='boltz'
KIND='container'
STATUS='verified'
GPU_MAX_CC=''
IMAGE='boltz_2.sif'
IMAGE_PATH='/mnt/scratch/group/CX500146_DS1/containers/boltz_2.sif'
IMAGE_MIRROR='/mnt/scratch/group/CX500146_DS1/containers/boltz_2.sif'
IMAGE_CANONICAL='/mnt/fac/CX500146_DS1/containers/boltz_2.sif'
EXPORT_SIF_BOLTZ='/mnt/scratch/group/CX500146_DS1/containers/boltz_2.sif'
EXPORT_BOLTZ_CACHE='/mnt/fac/CX500146_DS1/data/boltz'
```

One shell-quoted assignment per line, one record per entry, blank line between
records; no argument means every entry. `IMAGE_PATH` is the resolved answer —
the same `_image_path` `exec` uses — with both candidates beside it so a caller
diagnosing *which copy and why* does not have to reimplement the choice.
`EXPORT_*` are the entry's own exports, evaluated rather than echoed. `NOTE` is
deliberately absent: it is prose for a person reading plain `show`, it is the
one field that routinely carries quotes and backticks, and no consumer acts on
it. A value carrying a newline is refused rather than emitted, because a
line-oriented format that can turn one value into two lines is not a format.

Hap108or consumes this: its CoreHPC profile names the *entry* and this answers
with the path, so the filename lives in one place. See its ADR 0021.

Rules:

1. Build or pull into your own scratch, test in an interactive job, then
   `cp` to `$CHPC_LAB/containers/` and `chmod 644`. Group-readable, not writable by others.
2. Never modify a published sif. New version = new file name, and `IMAGE` in
   the entry's `tool.conf`; the wrapper reads the registry at run time.
3. Every image gets a `.def` (or the `docker://` URL in the README) so it
   can be rebuilt after a CVE or when the image is lost.
4. The supported way to run a tool is `chpc-tool exec <tool> -- <program>`
   (`tools/README.md`). `publish` also writes a `$CHPC_LAB/bin/<tool>` wrapper,
   which since 2026-09-26 is that same `exec` with the tool's default program
   always prepended, so it carries the exports, the GPU guard, the per-image
   fallback and `--writable-tmpfs` too.
5. Jobs read the sif from group scratch when present (fast VAST), falling
   back to FAC. `lab/bin/chpc-stage-containers` refreshes the scratch copy;
   run it after publishing and after each quarterly purge.
6. Reference data goes in `$CHPC_LAB/data/<tool>` (`$CHPC_REFDATA`) and is
   reached at the same path inside the container through the plain `/mnt/fac`
   bind. It is bound read-write, because rfdiffusion, boltz and chai populate
   caches there on first use; the NFSv4 ACL and file modes are what protect it.

`lab/README.md` and `lab/bin/` implement this.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `mount /mnt/fac->/mnt/fac error: destination /mnt/fac doesn't exist in container`, then `while running %post section: exit status 255` | **`APPTAINER_BIND` leaking into the build.** `chpc.env` exports `APPTAINER_BIND=/mnt/scratch,/mnt/fac` on every node, and `apptainer build` honours it while running `%post` — against a base image with no `/mnt/fac` to mount onto. `unset APPTAINER_BIND` before building; `templates/apptainer/build.sh` now does. Binds are a runtime concern, never a build one. Verified 2026-09-17. |
| `error: externally-managed-environment` from `pip` in `%post`, then `exit status 1` | **PEP 668.** The `pytorch/pytorch` images ship a conda python marked EXTERNALLY-MANAGED, so a bare `pip install` refuses. Apptainer then suggests `--ignore-fakeroot-command`, which is unrelated and wastes a second full build. `export PIP_BREAK_SYSTEM_PACKAGES=1` at the top of `%post`: inside a container the system interpreter *is* the environment, so there is nothing to protect it from. Verified 2026-09-17. |
| `exec /.singularity.d/libs/fakeroot failed: a shared library is likely missing` | Alpine/musl base: add `--ignore-fakeroot-command` |
| `%post` step needs real root (chown, setuid, systemd) | not possible here; build on your Mac (Option B) |
| `--fakeroot` errors | it is not enabled on CoreHPC; drop the flag |
| `no space left on device` while building | `APPTAINER_TMPDIR`/`CACHEDIR` still on home; set them to scratch |
| `Disk quota exceeded` | same |
| Command not found inside | `$PATH` inside container; use absolute path or fix `%environment` |
| Cannot see `/mnt/scratch` | `--bind /mnt/scratch,/mnt/fac` |
| GPU not visible | `--nv`; and the job must have `--gres=gpu:N` |
| Pull times out in a job | compute nodes have no internet; pull on the login node |
| Host Python packages interfere | `--containall` or `export PYTHONNOUSERSITE=1` |
| Slow start from FAC | stage sif to group scratch (`chpc-stage-containers`) |
