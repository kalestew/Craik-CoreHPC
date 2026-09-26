#!/bin/sh
# MMseqs2 self-test: search a sequence against itself and demand a hit.
# Run:  chpc-tool test mmseqs2
set -eu
printf '>q\nMKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQAPILSRVGDGTQDNLSGAEKAVQVKVKALPDAQFEVVHSLAKWKR\n' > q.fa
"$CHPC_TOOL" exec mmseqs2 -- mmseqs easy-search q.fa q.fa res.m8 tmp --threads 2 > mm.log 2>&1 || {
    echo "mmseqs exited non-zero:"; tail -15 mm.log; exit 1; }
test -s res.m8 || { echo "no alignment written -- a sequence must match itself"; tail -15 mm.log; exit 1; }
echo "ok: self-hit identity $(awk 'NR==1{print $3}' res.m8)"

# --- against Swiss-Prot, when it has been fetched ----------------------------
# fetch-db.sh puts it at $MMSEQS2_DB_SWISSPROT; without it the case is skipped
# and says so, because easy-search takes a FASTA as its target and the image
# is whole without a database. With it, the assertion is that the search runs
# and writes its table; the fixture is a real sequence, so a hit is expected
# and reported, but the identity of the top hit is upstream's business.
if [ -f "${MMSEQS2_DB_SWISSPROT:-}" ]; then
    "$CHPC_TOOL" exec mmseqs2 -- mmseqs easy-search q.fa "$MMSEQS2_DB_SWISSPROT" res_sp.m8 tmp_sp \
        --threads 2 > mm_sp.log 2>&1 || {
        echo "mmseqs exited non-zero against $MMSEQS2_DB_SWISSPROT:"; tail -15 mm_sp.log; exit 1; }
    [ -f res_sp.m8 ] || { echo "no res_sp.m8 from the Swiss-Prot search"; tail -15 mm_sp.log; exit 1; }
    echo "ok: Swiss-Prot search ran against $MMSEQS2_DB_SWISSPROT, $(wc -l < res_sp.m8 | tr -d ' ') hits, top: $(head -1 res_sp.m8 | cut -f2,3)"
else
    echo "skipped: no Swiss-Prot database at ${MMSEQS2_DB_SWISSPROT:-<unset>} (tools/mmseqs2/fetch-db.sh, on the login node)"
fi
