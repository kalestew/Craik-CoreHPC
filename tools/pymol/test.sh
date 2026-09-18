#!/bin/sh
# PyMOL self-test: load a structure headless and actually render a PNG.
# Run:  chpc-tool test pymol
set -eu
sh "$TOOLDIR/../_template/make_test_pdb.sh" 20 A > t.pdb
"$CHPC_TOOL" exec pymol -- pymol -cq t.pdb -d "hide everything; show cartoon; png out.png, width=200, height=200, dpi=72, ray=0" > pm.log 2>&1
# Rendering is the point. PyMOL exits 0 having drawn nothing when the display
# path is wrong, so the file is the check.
test -s out.png || { echo "no PNG rendered"; tail -15 pm.log; exit 1; }
echo "ok: $(wc -c < out.png) byte PNG"
