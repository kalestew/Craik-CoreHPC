#!/bin/sh
# Foldseek self-test: search a structure against itself and demand a hit.
# Run:  chpc-tool test foldseek
#
# --exhaustive-search is not a workaround for a broken tool, it is the only
# honest thing to assert without a database. Foldseek's prefilter scores a
# COMBINED amino-acid + 3Di k-mer against a similarity threshold tuned for real
# structural databases, and a generated 60-residue fold is too regular to clear
# it -- three 3Di states and a periodic sequence give "0 sequences passed
# prefiltering" even for a query against itself. Bypassing the prefilter still
# exercises everything this image is responsible for: PDB parsing, 3Di
# conversion, structural alignment and output conversion. Whether the prefilter
# is well tuned is upstream's business and needs a real database to test.
set -eu
sh "$TOOLDIR/../_template/make_test_pdb.sh" 60 A > q.pdb

"$CHPC_TOOL" exec foldseek -- foldseek easy-search q.pdb q.pdb res.m8 tmp \
    --threads 2 --exhaustive-search 1 > fs.log 2>&1 || {
    echo "foldseek exited non-zero:"; tail -15 fs.log; exit 1; }

test -s res.m8 || { echo "no alignment written -- a structure must match itself"; tail -20 fs.log; exit 1; }

# fident is column 3 in the default format; a structure against itself is 1.000.
fid=$(awk 'NR==1{print $3}' res.m8)
case "$fid" in
  1.000|1.0|1) ;;
  *) echo "self-hit identity is $fid, expected 1.000"; exit 1 ;;
esac
echo "ok: self-hit identity $fid over $(awk 'NR==1{print $4}' res.m8) residues, E=$(awk 'NR==1{print $11}' res.m8)"

# --- against the PDB, when it has been fetched ------------------------------
# fetch-db.sh puts the PDB at $FOLDSEEK_DB_PDB; without it the case is skipped
# and says so, because the image is whole without a database. With it, the
# prefilter is on (no --exhaustive-search: that is the fixture's crutch, not a
# production flag) and the assertion is that the search RUNS and writes its
# table. A synthetic backbone is not owed a hit, so the count is reported,
# not required.
if [ -f "${FOLDSEEK_DB_PDB:-}" ]; then
    "$CHPC_TOOL" exec foldseek -- foldseek easy-search q.pdb "$FOLDSEEK_DB_PDB" res_pdb.m8 tmp_pdb \
        --threads 2 > fs_pdb.log 2>&1 || {
        echo "foldseek exited non-zero against $FOLDSEEK_DB_PDB:"; tail -15 fs_pdb.log; exit 1; }
    [ -f res_pdb.m8 ] || { echo "no res_pdb.m8 from the PDB search"; tail -15 fs_pdb.log; exit 1; }
    echo "ok: PDB search ran against $FOLDSEEK_DB_PDB, $(wc -l < res_pdb.m8 | tr -d ' ') hits for the synthetic fixture"
else
    echo "skipped: no PDB database at ${FOLDSEEK_DB_PDB:-<unset>} (tools/foldseek/fetch-db.sh, on the login node)"
fi
