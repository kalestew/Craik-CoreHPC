#!/bin/sh
# RFdiffusion self-test: generate one short unconditional backbone.
# Run:  chpc-tool test rfdiffusion
#
# MUST run on an L40S or H100/H200. The image is cu121, which has no sm_120
# kernels, so on a Blackwell node (ggpu1-[13-19]) this dies at the first
# kernel launch with "no kernel image is available for execution on the
# device". Ask for --gres=gpu:nvidia_l40s:1, never a bare --gres=gpu:1.
set -eu

: "${RFDIFFUSION_MODELS:?not set -- run through chpc-tool, which exports it}"
: "${RFDIFFUSION_SCHEDULES:?not set -- run through chpc-tool, which exports it}"

test -s "$RFDIFFUSION_MODELS/Base_ckpt.pt" || {
    echo "no Base_ckpt.pt under $RFDIFFUSION_MODELS"
    echo "fetch with: tools/rfdiffusion/fetch-weights.sh"; exit 1; }

# diffuser.T=15 rather than the default 50. The point is that the whole path
# runs -- hydra config, checkpoint load, the SE3Transformer forward, PDB
# output -- not that the backbone is any good.
#
# 15 is the FLOOR, not a preference. diffusion.py:28 is
#   assert T >= 15, "With discrete time and T < 15, the schedule is badly
#                     approximated"
# so a smaller value fails inside Diffuser.__init__ -- after the checkpoint
# has loaded, which makes it look like a model problem rather than an
# out-of-range argument.
#
# schedule_directory_path is NOT optional. RFdiffusion defaults it to a
# schedules/ directory inside the installed package, which it mkdirs and
# writes IGSO3 tables into on first run -- and the package is in a read-only
# squashfs, so the default fails with a permission error that looks nothing
# like a config problem.
#
# `python` spelled out: ENTRY is not prepended in front of a bare script path.
if ! "$CHPC_TOOL" exec rfdiffusion -- python \
        /opt/RFdiffusion/scripts/run_inference.py \
        "inference.model_directory_path=$RFDIFFUSION_MODELS" \
        "inference.schedule_directory_path=$RFDIFFUSION_SCHEDULES" \
        "inference.output_prefix=out/t" \
        "inference.num_designs=1" \
        "contigmap.contigs=[20-20]" \
        "diffuser.T=15" > rfd.log 2>&1
then
    echo "run_inference.py exited non-zero:"
    if grep -q "no kernel image is available" rfd.log; then
        echo
        echo ">>> This is the sm_120 problem, not a broken image. The job landed"
        echo ">>> on a Blackwell node. Re-run with --gres=gpu:nvidia_l40s:1."
        echo
    fi
    tail -25 rfd.log; exit 1
fi

pdb=out/t_0.pdb
test -s "$pdb" || { echo "no backbone written at $pdb"; ls -R out 2>/dev/null | head; tail -25 rfd.log; exit 1; }

# Assert on the structure, not the exit code. RFdiffusion can write a file of
# NaN coordinates and exit 0 when the checkpoint half-loaded.
n_ca=$(grep -c '^ATOM.* CA ' "$pdb" || true)
[ "$n_ca" -eq 20 ] || { echo "expected 20 CA atoms, got $n_ca"; exit 1; }
# Check the coordinate COLUMNS, not the whole file. A substring search for
# "nan" is a false-positive generator -- it fired on chai's CIF against
# `_chem_comp.ma_provenance`, failing a good structure -- and a PDB REMARK
# can carry the same trap. PDB columns are fixed-width: x is 31-38, y 39-46,
# z 47-54.
#
# `if`, not `grep … && { … }`: under set -e the && form returns the failed
# grep's status, which would fail the test exactly when the file is clean.
# Capture, do not pipe inside `if`: a pipeline's status is the LAST
# command's, so `if awk ... | head` always sees head's 0 and reports failure
# on a clean file.
bad=$(awk '/^ATOM/ { x = substr($0,31,8); y = substr($0,39,8); z = substr($0,47,8)
                     if (x " " y " " z ~ /[Nn][Aa][Nn]|[Ii][Nn][Ff]|\*/) print }' "$pdb" | head -3)
if [ -n "$bad" ]; then
    echo "non-finite coordinates in $pdb:"; echo "$bad"; exit 1
fi

# Consecutive CA-CA distance is ~3.8 A in any real backbone. This is the
# assertion that separates "wrote a PDB" from "diffused a protein".
awk '/^ATOM.* CA /{
        x=substr($0,31,8)+0; y=substr($0,39,8)+0; z=substr($0,47,8)+0
        if (p) { d=sqrt((x-px)^2+(y-py)^2+(z-pz)^2)
                 if (d<3.0 || d>4.6) { printf "bad CA-CA distance %.2f at residue %d\n", d, NR; bad++ } }
        px=x; py=y; pz=z; p=1 }
     END { if (bad) exit 1 }' "$pdb" \
    || { echo "backbone geometry is not protein-like"; exit 1; }

echo "ok: 20-residue backbone at $pdb, CA-CA spacing in range"
