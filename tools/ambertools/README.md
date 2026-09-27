# AmberTools 26

| | |
|---|---|
| Status | **verified** 2026-09-26 — built, published, and `test.sh`'s four stages passed on `ccpu1-01` (CPU, `community_short`) |
| Image | `ambertools_26.sif` from [`ambertools_26.def`](ambertools_26.def); 894 MB on a `condaforge/miniforge3` base |
| GPU | none, and that is the licence boundary rather than a technical one: the GPU engine is `pmemd.cuda`, which is not in this package |
| Weights | none. Force field data (`ff14SB`, TIP3P, GAFF2) ships in the package and is baked in |
| Licence | GPL-3.0-or-later AND LGPL-3.0-or-later AND BSD-3-Clause AND MIT — **nothing to obtain** |
| Upstream | <https://ambermd.org/>, conda-forge `ambertools` 26.0 |
| Citation | Case et al., *Amber 2026*; cite the AmberTools paper for the tools used |

AmberTools is **the open source half of Amber**: system building and
parameterisation (`tleap`, `antechamber`, `parmchk2`, `pdb4amber`), topology
manipulation (`parmed`), trajectory analysis (`cpptraj`), binding free energy
(`MMPBSA.py`), and a CPU MD engine (`sander`).

## Run it

Nothing to fetch and nothing staged on FAC: conda-forge carries the force field
data and the image bakes it in.

```bash
salloc -p community_short --qos=cmnt_short -c 8 --mem 16G -t 0:30:00
chpc-tool exec ambertools -- tleap -f build.leap
chpc-tool exec ambertools -- antechamber -i lig.mol2 -fi mol2 -o lig.mol2 -fo mol2 -c bcc
chpc-tool exec ambertools -- cpptraj -p sys.prmtop -y traj.nc -i analyse.in
```

There is no `ENTRY` for this entry, deliberately: the image is a toolbox of a
dozen separately useful binaries rather than one program, so naming any of them
would make `chpc-tool exec ambertools --help` mean something arbitrary. Spell the
tool out after the `--`.

**`cpptraj` takes its commands in a file, passed with `-i`.** There is no flag
for inline commands, and given an unrecognised one it prints its entire usage
screen, appends `Error: Error(s) occurred during execution.` and exits non-zero,
so the real complaint sits at the bottom of fifty lines of help text.

