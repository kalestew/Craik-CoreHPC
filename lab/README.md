# Lab shared CoreHPC directory

Everything the lab shares on CoreHPC lives on our FAC share
`/mnt/fac/CX500146_DS1` (group `sec_fac_cx500146_ds1`, POSIX ACLs, group
read/write), with a hot mirror on group scratch
`/mnt/scratch/group/CX500146_DS1`. Both exist and were verified writable on
2026-09-17. The share already contains `software/moe2024.0601` and
`moejobs/`; the layout below adds to that rather than moving it.

## Using the tools

If you only want to run the lab's software, add this line to `~/.bashrc` on
the cluster and read [`tools/README.md`](../tools/README.md):

```bash
[ -f /mnt/fac/CX500146_DS1/chpc.env ] && source /mnt/fac/CX500146_DS1/chpc.env
```

That puts `$CHPC_LAB/bin` (and so `chpc-tool`, with Tab completion) on `PATH`,
points the Apptainer and conda caches at scratch, and sets `APPTAINER_BIND` so
containers see scratch and FAC. A project that carries this repo as a
submodule can instead `source <project>/corehpc/env.sh` and get the pinned
copy of `chpc.env` and the pinned registry, without touching the FAC copy. The
rest of this file is about the share itself: what is on it, how it was made,
and how a maintainer publishes to it.

## Layout

```
/mnt/fac/CX500146_DS1/                      $CHPC_LAB  (persistent, canonical; 5 TB)
├── chpc.env                                copy of lab/chpc.env; everyone sources it
├── software/                               native installs (already holds moe2024.0601)
├── moejobs/                                existing MOE job directory
├── bin/                                    on PATH via chpc.env
│   ├── chpc-tool                           resolve/run/build/publish from the tool registry (reads ../tools)
│   ├── chpc-assets                         install and verify licensed payloads and weights
│   ├── chpc-jobstats                       what a finished job should have asked for (reads ../lib/jobstats.awk)
│   ├── chpc-stage-containers               rsync containers/ -> group scratch
│   ├── chpc-fac-fixacl                     repair the owner-deny ACL on things created at the share root
│   ├── chpc-completion.bash                tab completion; chpc.env sources it in interactive shells
│   ├── run-in-container                    the generic wrapper `chpc-tool wrapper` instantiates
│   └── <tool>                              one per published container; prepends ENTRY and nothing else -- prefer chpc-tool exec
├── lib/jobstats.awk                        needed by bin/chpc-jobstats
├── tools/<tool>/tool.conf                  copy of the registry; what bin/chpc-tool reads when no checkout is sourced
├── containers/
│   ├── README.md                           table of images
│   ├── <tool>_<ver>.sif                    immutable images (644)
│   └── defs/<tool>_<ver>.def               recipes (copies; the originals are in git)
├── licenses/<tool>/                        licence files, mode 640, group only
├── envs/<name>.yml                         conda exports
├── data/<tool>/                            model weights and databases. Bound READ-WRITE in jobs (chpc.env); the ACL and file modes protect them, not the bind
├── slurm/                                  shared job templates (copy of templates/slurm)
└── results/<project>/                      final outputs only

/mnt/scratch/group/CX500146_DS1/             hot, volatile
├── containers/                             mirror of $CHPC_LAB/containers (sif only)
└── <project>/                              working dirs, intermediates, logs
```

## Bootstrapping it (done 2026-09-17)

The layout below exists on the share with corrected ACLs. Do not create new
top-level directories from the cluster without running `chpc-fac-fixacl`
on them afterwards (see the FAC ACL quirk in docs/02). For the record, the
steps were:

```bash
source env.sh                   # repo root; edit FAC_SHARE in lab/chpc.env first
mkdir -p $CHPC_LAB/{bin,containers/defs,envs,data,slurm,results}
mkdir -p $CHPC_GROUP_SCRATCH/containers
cp lab/chpc.env $CHPC_LAB/chpc.env
cp lab/bin/* $CHPC_LAB/bin/
cp templates/slurm/* $CHPC_LAB/slurm/
chmod -R g+rwX,o-rwx $CHPC_LAB/{bin,containers,envs,data,slurm,results} $CHPC_LAB/chpc.env
```

`licenses/` was added later, on 2026-09-17, and is the worked example of the
ACL quirk. A new top-level directory inherits a **DENY for the owner** --
`D::OWNER@:rwaDx`, showing as `d---rwx---` -- so the person who created it
cannot write to it. `chpc-fac-fixacl` is not optional here:

```bash
mkdir -p $CHPC_LAB/licenses
$CHPC_LAB/bin/chpc-fac-fixacl $CHPC_LAB/licenses
```

That leaves `drwxrwx---`, owner `:sec_fac_cx500146_ds1`, with the same ACL as
`software/` and `envs/`: group read/write, `EVERYONE@` limited to `tcy`, so
nothing outside the lab can read it. The directory is group-writable because
lab members need to add licences to it; the **files** inside are what get the
tighter mode, 640, and `chpc-assets install` sets that.

### Keeping the share's copy current

Nothing syncs the checkout to the share. `chpc-tool doctor` warns when the
share's `chpc.env` differs from the checkout's; the rest is by hand, from the
repo root on the login node, after every change to `lab/`, `tools/` or
`templates/slurm/`:

```bash
cp lab/chpc.env "$CHPC_LAB/chpc.env"
cp lab/bin/* "$CHPC_LAB/bin/"
mkdir -p "$CHPC_LAB/lib" && cp lab/lib/* "$CHPC_LAB/lib/"
rsync -a --delete --exclude='*.sif' --exclude='*.tar' tools/ "$CHPC_LAB/tools/"
cp templates/slurm/* "$CHPC_LAB/slurm/"
```

`tools/` and `lib/` are what the published `chpc-tool` and `chpc-jobstats`
resolve beside themselves (`../tools`, `../lib`); without them the share's
`chpc-tool` dies with "no tool registry found". Whether both exist on the
share today has not been checked from a laptop: `ls "$CHPC_LAB"/{tools,lib}`
on the login node, and if either is missing, the block above creates it,
followed by `chpc-fac-fixacl` on each new top-level directory (above).

## Publishing a container

The full sequence, from `tool.conf` to `STATUS=verified`, is
[`tools/README.md`, "Add a tool"](../tools/README.md#add-a-tool). On this
share, `chpc-tool publish <tool>` does the mechanical part in one command:
copies the built image from `$CHPC_USER_SCRATCH/apptainer/` to
`$CHPC_LAB/containers/` at mode 644, copies the `.def` into
`containers/defs/`, writes the `$CHPC_LAB/bin/<tool>` wrapper from
`bin/run-in-container`, appends a row to `containers/README.md`, and runs
`chpc-stage-containers`.

Doing it by hand instead is fine, and doc 07 spells the raw commands out. The
rules that matter either way: never modify a published `sif` (a new version is
a new filename), every image keeps its `.def` so it can be rebuilt after a CVE
or a loss, and the scratch mirror needs refreshing after every publish and
after every quarterly purge.

For anything that is not a container — a native build, a conda environment, a
licensed binary — the entry is the same shape with a different `KIND`, and
`chpc-assets` handles the payloads. See [`../tools/README.md`](../tools/README.md).
