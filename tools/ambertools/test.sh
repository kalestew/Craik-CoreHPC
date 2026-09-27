#!/bin/sh
# AmberTools self-test: build a system, read it back two ways, and minimise it.
# Run:  chpc-tool test ambertools            (CPU; no GPU, no weights, ~40 s)
#
# WHY TLEAP NEEDS MORE THAN AN EXIT STATUS. tleap is a script interpreter, and
# it fails by SUCCEEDING: hand it a missing leaprc, an unparameterisable
# residue or a typo in a unit name and it prints its banner, reports the error
# in the middle of a long log, exits 0, and writes nothing -- or writes a
# topology containing only the water box. So every check below is on the
# CONTENT of what it produced, and the interesting ones are the ones a
# plausible-looking empty topology cannot satisfy.
#
# The three stages correspond to the three things the lab actually uses this
# image for: parameterise (tleap), inspect (parmed and cpptraj, independently),
# and integrate (sander). If the third looks redundant next to ../openmm, it is
# not: it proves the force field data is self-consistent enough to produce
# forces, which reading a topology does not.
set -eu

: "${AMBERHOME:?not set -- run through chpc-tool, which exports it}"

# --- stage 1: tleap parameterises a real system -------------------------------
# A capped tetra-alanine in a TIP3P box. Small enough for 40 seconds, and
# complete enough to exercise the protein force field, the water model, the
# solvation code and the topology writer.
cat > build.leap <<'LEAP'
source leaprc.protein.ff14SB
source leaprc.water.tip3p
peptide = sequence { ACE ALA ALA ALA NME }
solvateBox peptide TIP3PBOX 8.0
saveAmberParm peptide sys.prmtop sys.inpcrd
quit
LEAP

if ! "$CHPC_TOOL" exec ambertools -- tleap -f build.leap > tleap.log 2>&1; then
    echo "tleap exited non-zero:" >&2; tail -25 tleap.log >&2; exit 1
fi
# tleap's exit status is not the signal; its log and its output files are.
if grep -qE '^(FATAL|Fatal)' tleap.log; then
    echo "tleap reported a fatal error while still exiting 0:" >&2
    grep -nE '^(FATAL|Fatal)' tleap.log >&2
    tail -20 tleap.log >&2
    exit 1
fi
test -s sys.prmtop || { echo "tleap wrote no topology:"; tail -25 tleap.log; exit 1; }
test -s sys.inpcrd || { echo "tleap wrote no coordinates:"; tail -25 tleap.log; exit 1; }
echo "ok: tleap wrote sys.prmtop and sys.inpcrd"

# --- stage 2: parmed reads it, and the CONTENT is right -----------------------
if ! "$CHPC_TOOL" exec ambertools -- python - > parmed.log 2>&1 <<'PY'
import parmed

p = parmed.load_file("sys.prmtop", xyz="sys.inpcrd")
waters = [r for r in p.residues if r.name in ("WAT", "HOH")]
solute = [r for r in p.residues if r.name not in ("WAT", "HOH")]
print("atoms %d, residues %d (%d solute, %d water)"
      % (len(p.atoms), len(p.residues), len(solute), len(waters)))
print("solute sequence:", " ".join(r.name for r in solute))

# ACE + 3 ALA + NME. If tleap built nothing, this is 0 and the box is all
# there is -- which is the failure that exits 0 and writes a plausible file.
assert len(solute) == 5, ("solute residues", [r.name for r in solute])
assert [r.name for r in solute] == ["ACE", "ALA", "ALA", "ALA", "NME"], \
    [r.name for r in solute]
assert len(waters) > 50, ("solvateBox produced almost no water", len(waters))

# CHARGES, which is the assertion that matters most. A topology whose partial
# charges are all zero parameterises, minimises, simulates, and is physically
# meaningless -- and nothing about its shape says so.
charges = [a.charge for a in p.atoms]
assert any(abs(c) > 1e-6 for c in charges), "every partial charge is zero"
total = sum(charges)
assert abs(total) < 1e-3, ("capped polyalanine should be neutral", total)
print("net charge %+.6f" % total)

# Bonded terms must exist too: an atom list with no bonds is not a force field.
assert len(p.bonds) > len(p.atoms) / 2, ("suspiciously few bonds", len(p.bonds))
assert len(p.angles) > 0 and len(p.dihedrals) > 0, "no angles or dihedrals"
print("bonds %d, angles %d, dihedrals %d" % (len(p.bonds), len(p.angles), len(p.dihedrals)))

# And the periodic box solvateBox was asked for.
assert p.box is not None, "no periodic box in the topology"
assert min(p.box[:3]) > 15.0, ("box is implausibly small", list(p.box))
print("box %s" % [round(x, 2) for x in p.box])

