#!/bin/sh
# python-bio self-test: the named environment's interpreter does real work.
# Run:  CHPC_PYENV=iggase chpc-tool test python-bio        (CPU, ~5 s)
#
# Passed 2026-09-26 on ccpu1-01 against CHPC_PYENV=iggase:
# python 3.12.14, gemmi 0.7.5, numpy 2.5.3, biopython 1.83, no torch.
#
# THIS ENTRY IS A MECHANISM, NOT AN ENVIRONMENT, and the test is shaped by
# that. The pins belong to the project -- a project that asserts recorded
# numbers off a pairwise alignment cannot share an interpreter with one that
# does not care which numpy it gets -- so there is no single environment this
# file could target. It targets the one the CALLER names, and refuses to run
# without a name rather than inventing one.
#
# That refusal is deliberate and is the opposite of what `doctor` does. Doctor
# returns 2, "not checked", because a false FAIL in a status table is worse
# than a missing row (../README.md). A test is not a status table: a green tick
# from a test that had nothing to test against is a lie, and it is exactly the
# lie that gets quoted back later. So doctor shrugs and the test fails.
set -eu

if [ -z "${CHPC_PYENV:-}" ]; then
    cat >&2 <<'MSG'
CHPC_PYENV is not set, so there is no environment to test.

This entry does not own a recipe; a project supplies the yml and the name, and
this test runs against whichever one you name:

    CHPC_PYENV=iggase chpc-tool test python-bio

Refusing rather than passing is the point -- see the comment at the top of
this file. `chpc-tool doctor python-bio` is the one that shrugs.
MSG
    exit 1
fi

: "${PYTHON:?not set -- run through chpc-tool, which exports it from tool_exports}"

[ -x "$PYTHON" ] || {
    echo "no interpreter at $PYTHON" >&2
    echo "the environment named by CHPC_PYENV=$CHPC_PYENV does not exist yet." >&2
    echo "  module load CBI; module load miniforge3; conda env create -f <yml>" >&2
    echo "  (never pipe \`module load\` -- it runs in a subshell and the change" >&2
    echo "   never reaches you; see ../../docs/06)" >&2
    exit 1
}

# The interpreter must be the one belonging to the environment we asked for,
# not whatever python happened to be first on PATH. A conda entry has no exec
# form, so this is the only guard against testing the wrong interpreter.
case "$PYTHON" in
    */"$CHPC_PYENV"/bin/python) ;;
    *) echo "PYTHON=$PYTHON does not sit inside an env named '$CHPC_PYENV'" >&2
       exit 1 ;;
esac

M="$TOOLDIR/../_template/make_test_pdb.sh"
[ -f "$M" ] || { echo "no fixture generator at $M"; exit 1; }
sh "$M" 40 A mixed > t.pdb

# Each of the three libraries is asked to DO something whose answer is known,
# rather than to import. The registry's own table of expensive failures is all
# of one shape -- the natural check passes while the thing is broken -- and a
# conda environment is where that happens most, because solving it again on a
# different day can quietly swap a BLAS, a compiler or a whole torch build
# (see placer, in ../README.md).
if ! "$PYTHON" - > probe.log 2>&1 <<'PY'
import sys

# --- gemmi: parse a structure, and count what is in it ----------------------
# A broken or partially-built gemmi imports and reports a version perfectly
# well; what it cannot do is read 160 atoms out of this file and put them in
# the right residues in the right order.
import gemmi
st = gemmi.read_structure("t.pdb")
st.setup_entities()
assert len(st) == 1, ("models", len(st))
chains = [ch for model in st for ch in model]
assert len(chains) == 1, ("chains", [c.name for c in chains])
ch = chains[0]
assert ch.name == "A", ch.name
assert len(ch) == 40, ("residues", len(ch))
n_atoms = sum(len(r) for r in ch)
assert n_atoms == 160, ("atoms", n_atoms)   # N, CA, C, O per residue
seq = gemmi.one_letter_code([r.name for r in ch])
WANT = "AELKIRVTWDFSYNMQHPGC" * 2
assert seq == WANT, ("sequence", seq, "wanted", WANT)

# --- numpy: a linear-algebra result, which needs a working BLAS -------------
# `import numpy` succeeds against a numpy whose BLAS is missing or mismatched.
# Solving a system and checking the residual does not.
import numpy as np
A = np.array([[3.0, 1.0], [1.0, 2.0]])
b = np.array([9.0, 8.0])
x = np.linalg.solve(A, b)
assert np.allclose(x, [2.0, 3.0]), ("solve", x)
assert float(np.abs(A @ x - b).max()) < 1e-12, ("residual", np.abs(A @ x - b).max())

# --- biopython: an alignment score off a substitution matrix ----------------
# This is the one the project's recorded numbers depend on, so it is the one
# worth pinning. 116.0 is the BLOSUM62 diagonal summed over the 20 residues the
# fixture generator cycles -- arithmetic over the matrix, not a version's
# opinion -- and a single substitution must lower it.
from Bio import Align
al = Align.PairwiseAligner()
al.open_gap_score = -10
al.extend_gap_score = -0.5
al.substitution_matrix = Align.substitution_matrices.load("BLOSUM62")
one = "AELKIRVTWDFSYNMQHPGC"
self_score = al.score(one, one)
assert self_score == 116.0, ("BLOSUM62 self-score", self_score)
sub_score = al.score(one, one[:-1] + "A")        # C -> A at the end
assert sub_score < self_score, ("substitution did not lower the score",
                                sub_score, self_score)

# --- and the absence this entry is named for -------------------------------
# "the light python layer ... and deliberately no torch". A yml that acquires
# torch turns a 300 MB environment into a several-GB one and starts competing
# for the GPU entries' CUDA stack. Asserting the absence is how that gets
# noticed on the day it happens rather than at the next quota alarm.
import importlib.util
assert importlib.util.find_spec("torch") is None, (
    "torch is present in this environment. python-bio is declared as the "
    "light layer with deliberately no torch; a project that needs torch "
    "wants a different entry, not this one.")

import Bio
print("python     %s" % sys.version.split()[0])
print("gemmi      %s  (40 residues, 160 atoms, sequence exact)" % gemmi.__version__)
print("numpy      %s  (solve residual 0)" % np.__version__)
print("biopython  %s  (BLOSUM62 self %.1f, one substitution %.1f)"
      % (Bio.__version__, self_score, sub_score))
print("torch      absent, as declared")
PY
then
    echo "python-bio probe failed in env '$CHPC_PYENV':" >&2
    tail -25 probe.log >&2
    exit 1
fi
cat probe.log

echo
echo "ok: CHPC_PYENV=$CHPC_PYENV -- gemmi parses and counts, numpy solves with a"
echo "    working BLAS, biopython scores off BLOSUM62, and torch is absent."
echo "    Record those versions beside any number a script of yours produced."
