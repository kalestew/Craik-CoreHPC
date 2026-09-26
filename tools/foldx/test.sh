#!/bin/sh
# FoldX self-test: RepairPDB, then BuildModel with one point mutation, on a
# generated 40-residue backbone; assert a ddG in Dif_*.fxout.
# Run:  chpc-tool test foldx      (CPU; a minute or so)
#
# What it proves: the licensed binary on the share runs on a compute node,
# accepts a mutant list in FoldX's own <wt><chain><number><mut>; grammar and
# writes the Dif_ table a project reads. The fixture is backbone only, so
# RepairPDB has to build every side chain first; the energies mean nothing
# and the test does not look at their sign or size, only that a number came
# out where the ddG goes.
set -eu

: "${FOLDX_BINARY?not set -- run through chpc-tool, which exports it}"
[ -n "$FOLDX_BINARY" ] || { echo "FOLDX_BINARY is empty: the payload is not installed for you (chpc-assets list foldx)"; exit 1; }
[ -x "$FOLDX_BINARY" ] || { echo "not executable: $FOLDX_BINARY"; exit 1; }

# The banner first. An expired FoldX is present, executable, fails every call
# and only says so when it runs, which is why tool_doctor reads it too.
if "$FOLDX_BINARY" -h 2>&1 | head -40 | grep -q "time has expired"; then
    echo "licence expired: $(basename "$FOLDX_BINARY")"; exit 1
fi

sh "$TOOLDIR/../_template/make_test_pdb.sh" 40 A > t.pdb

if ! "$FOLDX_BINARY" --command=RepairPDB --pdb=t.pdb > repair.log 2>&1; then
    echo "RepairPDB exited non-zero:"; tail -20 repair.log; exit 1
fi
[ -s t_Repair.pdb ] || { echo "RepairPDB wrote no t_Repair.pdb"; tail -20 repair.log; exit 1; }

# Mutate residue 10 to alanine. The wild-type letter is read out of the
# structure rather than assumed, which is the rule the README gives for real
# inputs: a label FoldX accepts is not a label that named the residue meant.
wt3=$(awk '$1=="ATOM" && $3=="CA" && $5=="A" && $6==10 {print $4; exit}' t_Repair.pdb)
[ -n "$wt3" ] || { echo "no CA for residue A10 in t_Repair.pdb"; exit 1; }
wt=$(echo "$wt3" | awk '{
    split("ALA A ARG R ASN N ASP D CYS C GLN Q GLU E GLY G HIS H ILE I LEU L LYS K MET M PHE F PRO P SER S THR T TRP W TYR Y VAL V", m, " ")
    for (i = 1; i < 41; i += 2) if (m[i] == $1) { print m[i+1]; exit } }')
[ -n "$wt" ] || { echo "unknown residue name $wt3"; exit 1; }
[ "$wt" != "A" ] || { echo "residue A10 is already ALA; the fixture changed"; exit 1; }
echo "${wt}A10A;" > individual_list.txt

if ! "$FOLDX_BINARY" --command=BuildModel --pdb=t_Repair.pdb --mutant-file=individual_list.txt > build.log 2>&1; then
    echo "BuildModel exited non-zero:"; tail -20 build.log; exit 1
fi
[ -s Dif_t_Repair.fxout ] || { echo "no Dif_t_Repair.fxout"; ls; tail -20 build.log; exit 1; }

# The Dif_ table: header lines, then one row per mutant, tab-separated, the
# PDB name in column 1 and the total-energy ddG in column 2.
ddg=$(awk -F'\t' '$1 ~ /^t_Repair_1\.pdb/ {print $2; exit}' Dif_t_Repair.fxout)
[ -n "$ddg" ] || { echo "no row for t_Repair_1.pdb in Dif_t_Repair.fxout:"; cat Dif_t_Repair.fxout; exit 1; }
case "$ddg" in
  *[0-9]*) ;;
  *) echo "ddG column is not a number: '$ddg'"; exit 1 ;;
esac
[ -s t_Repair_1.pdb ] || { echo "no mutant model t_Repair_1.pdb"; exit 1; }
n_ca=$(grep -c '^ATOM.* CA ' t_Repair_1.pdb || true)
[ "$n_ca" -eq 40 ] || { echo "expected 40 CA atoms in the mutant model, got $n_ca"; exit 1; }

echo "ok: ${wt}A10A on a 40-residue fixture, ddG $ddg kcal/mol, $(basename "$FOLDX_BINARY")"
