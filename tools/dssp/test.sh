#!/bin/sh
# DSSP self-test: mkdssp reads coordinates and answers from them.
# Run:  chpc-tool test dssp               (CPU; no GPU, no weights, ~5 s)
#
# Passed 2026-09-26 on the CoreHPC login node and on ccpu1-01, against
# mkdssp 2.2.1 from `module load Sali dssp/2.2.1`.
#
# WHAT THIS DELIBERATELY DOES NOT ASSERT: that the helical fixture is called
# `H`. It is not. The shared generator places CA on a correct alpha-helical
# path -- 100 degrees and 1.50 A per residue, CA radius 2.3 A -- but puts N, C
# and O on offset radii and phases rather than at real backbone geometry, and
# DSSP's assignment is an electrostatic hydrogen-bond energy computed from N and
# O. The idealised placement does not reach its -0.5 kcal/mol threshold, so
# mkdssp 2.2.1 returns `S` (bend) for the interior and nothing for the ends.
# Measured, not assumed. A test asserting `H` would fail against a perfectly
# good installation, which is the failure mode this registry cares about most:
# the false FAIL that teaches people to skim past test output.
#
# So the property asserted instead is that the answer DEPENDS ON THE
# COORDINATES. A tool that emitted a constant column, or that silently read a
# different file, cannot satisfy all four checks below at once.
set -eu

M="$TOOLDIR/../_template/make_test_pdb.sh"
[ -f "$M" ] || { echo "no fixture generator at $M"; exit 1; }

# --- fixtures ----------------------------------------------------------------
# `helix` gives an unbroken 40-residue chain. `mixed` -- the generator's
# default, and what every other entry's test uses -- sets its middle third to
# rise 3.30 A, which DSSP reads as CHAIN BREAKS and marks with `!` rows. That
# difference is the lever this test pulls, so both are generated.
sh "$M" 40 A helix > helix.pdb
sh "$M" 40 A mixed > mixed.pdb

# The generator cycles 20 residue names, so a 40-residue chain has a known
# one-letter sequence, twice over. Hard-coding it here is the point: it is what
# makes "mkdssp read OUR file, kept every residue, and kept them in order" an
# assertion rather than a hope.
WANT_SEQ=AELKIRVTWDFSYNMQHPGCAELKIRVTWDFSYNMQHPGC

run_dssp() {
    # $1 in.pdb, $2 out.dssp. mkdssp 2.x takes input then output as positional
    # arguments; there is no -o flag in 2.2.1.
    if ! "$CHPC_TOOL" exec dssp -- mkdssp "$1" "$2" > "$1.log" 2>&1; then
        echo "mkdssp failed on $1:" >&2
        tail -20 "$1.log" >&2
        return 1
    fi
}

# The residue table starts after the column-header line. Everything below reads
# fixed columns, which is what the DSSP format is: column 14 is the one-letter
# amino acid (`!` on a chain-break row), column 17 the structure code.
col() {  # col <file> <column>
    awk -v c="$2" 'f { printf "%s", substr($0, c, 1) } /^  #  RESIDUE AA/ { f = 1 }' "$1"
}

# --- 1: it runs, and writes a DSSP table -------------------------------------
run_dssp helix.pdb helix.dssp
grep -q '^  #  RESIDUE AA' helix.dssp || {
    echo "helix.dssp has no DSSP column header -- mkdssp wrote something else"; exit 1; }
echo "ok: mkdssp $("$CHPC_TOOL" exec dssp -- mkdssp --version 2>&1 | head -1 | awk '{print $NF}') wrote a DSSP table"

# --- 2: every residue is there, and none is a chain break --------------------
seq_helix=$(col helix.dssp 14)
n_helix=$(printf '%s' "$seq_helix" | wc -c | tr -d ' ')
[ "$n_helix" = 40 ] || {
    echo "expected 40 residue rows from a 40-residue chain, got $n_helix"
    echo "sequence column was: $seq_helix"; exit 1; }
case "$seq_helix" in
    *!*) echo "unbroken helix fixture produced chain-break rows: $seq_helix"; exit 1 ;;
esac
echo "ok: 40 residue rows, no chain breaks"

# --- 3: it read OUR coordinates, in order ------------------------------------
[ "$seq_helix" = "$WANT_SEQ" ] || {
    echo "sequence mismatch -- mkdssp did not read the fixture we wrote"
    echo "  want: $WANT_SEQ"
    echo "  got:  $seq_helix"; exit 1; }
echo "ok: sequence round-trips exactly ($WANT_SEQ)"

# --- 4: the assignment comes from the geometry -------------------------------
# Two halves, and both are needed. First: the helix fixture's interior must be
# assigned SOMETHING rather than left blank -- 36 of 40 were `S` when measured,
# so 30 is a floor with room for a version that disagrees at the ends.
str_helix=$(col helix.dssp 17)
assigned=$(printf '%s' "$str_helix" | tr -d ' ' | wc -c | tr -d ' ')
[ "$assigned" -ge 30 ] || {
    echo "only $assigned of 40 residues carry a structure code in the helical"
    echo "fixture; DSSP is not assigning from these coordinates at all"
    echo "structure column: [$str_helix]"; exit 1; }

# Second, and the half that cannot be faked by a constant column: the mixed
# fixture's broken middle third must come back DIFFERENT. Same tool, same
# sequence, different coordinates, different answer.
run_dssp mixed.pdb mixed.dssp
seq_mixed=$(col mixed.dssp 14)
case "$seq_mixed" in
    *!*) ;;
    *) echo "mixed fixture produced no chain-break rows; its middle third rises"
       echo "3.30 A per residue and DSSP read that as broken on 2026-09-26."
       echo "sequence column: $seq_mixed"; exit 1 ;;
esac
str_mixed=$(col mixed.dssp 17)
[ "$str_helix" != "$str_mixed" ] || {
    echo "helix and mixed fixtures gave an IDENTICAL structure column:"
    echo "  [$str_helix]"
    echo "mkdssp is not answering from the coordinates."; exit 1; }
echo "ok: $assigned of 40 assigned on the helix; the mixed fixture differs and breaks"

echo
echo "ok: mkdssp 2.2.1 parses a 40-residue chain, round-trips its sequence"
echo "    exactly, assigns structure from the coordinates, and reports chain"
echo "    breaks where the geometry has them. It does NOT call this fixture a"
echo "    helix, and that is the fixture's geometry, not the tool -- see the"
echo "    comment at the top of this file before tightening anything."
