#!/bin/sh
# Boltz-2 self-test: predict a short peptide from sequence alone.
# Run:  chpc-tool test boltz      (GPU; --accelerator cpu also works, slower)
set -eu

: "${BOLTZ_CACHE:?not set -- run through chpc-tool, which exports it}"

# Absolute, or boltz resolves --cache against the working directory and a
# job that cd's elsewhere silently uses a different, empty cache -- then
# tries to download 6 GB from a node with no internet.
case "$BOLTZ_CACHE" in
  /*) ;;
  *)  echo "BOLTZ_CACHE must be absolute, got: $BOLTZ_CACHE"; exit 1 ;;
esac

n_ckpt=$(find "$BOLTZ_CACHE" -type f -name '*.ckpt' 2>/dev/null | wc -l)
[ "$n_ckpt" -ge 1 ] || {
    echo "no checkpoint under $BOLTZ_CACHE"
    echo "fetch with: tools/boltz/fetch-weights.sh"; exit 1; }

# `msa: empty` is boltz's explicit single-sequence mode (schema.py:1127).
# It is used here for the same reason colabfold's test uses
# --msa-mode single_sequence: --use_msa_server queries a remote MMseqs2 API
# that a compute node cannot reach, so a test relying on it would pass on
# the login node and fail in every job.
cat > in.yaml <<'EOF'
version: 1
sequences:
  - protein:
      id: A
      sequence: MKTAYIAKQRQISFVKSHFSRQLEERLGLIE
      msa: empty
EOF

if ! "$CHPC_TOOL" exec boltz -- boltz predict in.yaml \
        --cache "$BOLTZ_CACHE" \
        --out_dir out \
        --accelerator gpu --devices 1 \
        --recycling_steps 1 --sampling_steps 20 --diffusion_samples 1 \
        --output_format pdb --seed 37 \
        --override > boltz.log 2>&1
then
    echo "boltz predict exited non-zero:"
    tail -30 boltz.log; exit 1
fi

pdb=$(find out -name '*.pdb' -type f 2>/dev/null | head -1)
[ -n "$pdb" ] || { echo "no .pdb written"; find out -type f 2>/dev/null | head -20; tail -30 boltz.log; exit 1; }

n_ca=$(grep -c '^ATOM.* CA ' "$pdb" || true)
[ "$n_ca" -eq 31 ] || { echo "expected 31 CA atoms for a 31-mer, got $n_ca"; exit 1; }

# Coordinate columns only. A substring search for "nan" over a structure
# file matches ordinary metadata and condemns good results; and capture the
# output rather than piping into `if`, whose status would be head's.
bad=$(awk '/^ATOM/ { x = substr($0,31,8); y = substr($0,39,8); z = substr($0,47,8)
                     if (x " " y " " z ~ /[Nn][Aa][Nn]|[Ii][Nn][Ff]|\*/) print }' "$pdb" | head -3)
[ -z "$bad" ] || { echo "non-finite coordinates in $pdb:"; echo "$bad"; exit 1; }

# Real spread, not a collapsed point cloud -- what separates "wrote a PDB"
# from "ran the diffusion module".
spread=$(awk '/^ATOM.* CA /{ x=substr($0,31,8)+0; y=substr($0,39,8)+0; z=substr($0,47,8)+0
                             n++; sx+=x; sy+=y; sz+=z; qx+=x*x; qy+=y*y; qz+=z*z }
              END { if (n<2) { print 0; exit }
                    vx=qx/n-(sx/n)^2; vy=qy/n-(sy/n)^2; vz=qz/n-(sz/n)^2
                    printf "%.2f", sqrt(vx+vy+vz) }' "$pdb")
awk -v s="$spread" 'BEGIN { exit !(s > 3.0) }' \
    || { echo "CA radius of gyration $spread A is too small to be a fold"; exit 1; }

echo "ok: $n_ca CA atoms in $(basename "$pdb"), CA spread ${spread} A"