Rebuild and republish: [`../README.md`, Add a tool](../README.md#add-a-tool).

## Why this is a separate entry from `amber`

Amber ships as two products with two licences, and the split is not where
people expect: **the tools everybody uses daily are free, and the engine is
not.** [`amber`](../amber/README.md) used to carry both, with a `tool_doctor`
that failed on a missing `pmemd.cuda` — so a paid binary nobody had bought made
the entire free toolchain report as broken, and `tleap` was unavailable because
of it. Splitting them means the free 90% no longer waits on the paid 10%.

## The route that needs no licence anywhere

This is the composition the split makes available, and it is worth knowing
before anyone buys an Amber licence to do molecular dynamics:

1. **Parameterise here.** `tleap` for the protein and water, `antechamber` plus
   `parmchk2` with GAFF2 for a novel ligand. Out comes a `prmtop` and an
   `inpcrd`.
2. **Integrate on a GPU with [`openmm`](../openmm/README.md).** It reads Amber
   topologies directly through `openmm.app.AmberPrmtopFile`, is MIT licensed,
   and runs on all three of our GPU models.
3. **Analyse back here** with `cpptraj`.

`sander` is included and will run MD with the same force fields, but it is
CPU-only: right for equilibration, for checking an input, and for anything
short, and orders of magnitude off for production.

## Do not miss

- **`tleap` FAILS BY SUCCEEDING.** It is a script interpreter. Hand it a
  missing `leaprc`, an unparameterisable residue or a typo in a unit name and
  it prints its banner, reports the error somewhere in the middle of a long
  log, **exits 0**, and either writes nothing or writes a topology containing
  only the water box. Never trust its exit status. Check that the `prmtop`
  exists, and check its atom count, its residue list and its net charge against
  what you expected — which is exactly what [`test.sh`](test.sh) does.
- **A topology with all-zero partial charges parameterises, minimises,
  simulates, and is meaningless.** Nothing about its shape says so, and no exit
  status reports it. `test.sh` asserts that charges were assigned and that a
  capped polyalanine comes out neutral, because this is the failure that
  produces a full trajectory of confident nonsense.
- **`cpptraj` and `sander` will take every core on the machine**, not the cores
  Slurm gave the job, since they parallelise with OpenMP and read the node
  rather than the allocation. `%environment` sets `OMP_NUM_THREADS` from
  `$SLURM_CPUS_PER_TASK` so the default honours the allocation; if you override
  it, override it to the allocation.
- **A row count is not a residue count** once water is involved. Strip `:WAT`
  before counting anything, and remember that `solvateBox` adds hundreds of
  residues to a five-residue peptide.
- **`pmemd.cuda` is not here.** `test.sh` asserts its absence rather than
  assuming it, because the day a conda-forge build starts shipping it is the day
  this entry's licence position changes and somebody needs to notice.

---

## Provenance

**Run 2026-09-26** on `ccpu1-01` (`community_short`), against conda-forge
`ambertools` 26.0. All four stages passed.

### What `test.sh` proves

Four stages, matching the three things the lab uses this image for —
parameterise, inspect, integrate — plus the licence check.

| Stage | Asserted | Measured 2026-09-26 |
|---|---|---|
| 1 | `tleap` builds a capped tetra-alanine in a TIP3P box and writes both files; a `FATAL` in its log fails the test **even though it exits 0** | both files written |
| 2 | `parmed` reads it: exactly `ACE ALA ALA ALA NME` as solute, more than 50 waters, **non-zero partial charges summing to ~0**, bonds/angles/dihedrals present, and a periodic box over 15 Å | **1782 atoms, 585 residues (5 solute, 580 water), net charge −0.000000, 1781 bonds, box 31.4 × 35.78 × 26.19 Å** |
| 3 | `cpptraj` reads the same pair with its own parser and **agrees with parmed on the atom count** | 1782, agreeing |
| 4 | `sander` runs 50 steps of minimisation and the energy **falls**, ending below −100 kcal/mol | **−4317.3 → −5627.4 kcal/mol**, a drop of 1310.1 |
| — | `pmemd.cuda` is absent, as the licence story declares | absent |

The per-water figure is the one with physical meaning: **−9.70 kcal/mol over 580
waters**, against a known TIP3P value of about −9.9. That is the check that says
the force field was really applied rather than merely parsed, and it is asserted
with a wide band because 50 steps of minimisation on a freshly solvated box is
not an equilibrated simulation.

**Units here are kcal/mol.** Amber is kcal throughout, while
[`openmm`](../openmm/README.md) and [`gromacs`](../gromacs/README.md) next door
report kJ/mol. Worth remembering before comparing a number from one with a number
from the other.

Stage 3 is a second implementation agreeing rather than either matching a
number written in the test file. Stage 4 is the one that proves the force field
data is self-consistent enough to *evaluate*, which reading a topology does
not: a broken parameter set can be read back perfectly and cannot lower an
energy. The `< -100` floor catches the case where the nonbonded terms never
contributed, which leaves an energy near zero.

### Verified against upstream, 2026-09-26

- conda-forge `ambertools` 26.0 exists for linux-64, with the licence string
  `GPL-3.0-or-later AND LGPL-3.0-or-later AND BSD-3-Clause AND MIT` — so
  **nothing here needs a licence**, which is the fact this entry was created
  to act on;
- that the conda package is the AmberTools distribution and does **not** carry
  `pmemd` or `pmemd.cuda`.

### Three shell traps this recipe walked into, all in one build

Worth recording because each produced a failure that pointed somewhere other
than at its cause, and all three are now written up in
[`../README.md`](../README.md) Traps:

- **`cd /tmp` in `%post`.** Another user's `inspect.py` has been sitting in the
  login node's `/tmp` since July, and python puts the working directory on
  `sys.path`, so `import inspect` reached from numpy via parmed resolved to their
  script and died trying to read a file in *their* scratch. The traceback read as
  a broken numpy.
- **`grep -q PATTERN file && { fail; }` under `set -e`.** When grep finds nothing,
  the healthy case, the list's exit status is grep's 1 and `set -e` kills the
  build with no message. A clean `cpptraj` log failed the build; a dirty one
  would have reported properly.
- **Matching the word "error" at all.** `tleap` ends every run, including a
  perfectly clean one, with `Exiting LEaP: Errors = 0; Warnings = 0; Notes = 0.`,
  so a case-insensitive search for `error` matches always. The check asserts
  `Errors = 0` is *present* instead.

And one API mistake of the same shape: `cpptraj -ec '...'` is not cpptraj syntax.
Given an unrecognised flag it prints its whole usage screen, appends
`Error: Error(s) occurred during execution.` and exits non-zero, so the real
complaint sits under fifty lines of help text. Commands go in a file, with `-i`.

**Not** verified, and left where it is: which `leaprc` files the package ships
beyond the three the recipe asserts, and whether `MMPBSA.py` works without an MPI
at run time. The recipe prints the `leaprc` listing into the build log rather than
asserting a set.
