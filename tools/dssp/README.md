# DSSP

| | |
|---|---|
| Verified | 2026-09-17 on CoreHPC — `module load Sali dssp/2.2.1` |
| Kind | `module` — nothing is built, nothing is published |
| Provides | `mkdssp` 2.2.1, from `/mnt/software/sali/linux/x86_64/dssp-2.2.1/bin` |
| Upstream | https://github.com/PDB-REDO/dssp |
| Licence | BSD-2-Clause |
| GPU | no |

DSSP is already installed cluster-wide in the **Sali** module collection, so
there is nothing for this registry to build. The entry exists so a project can
name `dssp` and get it, instead of every script hardcoding a `module load`
line that will be wrong on the next cluster.

Sali also ships `dssp/2.0.4`. `2.2.1` is the collection default and what this
entry pins; 2.0.4 and 2.2.1 disagree on some assignments at chain breaks, so
the version is named rather than left to the default.

## The binary is `mkdssp`, not `dssp`

Hence `ENTRY=mkdssp`. A script that calls `dssp` gets "command not found"
*after* the module has loaded successfully, which reads like a broken module.

## Lmod from inside a script breaks in three ways

All three look like a missing module, and all three are handled in
`chpc-tool`'s `KIND=module` arm — the reason to go through the registry rather
than write `module load` yourself. Written up in full in
[`docs/06`](../../docs/06-software-modules-conda.md):

- **`module` is a shell function.** Piping it (`module load x | tee`) runs it
  in a subshell and the change never reaches your shell.
- **Re-sourcing `/etc/profile.d/lmod.sh` when Lmod is already inherited**
  rebuilds `MODULEPATH` and silently drops `/etc/modulefiles`, which is where
  the `CBI`, `Sali` and `RAD` collections live. Lmod then reports that the
  module "exists but cannot be loaded as requested".
- **That init script reads `$SLURM_NODELIST` unguarded**, so sourcing it under
  `set -u` dies outside a job.

Collections are also a hierarchy: `module load Sali dssp/2.2.1` as a single
command fails. Load them in order — which is why `MODULE` is a two-word value
here and `chpc-tool` splits it.
