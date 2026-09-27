# DSSP

| | |
|---|---|
| Status | **verified** 2026-09-26 — `test.sh` passed on `ccpu1-01`; the module itself was checked by hand on 2026-09-17 |
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
chpc-tool exec dssp -- mkdssp in.pdb out.dssp             # mkdssp 2.x takes input then output, positionally
```

There is nothing to `eval`: the entry exports no variables. As a job: copy
`templates/slurm/tool-gpu.sbatch`, switch it to `--partition=cpu` and delete
its `--gres` and `nvidia-smi` lines (its header says so), then set the EDIT
lines to the values above. The method:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

A PDB file in, a DSSP text table out, one residue per line. Confirmed
2026-09-26: the residue table begins after a `  #  RESIDUE AA STRUCTURE ...`
header line, column 14 holds the one-letter amino acid, and column 17 the
structure code. A chain break occupies a row of its own with `!` in column 14,
so a row count is not a residue count wherever breaks are possible. Nothing is ranked. Before comparing an
assignment with anything published: Sali also ships `dssp/2.0.4`, and 2.0.4
and 2.2.1 disagree on some assignments at chain breaks, so record the version
beside the number. This entry pins 2.2.1.

## Do not miss

- **The binary is `mkdssp`, not `dssp`.** A script that calls `dssp` gets "command not found" *after* the module has loaded successfully, which reads like a broken module.
- **Go through `chpc-tool exec dssp -- ...`, not a `module load` line in your script.** Lmod from a script breaks three ways (Traps), and `module load Sali dssp/2.2.1` as one command fails: it is a hierarchy, loaded one collection at a time, which is what the `KIND=module` arm of `chpc-tool` does.
- **2.0.4 and 2.2.1 differ at chain breaks.** Name the version beside every assignment you keep. And chain breaks are easier to provoke than they look — the registry's own test fixture provokes 13 of them with a 3.30 Å rise (Provenance).

---

## Provenance

Checked by hand on CoreHPC 2026-09-17: loading `Sali` and then `dssp/2.2.1`
puts `/mnt/software/sali/linux/x86_64/dssp-2.2.1/bin` on `PATH`. The hierarchy
and the `MODULEPATH` re-sourcing breakage under Traps were verified the same day
and are handled in `lab/bin/chpc-tool`'s `KIND=module` arm.

`test.sh` was written and passed on 2026-09-26, on `ccpu1-01` and on the login
node, which is what moved this entry to `verified`. Nothing is built here — the
module is the install — so `verified` means the module resolves through the
registry and `mkdssp` answers from the coordinates it is handed.

### The test does not assert `H`, and that is a measurement

The obvious test of a secondary-structure program is to hand it a helix and
check for `H`. That test **fails against a working mkdssp 2.2.1**, and the
reason is the fixture, not the tool.

[`../_template/make_test_pdb.sh`](../_template/make_test_pdb.sh) puts CA on a
correct alpha-helical path — 100° and 1.50 Å per residue, CA radius 2.3 Å — but
places N, C and O on offset radii and phases rather than at real backbone
geometry, and says so in its own header: *good enough to parse, number, render
and search; not a structure to do science on.* DSSP's assignment is an
electrostatic hydrogen-bond energy computed from exactly those N and O
positions, against a −0.5 kcal/mol threshold. The idealised placement does not
reach it. Measured on 2026-09-26: the 40-residue `helix` fixture comes back as
36 `S` (bend) and four blanks, with no `H` anywhere.

So the property the test asserts is that **the answer depends on the
coordinates**, which a constant column or a misread file cannot satisfy:

| # | Asserted | Measured 2026-09-26 |
|---|---|---|
| 1 | `mkdssp` exits 0 and writes a table with the DSSP column header | yes, mkdssp 2.2.1 |
| 2 | 40 residue rows for a 40-residue chain, **no** `!` chain-break rows | 40, none |
| 3 | the one-letter sequence equals `AELKIRVTWDFSYNMQHPGC` twice | exact match |
| 4 | ≥30 of 40 carry a structure code, **and** the `mixed` fixture returns a different column with chain breaks | 36 assigned; `mixed` differs and breaks |

Case 4 is the one that carries the weight. The `mixed` fixture — the
generator's default, and what nine other entries' tests use — sets its middle
third to a 3.30 Å rise, which mkdssp reads as **chain breaks**: 13 `!` rows
among the 40 residues, and a blank structure column through the middle. Same
tool, same sequence, different coordinates, different answer. That is the
assertion a broken installation cannot pass.

A false FAIL costs more here than a missing check, because it is what teaches
people to skim past test output — and then a real failure goes unread. That
principle is written up in [`../README.md`](../README.md#reference-toolconf).

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
