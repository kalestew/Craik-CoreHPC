#!/bin/sh
# Chai-1 self-test: fold a short peptide end to end.
# Run:  chpc-tool test chai1
#
# MUST run on an L40S or H100/H200. Measured, not inferred: chai's torch is
# 2.6.0+cu124 and torch._C._cuda_getArchFlags() reports
#   sm_50 sm_60 sm_70 sm_75 sm_80 sm_86 sm_90
# with no sm_120, so on a Blackwell node (ggpu1-[13-19]) this dies at the
# first kernel launch. Ask for --gres=gpu:nvidia_l40s:1, never --gres=gpu:1.
set -eu

: "${CHAI_DOWNLOADS_DIR:?not set -- run through chpc-tool, which exports it}"

# All three parts of the cache, because a missing ESM trace is the failure
# that otherwise shows up minutes into a fold rather than here. The trace is
# a separate 5.6 GB download from a different URL than the six components;
# tools/chai1/fetch-weights.sh gets all of it.
for f in models_v2/trunk.pt models_v2/diffusion_module.pt \
         models_v2/confidence_head.pt conformers_v1.apkl \
         esm/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt; do
    test -s "$CHAI_DOWNLOADS_DIR/$f" || {
        echo "missing $CHAI_DOWNLOADS_DIR/$f"
        echo "fetch with: tools/chai1/fetch-weights.sh"; exit 1; }
done

# chai's header grammar is 'protein|name=...' (inference_dataset.py:239-246).
# A plain '>seq' header parses as a fasta record and then fails entity-type
# dispatch, which is a confusing error for a simple mistake.
cat > in.fasta <<'EOF'
>protein|name=test-peptide
MKTAYIAKQRQISFVKSHFSRQLEERLGLIE
EOF

# Cheapest settings that still exercise every stage. Defaults are 3 trunk
# recycles, 200 diffusion timesteps and 5 samples; this is one of each and 20
# steps, which runs the same code paths in a fraction of the time. Not
# --no-use-esm-embeddings: leaving embeddings ON is the point, since that is
# the path that needs the 5.6 GB trace and the one most likely to be missing.
if ! "$CHPC_TOOL" exec chai1 -- chai-lab fold \
        --num-trunk-recycles 1 --num-diffn-timesteps 20 \
        --num-diffn-samples 1 --num-trunk-samples 1 --seed 37 \
        in.fasta out > chai.log 2>&1
then
    echo "chai-lab fold exited non-zero:"
    if grep -q "no kernel image is available" chai.log; then
        echo
        echo ">>> sm_120: the job landed on a Blackwell node. chai's torch is"
        echo ">>> cu124 and has no kernels for it. Use --gres=gpu:nvidia_l40s:1."
        echo
    fi
    tail -30 chai.log; exit 1
fi

cif=$(ls -1 out/*.cif 2>/dev/null | head -1 || true)
[ -n "$cif" ] || { echo "no .cif written"; ls -R out 2>/dev/null | head -20; tail -30 chai.log; exit 1; }

# Assert on the structure, not the exit code. Chai can write a well-formed
# file of degenerate coordinates and exit 0.
n_ca=$(grep -c ' CA ' "$cif" || true)
[ "$n_ca" -ge 31 ] || { echo "expected >=31 CA records for a 31-mer, got $n_ca"; exit 1; }
if grep -qi 'nan' "$cif"; then echo "NaN coordinates in $cif"; exit 1; fi

# A folded peptide is not a point cloud at the origin: demand real spread.
# This is what separates "wrote a CIF" from "ran the diffusion module".
spread=$(awk '/ CA /{n++; x+=$11; y+=$12; z+=$13; xx+=$11*$11; yy+=$12*$12; zz+=$13*$13}
              END{ if(n<2){print 0; exit}
                   vx=xx/n-(x/n)^2; vy=yy/n-(y/n)^2; vz=zz/n-(z/n)^2;
                   printf "%.2f", sqrt(vx+vy+vz) }' "$cif")
awk -v s="$spread" 'BEGIN{ exit !(s > 3.0) }' \
    || { echo "CA radius of gyration $spread A is too small to be a fold"; exit 1; }

echo "ok: $n_ca CA records in $(basename "$cif"), CA spread ${spread} A"
