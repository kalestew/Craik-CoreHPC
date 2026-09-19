#!/bin/sh
# Rosetta self-test: score a real backbone, then run one cartesian_ddg
# mutation. Run:  chpc-tool test rosetta
#
# Both binaries are tested because they fail differently. rosetta_scripts
# exercises the XML parser and the scorefunction; cartesian_ddg exercises the
# minimizer and the mutation machinery, and it is the one whose output the ddG
# cascade actually reads.
#
# CPU only. ~1 minute.
set -eu

: "${ROSETTA_BIN:?not set -- run through chpc-tool, which exports it}"
: "${ROSETTA_DB:?not set -- run through chpc-tool, which exports it}"
SUFFIX="${ROSETTA_SUFFIX:-default.linuxgccrelease}"

RS="$ROSETTA_BIN/rosetta_scripts.$SUFFIX"
CD="$ROSETTA_BIN/cartesian_ddg.$SUFFIX"
for b in "$RS" "$CD"; do
    test -x "$b" || { echo "missing $b"; exit 1; }
done
test -d "$ROSETTA_DB" || { echo "no database at $ROSETTA_DB"; exit 1; }

# Six residues of real backbone (3rgk 1-6). Real coordinates rather than
# hand-built ones, so the geometry is physical and the score is meaningful;
# side chains are absent on purpose, because Rosetta rebuilding them is part
# of what this proves.
cat > in.pdb <<'PDB'
ATOM      1  N   GLY A   1      -5.305  16.052  14.494  1.00 25.71           N
ATOM      2  CA  GLY A   1      -4.718  17.420  14.606  1.00 25.07           C
ATOM      3  C   GLY A   1      -3.276  17.379  15.070  1.00 24.60           C
ATOM      4  O   GLY A   1      -2.544  16.424  14.782  1.00 25.45           O
ATOM      5  N   LEU A   2      -2.867  18.418  15.792  1.00 23.41           N
ATOM      6  CA  LEU A   2      -1.513  18.492  16.328  1.00 22.04           C
ATOM      7  C   LEU A   2      -1.511  18.312  17.837  1.00 21.09           C
ATOM      8  O   LEU A   2      -2.466  18.697  18.508  1.00 21.11           O
ATOM      9  N   SER A   3      -0.432  17.734  18.361  1.00 19.94           N
ATOM     10  CA  SER A   3      -0.201  17.679  19.802  1.00 19.07           C
ATOM     11  C   SER A   3       0.245  19.055  20.300  1.00 18.46           C
ATOM     12  O   SER A   3       0.622  19.915  19.499  1.00 17.75           O
ATOM     13  N   ASP A   4       0.219  19.269  21.615  1.00 18.01           N
ATOM     14  CA  ASP A   4       0.721  20.527  22.162  1.00 17.45           C
ATOM     15  C   ASP A   4       2.218  20.683  21.892  1.00 16.38           C
ATOM     16  O   ASP A   4       2.682  21.787  21.648  1.00 15.58           O
ATOM     17  N   GLY A   5       2.960  19.574  21.931  1.00 15.27           N
ATOM     18  CA  GLY A   5       4.391  19.606  21.600  1.00 14.04           C
ATOM     19  C   GLY A   5       4.630  20.048  20.165  1.00 13.01           C
ATOM     20  O   GLY A   5       5.558  20.813  19.888  1.00 12.92           O
ATOM     21  N   GLU A   6       3.791  19.562  19.251  1.00 12.15           N
ATOM     22  CA  GLU A   6       3.860  19.963  17.840  1.00 12.43           C
ATOM     23  C   GLU A   6       3.505  21.442  17.653  1.00 10.85           C
ATOM     24  O   GLU A   6       4.207  22.171  16.935  1.00 10.19           O
END
PDB

cat > score.xml <<'XML'
<ROSETTASCRIPTS>
    <SCOREFXNS><ScoreFunction name="r15" weights="ref2015"/></SCOREFXNS>
    <MOVERS></MOVERS>
    <PROTOCOLS></PROTOCOLS>
    <OUTPUT scorefxn="r15"/>
</ROSETTASCRIPTS>
XML

# ---------------------------------------------------------- rosetta_scripts --
if ! "$RS" -database "$ROSETTA_DB" -parser:protocol score.xml -s in.pdb \
        -nstruct 1 -out:file:scorefile score.sc -overwrite > rs.log 2>&1
then
    echo "rosetta_scripts exited non-zero:"; tail -25 rs.log; exit 1
fi

test -s score.sc || { echo "no scorefile written"; tail -25 rs.log; exit 1; }
# Column position is not fixed across Rosetta versions, so find total_score by
# NAME in the header rather than assuming $2.
total=$(awk '
    /^SCORE:/ && $2=="total_score" { for(i=1;i<=NF;i++) if($i=="total_score") col=i; next }
    /^SCORE:/ && col { print $col; exit }
' score.sc)
[ -n "$total" ] || { echo "no total_score in score.sc"; cat score.sc; exit 1; }
# A finite number, not nan/inf. ref2015 on a 6-residue fragment with rebuilt
# side chains lands in single digits either side of zero; the assertion is only
# that scoring produced a real number.
case "$total" in
    *nan*|*NaN*|*inf*|*Inf*) echo "total_score is not finite: $total"; exit 1 ;;
esac
awk -v t="$total" 'BEGIN{ if (t+0 == 0 && t !~ /^[+-]?0\.?0*$/) exit 1 }' \
    || { echo "total_score did not parse as a number: $total"; exit 1; }

# ------------------------------------------------------------ cartesian_ddg --
# One mutation, one iteration. This is the app that ignores -out:path:all and
# writes its .ddg table to the CURRENT directory -- chpc-tool test already runs
# in a scratch dir, which is why that is safe here and why the stages cd first.
# Mutfile format: `total <N>`, then PER BLOCK a count line, then that block's
# mutations. Omitting the per-block count -- which looks redundant when there
# is one mutation -- gets you
#   ERROR: Assertion `num_mutations>0` failed.
#   ERROR:: Exit from: src/apps/public/ddg/cartesian_ddg.cc line: 188
# plus a developer backtrace, which says nothing about the file being short a
# line.
printf 'total 1\n1\nS 3 A\n' > mut.txt
if ! "$CD" -database "$ROSETTA_DB" -s in.pdb -ddg:mut_file mut.txt \
        -ddg:iterations 1 -ddg:cartesian -ddg:dump_pdbs false \
        -score:weights ref2015_cart -fa_max_dis 9.0 > ddg.log 2>&1
then
    echo "cartesian_ddg exited non-zero:"; tail -25 ddg.log; exit 1
fi

ddg=$(find . -name '*.ddg' -type f 2>/dev/null | head -1)
[ -n "$ddg" ] || { echo "no .ddg table written"; ls -la; tail -25 ddg.log; exit 1; }
rows=$(grep -c 'COMPLEX' "$ddg" 2>/dev/null || true)
[ "${rows:-0}" -ge 1 ] || { echo "no COMPLEX rows in $ddg"; cat "$ddg"; exit 1; }

echo "ok: rosetta_scripts total_score=$total, cartesian_ddg wrote $rows rows to $(basename "$ddg")"
