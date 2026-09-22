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
# compiler inside the image; this image is python:3.12-slim and has none.
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

if ! "$CHPC_TOOL" exec boltz -- boltz predict big.yaml \
        --cache "$BOLTZ_CACHE" \
        --out_dir out_big \
        --accelerator gpu --devices 1 \
        --recycling_steps 1 --sampling_steps 20 --diffusion_samples 1 \
        --output_format pdb --seed 37 \
        --override > boltz_big.log 2>&1
then
    echo "boltz predict exited non-zero on the ${#BIG}-residue case."
    if grep -q "Failed to find C compiler" boltz_big.log; then
        echo "  CAUSE: no C compiler in the image, so Triton cannot build the"
        echo "  cuequivariance kernels. Every prediction above ~128 tokens"
        echo "  fails this way. Either rebuild the image with gcc, or pass"
        echo "  --no_kernels, which costs speed only."
    fi
    tail -20 boltz_big.log; exit 1
fi

bigpdb=$(find out_big -name '*.pdb' -type f 2>/dev/null | head -1)
[ -n "$bigpdb" ] || { echo "no .pdb from the ${#BIG}-residue case"; tail -20 boltz_big.log; exit 1; }
n_big=$(grep -c '^ATOM.* CA ' "$bigpdb" || true)
[ "$n_big" -eq "${#BIG}" ] \
    || { echo "expected ${#BIG} CA atoms, got $n_big"; exit 1; }

echo "ok: kernel path exercised, $n_big CA atoms in $(basename "$bigpdb")"
