#!/bin/sh
# HH-suite self-test: profile-profile alignment with no database.
# Run:  chpc-tool test hhsuite
#
# hhalign is the right entry point for a self-test because it is the one
# HH-suite tool that needs no database. hhblits and hhsearch both want a
# prebuilt database (UniRef30, PDB70) that is tens of gigabytes and is a
# deployment question, not an image question. hhalign takes two alignments
# directly, so it exercises the parts this image is actually responsible for:
# A3M parsing, HMM construction, the Viterbi alignment and .hhr output.
set -eu

# Two sequences with a clear common core and divergent flanks, so the
# alignment has something to do. A pair of identical sequences would pass
# even if the aligner were replaced by a diagonal.
cat > q.a3m <<'EOF'
>query
MKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQAPILSRVGDGTQDNLSGAEKAVQVKVKALPDAQFEVVHSLAKWKR
EOF
cat > t.a3m <<'EOF'
>template
GGSSHHAKQRQISFVKSHFSRQLEERLGLIEVQAPILSRVGDGTQDNLSGCEKAVQVKVKALPDAQFEVVHSLAKWYYPP
EOF

"$CHPC_TOOL" exec hhsuite -- /opt/hhsuite/bin/hhalign \
    -i q.a3m -t t.a3m -o out.hhr -cpu 2 > hh.log 2>&1 || {
    echo "hhalign exited non-zero:"; tail -20 hh.log; exit 1; }

test -s out.hhr || { echo "hhalign wrote no .hhr"; tail -20 hh.log; exit 1; }

# Assert on the result, not the exit code. hhalign writes a well-formed but
# hit-less .hhr when nothing aligns, and exits 0 doing it.
grep -q "No 1" out.hhr || { echo "no hit in out.hhr:"; cat out.hhr; exit 1; }

# Probability is on the "Probab=" line of the first hit. These two share a
# ~60-residue core, so anything below 90 means the alignment went wrong.
prob=$(sed -n 's/.*Probab=\([0-9.]*\).*/\1/p' out.hhr | head -1)
[ -n "$prob" ] || { echo "could not read Probab from out.hhr"; cat out.hhr; exit 1; }
awk -v p="$prob" 'BEGIN{ exit !(p >= 90) }' \
    || { echo "hit probability $prob, expected >= 90"; exit 1; }

cols=$(sed -n 's/.*Aligned_cols=\([0-9]*\).*/\1/p' out.hhr | head -1)
echo "ok: hhalign hit at Probab=$prob over ${cols:-?} aligned columns"
