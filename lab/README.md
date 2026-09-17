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
│   ├── chpc-stage-containers               rsync containers/ -> group scratch
│   ├── chpc-fac-fixacl                     repair the owner-deny ACL on things created at the share root
│   └── <tool>                              one per container (see lab/bin/run-in-container)
├── containers/
│   ├── README.md                           table of images
│   ├── <tool>_<ver>.sif                    immutable images (644)
│   └── defs/<tool>_<ver>.def               recipes
├── envs/<name>.yml                         conda exports
├── data/                                   reference data, read-only in jobs
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

1. Build/pull into `/mnt/scratch/user/$USER/apptainer/` (doc 07).
2. Test in an interactive job.
3. `cp tool_1.2.sif $CHPC_LAB/containers/ && chmod 644 $CHPC_LAB/containers/tool_1.2.sif`
4. `cp tool_1.2.def $CHPC_LAB/containers/defs/`
5. Add a wrapper: `cp lab/bin/run-in-container $CHPC_LAB/bin/tool` and edit
   the two variables at the top (`IMAGE`, `GPU`).
6. Add a row to `$CHPC_LAB/containers/README.md`.
7. `chpc-stage-containers` to mirror to group scratch.
8. Commit the `.def` and the wrapper to this repo.
