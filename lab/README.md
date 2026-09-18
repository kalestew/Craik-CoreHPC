# Lab shared CoreHPC directory

Everything the lab shares on CoreHPC lives on our FAC share
`/mnt/fac/CX500146_DS1` (group `sec_fac_cx500146_ds1`, POSIX ACLs, group
read/write), with a hot mirror on group scratch
`/mnt/scratch/group/CX500146_DS1`. Both exist and were verified writable on
2026-09-17. The share already contains `software/moe2024.0601` and
`moejobs/`; the layout below adds to that rather than moving it.

```
/mnt/fac/CX500146_DS1/                      $CHPC_LAB  (persistent, canonical; 5 TB)
├── chpc.env                                copy of lab/chpc.env; everyone sources it
├── software/                               native installs (already holds moe2024.0601)
├── moejobs/                                existing MOE job directory
├── bin/                                    wrappers; add to PATH via chpc.env
│   ├── chpc-tool                           resolve/run/build/publish from the tool registry
│   ├── chpc-assets                         install and verify licensed payloads and weights
│   ├── chpc-stage-containers               rsync containers/ -> group scratch
│   ├── chpc-fac-fixacl                     repair the owner-deny ACL on things created at the share root
│   └── <tool>                              one per container (chpc-tool wrapper writes these)
├── containers/
│   ├── README.md                           table of images
│   ├── <tool>_<ver>.sif                    immutable images (644)
│   └── defs/<tool>_<ver>.def               recipes (copies; the originals are in git)
├── software/                               native installs (already holds moe2024.0601)
├── licenses/<tool>/                        licence files, mode 640, group only
├── envs/<name>.yml                         conda exports
├── data/<tool>/                            model weights and databases, read-only in jobs
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

## Every lab member

Add to `~/.bashrc` on the cluster:

```bash
[ -f /mnt/fac/CX500146_DS1/chpc.env ] && source /mnt/fac/CX500146_DS1/chpc.env
```

That puts `$CHPC_LAB/bin` on `PATH`, points Apptainer caches and conda at
scratch, and sets `APPTAINER_BIND` so containers see scratch and FAC.

A project that carries this repo as a submodule can instead
`source <project>/corehpc/env.sh` on the login node and get the pinned copy
of `chpc.env`, plus the `chpc-*` scripts, without touching the FAC copy.

## Publishing a new container

Every tool is declared once, in the registry at [`../tools/`](../tools/README.md),
and `chpc-tool` does the mechanical parts from that declaration. The eight
steps below are still what happens; steps 3 to 7 are now one command.

1. Write the entry: `cp -r ../tools/_template ../tools/mytool`, then edit
   `tool.conf` and drop `mytool_1.2.def` beside it.
2. `chpc-tool build mytool` — on the login node, the only one with internet.
3. Test it in an interactive job: `chpc-tool exec mytool -- mytool --version`.
4. `chpc-tool publish mytool` — copies the image to `$CHPC_LAB/containers/` at
   mode 644, copies the `.def` into `defs/`, writes the `$CHPC_LAB/bin/mytool`
   wrapper from `bin/run-in-container`, adds a row to the container README and
   runs `chpc-stage-containers`.
5. Set `STATUS=verified` and fill in `UPSTREAM_REF` in `tool.conf`, write the
   entry's `README.md`, and commit **to this repo**.
6. In each project that wants it, bump the submodule pin.

Doing it by hand instead is fine, and doc 07 spells the raw commands out. The
rules that matter either way: never modify a published `sif` (a new version is
a new filename), every image keeps its `.def` so it can be rebuilt after a CVE
or a loss, and the scratch mirror needs refreshing after every publish and
after every quarterly purge.

For anything that is not a container — a native build, a conda environment, a
licensed binary — the entry is the same shape with a different `KIND`, and
`chpc-assets` handles the payloads. See [`../tools/README.md`](../tools/README.md).
