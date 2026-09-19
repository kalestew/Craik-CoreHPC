#!/bin/sh
# ColabFold self-test: predict a short peptide from sequence alone.
# Run:  chpc-tool test colabfold
#
# MUST run on an L40S or H100/H200. The upstream tag is cuda12.2, which
# predates sm_120, so on a Blackwell node (ggpu1-[13-19]) this dies at the
# first kernel launch. Ask for --gres=gpu:nvidia_l40s:1.
set -eu

: "${COLABFOLD_DATA:?not set -- run through chpc-tool, which exports it}"

test -d "$COLABFOLD_DATA/params" || {
    echo "no AlphaFold2 parameters at $COLABFOLD_DATA/params"
    echo "fetch with: tools/colabfold/fetch-weights.sh"; exit 1; }

cat > in.fasta <<'EOF'
>testpep
MKTAYIAKQRQISFVKSHFSRQLEERLGLIE
EOF

# --msa-mode single_sequence is not a shortcut, it is the only mode that
# works here. The default modes (mmseqs2_uniref_env, mmseqs2_uniref) query a
# REMOTE server at api.colabfold.com, and a compute node reaches a proxy that
# denies it (doc 02) -- the job then fails or hangs partway in, after the
# weights have loaded. Real runs must either precompute MSAs on the login
# node and pass --msa-directory, or accept single-sequence mode. A test that
# quietly depended on the network would pass on the login node and fail in
# every job, which is the wrong way round.
#
# --data is likewise mandatory, not tidiness: colabfold's default weights
# path is /cache/colabfold INSIDE the image, which is read-only.
if ! "$CHPC_TOOL" exec colabfold -- colabfold_batch \
        --msa-mode single_sequence \
        --model-type alphafold2_ptm \
        --num-models 1 \
        --data "$COLABFOLD_DATA" \
        in.fasta out > cf.log 2>&1
then
    echo "colabfold_batch exited non-zero:"
    if grep -q "no kernel image is available" cf.log; then
        echo
        echo ">>> sm_120: the job landed on a Blackwell node. This image is"
        echo ">>> cuda12.2. Use --gres=gpu:nvidia_l40s:1."
        echo
    fi
    tail -30 cf.log; exit 1
fi

pdb=$(ls -1 out/*.pdb 2>/dev/null | head -1 || true)
[ -n "$pdb" ] || { echo "no .pdb written"; ls -R out 2>/dev/null | head -20; tail -30 cf.log; exit 1; }

n_ca=$(grep -c '^ATOM.* CA ' "$pdb" || true)
[ "$n_ca" -eq 31 ] || { echo "expected 31 CA atoms for a 31-mer, got $n_ca"; exit 1; }

# Coordinate columns only -- a substring search for "nan" over a PDB matches
# REMARK text and condemns good structures. PDB x/y/z are columns 31-38,
# 39-46, 47-54. Capture and test for emptiness rather than piping into `if`,
# whose status would be head's and therefore always zero.
bad=$(awk '/^ATOM/ { x = substr($0,31,8); y = substr($0,39,8); z = substr($0,47,8)
                     if (x " " y " " z ~ /[Nn][Aa][Nn]|[Ii][Nn][Ff]|\*/) print }' "$pdb" | head -3)
[ -z "$bad" ] || { echo "non-finite coordinates in $pdb:"; echo "$bad"; exit 1; }

# pLDDT lands in the B-factor column (61-66). Single-sequence mode on a short
# peptide scores poorly and that is fine -- the assertion is that a real
# confidence was computed, not that the model is good.
plddt=$(awk '/^ATOM.* CA /{ s += substr($0,61,6); n++ } END { if (n) printf "%.1f", s/n }' "$pdb")
awk -v p="$plddt" 'BEGIN { exit !(p > 0 && p <= 100) }' \
    || { echo "mean pLDDT $plddt is not a plausible confidence"; exit 1; }

echo "ok: $n_ca CA atoms in $(basename "$pdb"), mean pLDDT $plddt"