# --- second case: big enough to reach the cuequivariance kernels -------------
# The 31-mer above does NOT exercise them, and that is how this test came to
# pass while every real job failed. Boltz turns the kernels on by default and
# they are Triton, which JIT-compiles them at first use and so needs a C
# compiler inside the image. boltz_2.sif was python:3.12-slim and had none;
# boltz_2_gcc.sif exists to carry one, and THIS CASE IS THE THING THAT PROVES
# IT. On boltz_2.sif it fails by design.
#
# WHICH DEVICE THIS RAN ON IS PART OF THE RESULT, so it is printed. The gpu
# partition is three device classes and a bare --gres=gpu:1 takes whichever is
# idle, so "case 2 passed" without a device name does not say whether the
# kernels were built for sm_89, sm_90 or sm_120. The Blackwell nodes
# (ggpu1-[13-19], --gres=gpu:nvidia_rtx_pro_6000:1) are the ones that have
# never run a cuequivariance kernel: the sm_120 measurement this entry rests on
# folded the 31-mer above, which is below the size that reaches one at all.
# Run this case there explicitly before trusting a bare --gres=gpu:1.
# DONE 2026-09-26: job 1997377 on ggpu1-16 (RTX PRO 6000, sm_120) passed it
# with the kernels on, 27 s for the 213-mer; job 1997947 agreed on the same node.
#
# Measured 2026-09-22 on an L40S: 31 aa and 71 aa predict fine with kernels on,
# 142 aa does not, and neither does anything larger. One chain or two makes no
# difference -- 2 x 71 fails and 1 x 142 fails, both at 142 total tokens -- so
# the boundary is total token count and lies between 71 and 142. 213 aa is
# comfortably past it without being slow.
#
# If the kernels cannot build, boltz exits non-zero with
#   RuntimeError: Failed to find C compiler.
# and writes nothing, so the existing failure path catches it. `--no_kernels`
# is the supported escape hatch and costs speed only.
dev=$("$CHPC_TOOL" exec boltz -- python -c \
        'import torch; i=torch.cuda.get_device_properties(0); print(f"{i.name} sm_{i.major}{i.minor}")' \
        2>/dev/null || echo "unknown device")
echo "device: $dev"

U="SYESQAELTQKTAADIEAELRAEAEKHEAEGTPEEGERFRAEAEERIAAIRAAADEAIAEYEAKAAAERAA"
BIG="${U}${U}${U}"
cat > big.yaml <<EOF
version: 1
sequences:
  - protein:
      id: A
      sequence: $BIG
      msa: empty
EOF

t0=$(date +%s)
if ! "$CHPC_TOOL" exec boltz -- boltz predict big.yaml \
        --cache "$BOLTZ_CACHE" \
        --out_dir out_big \
        --accelerator gpu --devices 1 \
        --recycling_steps 1 --sampling_steps 20 --diffusion_samples 1 \
        --output_format pdb --seed 37 \
        --override > boltz_big.log 2>&1
then
    echo "boltz predict exited non-zero on the ${#BIG}-residue case, on $dev."
    # Three distinct causes, which matter because the remedies are opposite.
    if grep -q "Failed to find C compiler" boltz_big.log; then
        echo "  CAUSE: no C compiler in the image, so Triton cannot build the"
        echo "  cuequivariance kernels. Every prediction above ~128 tokens"
        echo "  fails this way. Either use boltz_2_gcc.sif, which carries one,"
        echo "  or pass --no_kernels, which costs speed only."
    elif grep -qi "libcuda" boltz_big.log; then
        echo "  CAUSE: Triton found a compiler and could not LINK. Its launcher"
        echo "  wants libcuda.so, and a driver bind often provides only"
        echo "  libcuda.so.1. This is a container/driver problem, not a missing"
        echo "  compiler: set TRITON_LIBCUDA_PATH to the directory holding the"
        echo "  driver library, or fall back to --no_kernels."
    elif grep -qi "no kernel image is available\|not supported on this device\|sm_120\|PTX" boltz_big.log; then
        echo "  CAUSE: this looks like an ARCHITECTURE failure on $dev, not a"
        echo "  build one. The cuequivariance Triton kernels have never been"
        echo "  measured on Blackwell (sm_120). If that is where this landed,"
        echo "  set GPU_MAX_CC=9.0 in tool.conf -- boltz would then stop being"
        echo "  the one tool here that runs on any gpu node -- and re-run this"
        echo "  case on --gres=gpu:nvidia_l40s:1 to confirm the kernels are"
        echo "  fine and only the device was wrong."
    fi
    tail -20 boltz_big.log; exit 1
fi

bigpdb=$(find out_big -name '*.pdb' -type f 2>/dev/null | head -1)
[ -n "$bigpdb" ] || { echo "no .pdb from the ${#BIG}-residue case"; tail -20 boltz_big.log; exit 1; }
n_big=$(grep -c '^ATOM.* CA ' "$bigpdb" || true)
[ "$n_big" -eq "${#BIG}" ] \
    || { echo "expected ${#BIG} CA atoms, got $n_big"; exit 1; }

# The wall time is the point of the rebuild, so record it rather than leaving
# "is it actually faster?" to be re-measured by whoever next wonders. Compare
# against the SAME case with --no_kernels, not against a different fold.
echo "ok: kernel path exercised on $dev, $n_big CA atoms in $(basename "$bigpdb"), $(( $(date +%s) - t0 )) s"
echo
echo "To measure what the kernels bought, re-run this case with --no_kernels"
echo "on the same device and compare. Kernels on is a DIFFERENT COMPUTATION in"
echo "this project's digest, not merely a faster one, so the comparison is"
echo "worth having before any baseline is re-folded against it."
