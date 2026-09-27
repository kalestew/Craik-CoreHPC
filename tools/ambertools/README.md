# AmberTools 26

| | |
|---|---|
| Status | planned — recipe, entry and a four-stage `test.sh` written; not yet built |
| Image to be | `ambertools_26.sif` from [`ambertools_26.def`](ambertools_26.def), on a `condaforge/miniforge3` base |
| GPU | none, and that is the licence boundary rather than a technical one: the GPU engine is `pmemd.cuda`, which is not in this package |
| Weights | none. Force field data (`ff14SB`, TIP3P, GAFF2) ships in the package and is baked in |
| Licence | GPL-3.0-or-later AND LGPL-3.0-or-later AND BSD-3-Clause AND MIT — **nothing to obtain** |
| Upstream | <https://ambermd.org/>, conda-forge `ambertools` 26.0 |
| Citation | Case et al., *Amber 2026*; cite the AmberTools paper for the tools used |

AmberTools is **the open source half of Amber**: system building and
parameterisation (`tleap`, `antechamber`, `parmchk2`, `pdb4amber`), topology
manipulation (`parmed`), trajectory analysis (`cpptraj`), binding free energy
(`MMPBSA.py`), and a CPU MD engine (`sander`).

## Not built yet

Nothing to fetch and nothing to stage: conda-forge carries the force field data
and the image bakes it in.

```bash
chpc-tool build ambertools           # login node
chpc-tool publish ambertools
chpc-tool test ambertools            # CPU -- this is what `verified` means
```

The intended commands, from [`test.sh`](test.sh) and **not yet run**:

```bash
salloc -p community_short --qos=cmnt_short -c 8 --mem 16G -t 0:30:00
chpc-tool exec ambertools -- tleap -f build.leap                            # (untested)
chpc-tool exec ambertools -- cpptraj -p sys.prmtop -y traj.nc -i analyse.in  # (untested)
```

There is no `ENTRY` for this entry, deliberately: the image is a toolbox of a
dozen separately useful binaries rather than one program, so naming any of them
would make `chpc-tool exec ambertools --help` mean something arbitrary. Spell
the tool out after the `--`.

Build and publish: [`../README.md`, Add a tool](../README.md#add-a-tool).

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

**Never run.** `STATUS=planned`; the image is not built. Everything below is
what the recipe and test will establish.

### What `test.sh` will prove

Four stages, matching the three things the lab uses this image for —
parameterise, inspect, integrate — plus the licence check.

| Stage | Asserted |
|---|---|
| 1 | `tleap` builds a capped tetra-alanine in a TIP3P box and writes both files; a `FATAL` in its log fails the test **even though it exits 0** |
| 2 | `parmed` reads it: exactly `ACE ALA ALA ALA NME` as solute, more than 50 waters, **non-zero partial charges summing to ~0**, bonds/angles/dihedrals present, and a periodic box over 15 Å |
| 3 | `cpptraj` reads the same pair with its own parser and **agrees with parmed on the atom count** |
| 4 | `sander` runs 50 steps of minimisation and the energy **falls**, ending below −100 kcal/mol |
| — | `pmemd.cuda` is absent, as the licence story declares |

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

**Not** verified, and left to the first build: the exact atom count of the
solvated fixture (it depends on the water-placement algorithm and is not worth
pinning), which `leaprc` files the package ships beyond the three the recipe
asserts, and whether `MMPBSA.py` works without an MPI at run time. The recipe
prints the `leaprc` listing into the build log rather than asserting a set.