with open("atomcount.txt", "w") as fh:
    fh.write(str(len(p.atoms)))
PY
then
    echo "parmed could not validate the topology:" >&2; tail -25 parmed.log >&2; exit 1
fi
cat parmed.log

# --- stage 3: cpptraj agrees, independently -----------------------------------
# A second reader, with its own parser. Two implementations agreeing on the atom
# count is a stronger statement than either matching a number written here.
# Commands go in a FILE, passed with -i. cpptraj has no inline-command flag, and
# it answers an unrecognised one by printing its entire usage screen followed by
# "Error: Error(s) occurred during execution." -- fifty lines of help text with
# the actual complaint at the bottom.
cat > analyse.in <<'CPPTRAJ'
strip :WAT
go
CPPTRAJ
if ! "$CHPC_TOOL" exec ambertools -- cpptraj -p sys.prmtop -y sys.inpcrd \
        -i analyse.in > cpptraj.log 2>&1
then
    echo "cpptraj failed to read the topology:" >&2; tail -25 cpptraj.log >&2; exit 1
fi
want=$(cat atomcount.txt)
# cpptraj prints e.g. "Topology ... contains 1234 atoms".
got=$(grep -oE '[0-9]+ atoms' cpptraj.log | head -1 | awk '{print $1}')
[ -n "$got" ] || { echo "cpptraj printed no atom count:"; tail -20 cpptraj.log; exit 1; }
[ "$got" = "$want" ] || {
    echo "cpptraj says $got atoms, parmed says $want -- the two parsers disagree"
    tail -20 cpptraj.log; exit 1; }
echo "ok: cpptraj independently reads $got atoms, agreeing with parmed"

# --- stage 4: sander produces forces, and minimisation lowers the energy -------
# The end of the chain. Reading a topology does not prove the force field data
# is self-consistent enough to evaluate; running 50 steps of steepest descent
# does, and the energy going DOWN is the property a broken parameter set cannot
# fake.
cat > min.in <<'MDIN'
minimisation, 50 steps
 &cntrl
  imin = 1, maxcyc = 50, ncyc = 25,
  cut = 8.0, ntb = 1, ntpr = 10,
 /
MDIN
if ! "$CHPC_TOOL" exec ambertools -- sander -O -i min.in -o min.out \
        -p sys.prmtop -c sys.inpcrd -r min.rst > sander.log 2>&1
then
    echo "sander failed:" >&2; tail -25 min.out 2>/dev/null >&2; tail -10 sander.log >&2; exit 1
fi
test -s min.rst || { echo "sander wrote no restart file:"; tail -25 min.out; exit 1; }

if ! "$CHPC_TOOL" exec ambertools -- python - > energy.log 2>&1 <<'PY'
import re

text = open("min.out").read()
# Every printed step carries an ENERGY field; take the first and the last.
energies = [float(m) for m in re.findall(r"^\s+ENERGY\s+=\s+(-?\d+\.\d+)",
                                         text, re.MULTILINE)]
if not energies:
    energies = [float(m) for m in re.findall(r"ENERGY\s+=\s+(-?[\d.]+)", text)]
assert len(energies) >= 2, ("sander printed fewer than two energies", energies[:5])
first, last = energies[0], energies[-1]
print("sander minimisation: %.4f -> %.4f kcal/mol over %d printed steps"
      % (first, last, len(energies)))
assert last < first, ("minimisation did not lower the energy", first, last)
# A solvated peptide's potential energy is large and negative; a value near zero
# means the nonbonded terms never contributed.
assert last < -100.0, ("energy implausibly high for a solvated system", last)
print("energy decreased by %.4f kcal/mol" % (first - last))
PY
then
    echo "could not read energies out of sander's output:" >&2
    tail -25 energy.log >&2
    grep -n "ENERGY" min.out | head -5 >&2
    exit 1
fi
cat energy.log

# --- and the licensed engine is absent, as declared ---------------------------
# Asserted rather than assumed, because the day a conda-forge build starts
# shipping pmemd is the day this entry's licence story changes.
if "$CHPC_TOOL" exec ambertools -- sh -c 'command -v pmemd.cuda' >/dev/null 2>&1; then
    echo "pmemd.cuda is PRESENT in a conda-forge ambertools build." >&2
    echo "That is unexpected and changes this entry's licence position." >&2
    echo "Do not publish until it is understood -- see tools/amber." >&2
    exit 1
fi
echo "ok: no pmemd.cuda, as declared -- the licensed engine is tools/amber"

echo
echo "ok: tleap parameterised a capped tetra-alanine in TIP3P with real charges"
echo "    and a periodic box, parmed and cpptraj agree on the atom count, and"
echo "    sander lowered the energy over 50 steps of minimisation. For GPU MD"
echo "    without a licence, hand the prmtop to tools/openmm."
