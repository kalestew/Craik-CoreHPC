# DSSP

| | |
|---|---|
| Status | built (no `test.sh`, so nothing has run through `chpc-tool test`); `module load Sali dssp/2.2.1` checked by hand on CoreHPC 2026-09-17 |
| Module | `Sali dssp/2.2.1`, an Lmod hierarchy loaded in that order; nothing is built, nothing is published |
| Provides | `mkdssp` 2.2.1, from `/mnt/software/sali/linux/x86_64/dssp-2.2.1/bin` |
| GPU | CPU |
| Licence | BSD-2-Clause |
| Upstream | https://github.com/PDB-REDO/dssp |

## Run it

```bash
salloc -p cpu -c 2 --mem 4G -t 1:00:00
chpc-tool exec dssp -- mkdssp --version                   # loads Sali, then dssp/2.2.1, then runs the binary
mkdir -p /mnt/scratch/user/$USER/dssp/run1 && cd "$_"     # in.pdb here
chpc-tool exec dssp -- mkdssp in.pdb out.dssp             # (untested) mkdssp 2.x takes input then output
```

There is nothing to `eval`: the entry exports no variables. As a job: copy
`templates/slurm/tool-gpu.sbatch`, switch it to `--partition=cpu` and delete
its `--gres` and `nvidia-smi` lines (its header says so), then set the EDIT
lines to the values above. The method:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

A PDB file in, a DSSP text table out, one residue per line (untested here;
that is mkdssp 2.2.1's own format). Nothing is ranked. Before comparing an
assignment with anything published: Sali also ships `dssp/2.0.4`, and 2.0.4
and 2.2.1 disagree on some assignments at chain breaks, so record the version
beside the number. This entry pins 2.2.1.

## Do not miss

- **The binary is `mkdssp`, not `dssp`.** A script that calls `dssp` gets "command not found" *after* the module has loaded successfully, which reads like a broken module.
- **Go through `chpc-tool exec dssp -- ...`, not a `module load` line in your script.** Lmod from a script breaks three ways (Traps), and `module load Sali dssp/2.2.1` as one command fails: it is a hierarchy, loaded one collection at a time, which is what the `KIND=module` arm of `chpc-tool` does.
- **2.0.4 and 2.2.1 differ at chain breaks.** Name the version beside every assignment you keep.

---

## Provenance

Nothing is built. Checked by hand on CoreHPC 2026-09-17: loading `Sali` and
then `dssp/2.2.1` puts `/mnt/software/sali/linux/x86_64/dssp-2.2.1/bin` on
`PATH`. The hierarchy and the `MODULEPATH` re-sourcing breakage under Traps
were verified the same day and are handled in `lab/bin/chpc-tool`'s
`KIND=module` arm. There is no `test.sh`, so `chpc-tool test dssp` has nothing
to run and the entry is `built`, not `verified`; an earlier header called that
hand check verified. Whoever writes a `test.sh` (`mkdssp` on a small PDB,
assert the residue count) can set `verified` (`../README.md`, Add a tool).

## Build notes

DSSP is already installed cluster-wide in the **Sali** module collection, so
there is nothing for this registry to build. The entry exists so a project can
name `dssp` and get it, instead of every script hardcoding a `module load`
line that will be wrong on the next cluster.

Sali also ships `dssp/2.0.4`. `2.2.1` is the collection default and what this
entry pins; 2.0.4 and 2.2.1 disagree on some assignments at chain breaks, so
the version is named rather than left to the default.

## Traps

### The binary is `mkdssp`, not `dssp`

Hence `ENTRY=mkdssp`. A script that calls `dssp` gets "command not found"
*after* the module has loaded successfully, which reads like a broken module.

### Lmod from inside a script breaks in three ways

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
