#!/bin/sh
# MMseqs2 self-test: search a sequence against itself and demand a hit.
# Run:  chpc-tool test mmseqs2
set -eu
printf '>q\nMKTAYIAKQRQISFVKSHFSRQLEERLGLIEVQAPILSRVGDGTQDNLSGAEKAVQVKVKALPDAQFEVVHSLAKWKR\n' > q.fa
"$CHPC_TOOL" exec mmseqs2 -- mmseqs easy-search q.fa q.fa res.m8 tmp --threads 2 > mm.log 2>&1 || {
    echo "mmseqs exited non-zero:"; tail -15 mm.log; exit 1; }
test -s res.m8 || { echo "no alignment written -- a sequence must match itself"; tail -15 mm.log; exit 1; }
echo "ok: self-hit identity $(awk 'NR==1{print $3}' res.m8)"
