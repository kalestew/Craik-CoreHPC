# Lab shared CoreHPC directory

Everything the lab shares on CoreHPC lives in one directory on our FAC
share, with a hot mirror on group scratch. Set the share name once in
`lab/chpc.env`.

```
/mnt/fac/<FAC_SHARE>/chpc/                  $CHPC_LAB  (persistent, canonical)
├── chpc.env                                copy of lab/chpc.env; everyone sources it
├── bin/                                    wrappers; add to PATH via chpc.env
│   ├── chpc-stage-containers               rsync containers/ -> group scratch
│   └── <tool>                              one per container (see lab/bin/run-in-container)
├── containers/
│   ├── README.md                           table of images
│   ├── <tool>_<ver>.sif                    immutable images (644)
│   └── defs/<tool>_<ver>.def               recipes
├── envs/<name>.yml                         conda exports
├── data/                                   reference data, read-only in jobs
├── slurm/                                  shared job templates (copy of templates/slurm)
└── results/<project>/                      final outputs only

/mnt/scratch/group/<FAC_SHARE>/             hot, volatile
├── containers/                             mirror of $CHPC_LAB/containers (sif only)
└── <project>/                              working dirs, intermediates, logs
```

## Bootstrapping it (once, by whoever owns the share)

```bash
source lab/chpc.env             # after editing FAC_SHARE
mkdir -p $CHPC_LAB/{bin,containers/defs,envs,data,slurm,results}
mkdir -p $CHPC_GROUP_SCRATCH/containers
cp lab/chpc.env $CHPC_LAB/chpc.env
cp lab/bin/* $CHPC_LAB/bin/
cp templates/slurm/* $CHPC_LAB/slurm/
chmod -R g+rX,o-rwx $CHPC_LAB
```

## Every lab member

Add to `~/.bashrc` on the cluster:

```bash
[ -f /mnt/fac/<FAC_SHARE>/chpc/chpc.env ] && source /mnt/fac/<FAC_SHARE>/chpc/chpc.env
```

That puts `$CHPC_LAB/bin` on `PATH`, points Apptainer caches and conda at
scratch, and sets `APPTAINER_BIND` so containers see scratch and FAC.

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
