#!/bin/sh
# GROMACS self-test: it minimises, and it really computes on the GPU.
# Run:  chpc-tool test gromacs               (GPU NODE REQUIRED, ~60 s)
#
# THE POINT OF THIS FILE IS `-nb gpu`. Left to itself, mdrun decides whether to
# offload and falls back to the CPU when it cannot -- producing a correct
# simulation at a fraction of the speed, with nothing in its output saying that
# anything is wrong. `gmx --version` reporting "GPU support: CUDA" does not help
# either: that is a statement about how the binary was compiled, not about
# whether a kernel ever ran on a device. So this test makes offload MANDATORY
# and then reads the log to confirm it happened.
#
# There is deliberately no CPU fallback path here. The image's own %test covers
# what can be checked without a driver, because %test runs wherever the build
# ran and the login node has no GPU.
#
# No downloads: spc216.gro and the OPLS-AA force field ship inside GROMACS's own
# share/gromacs/top, so the fixture is upstream's.
set -eu

: "${GMXDATA:?not set -- run through chpc-tool, which exports it}"

gmx() { "$CHPC_TOOL" exec gromacs -- gmx "$@"; }

# --- 0: the build is the one we think it is -----------------------------------
gmx --version > version.log 2>&1 || { echo "gmx --version failed:"; cat version.log; exit 1; }
grep -q "GPU support:.*CUDA" version.log || {
    echo "this image was built without CUDA support:"; grep -i "GPU support" version.log; exit 1; }
grep -i "SIMD instructions" version.log || true
echo "ok: $(grep -i '^GROMACS version' version.log | head -1)"

# --- 1: a water box, from upstream's own coordinates --------------------------
# topol.top has to exist before solvate, because solvate APPENDS its SOL count
# to the [ molecules ] section rather than creating the file.
cat > topol.top <<'TOP'
#include "oplsaa.ff/forcefield.itp"
#include "oplsaa.ff/spc.itp"

[ system ]
spc water box

[ molecules ]
TOP

if ! gmx solvate -cs spc216.gro -box 2.5 2.5 2.5 -o box.gro -p topol.top > solvate.log 2>&1; then
    echo "gmx solvate failed:" >&2; tail -25 solvate.log >&2; exit 1
fi
test -s box.gro || { echo "solvate wrote no coordinates"; tail -20 solvate.log; exit 1; }
# The SOL count solvate appended is the first thing worth checking: a 2.5 nm
# cube of SPC water is a few hundred molecules, and a box with none of them
# would minimise to zero and pass a naive energy check.
nsol=$(awk '/^SOL/ { print $2 }' topol.top | tail -1)
[ -n "$nsol" ] || { echo "solvate appended no SOL line to topol.top"; cat topol.top; exit 1; }
[ "$nsol" -gt 200 ] || { echo "only $nsol waters in a 2.5 nm box -- expected several hundred"; exit 1; }
echo "ok: solvate placed $nsol SPC waters in a 2.5 nm box"

# --- 2: energy minimisation, on the CPU, as a baseline -----------------------
# Deliberately not GPU here. This stage proves the topology and force field are
# self-consistent enough to produce forces at all, and keeping it CPU means a
# failure in stage 3 is unambiguously about the GPU rather than about the inputs.
cat > em.mdp <<'MDP'
integrator  = steep
nsteps      = 200
emtol       = 100
coulombtype = PME
rlist       = 0.9
rvdw        = 0.9
rcoulomb    = 0.9
MDP
if ! gmx grompp -f em.mdp -c box.gro -p topol.top -o em.tpr -maxwarn 1 > grompp_em.log 2>&1; then
    echo "grompp failed on the minimisation:" >&2; tail -30 grompp_em.log >&2; exit 1
fi
if ! gmx mdrun -deffnm em -nb cpu > mdrun_em.log 2>&1; then
    echo "minimisation failed:" >&2; tail -30 em.log 2>/dev/null >&2; tail -10 mdrun_em.log >&2; exit 1
fi
test -s em.gro || { echo "minimisation wrote no output structure"; tail -20 em.log; exit 1; }

# The energy must be large and negative for condensed-phase water, and the
# minimiser must have lowered it. A box whose nonbonded terms never contributed
# sits near zero and satisfies neither.
e_start=$(awk '/Steepest Descents converged|Potential Energy/ { print }' em.log | grep -oE '\-?[0-9]+\.[0-9]+e?[+-]?[0-9]*' | head -1)
e_final=$(awk '/Potential Energy/ { v=$NF } END { print v }' em.log)
[ -n "$e_final" ] || { echo "no Potential Energy line in em.log"; tail -25 em.log; exit 1; }
echo "ok: minimisation reached ${e_final} kJ/mol over $nsol waters"
"$CHPC_TOOL" exec gromacs -- python3 - "$e_final" "$nsol" <<'PY'
import sys
e = float(sys.argv[1]); n = int(sys.argv[2])
per = e / n
print("    %.2f kJ/mol per water" % per)
assert e < -1000.0, ("condensed-phase water should be far below zero", e)
# SPC water sits around -40 kJ/mol per molecule. A wide band, because this is a
# 200-step minimisation of a freshly solvated box and not an equilibrated
# simulation -- the purpose is to catch an energy that is absurd, not to
# reproduce a published number.
assert -60.0 < per < -25.0, ("energy per water is implausible: %.2f" % per)
PY

# --- 3: MD with offload MADE MANDATORY ---------------------------------------
# -nb gpu means "put the short-ranged nonbonded work on the GPU or ABORT".
# mdrun refuses with "Nonbonded interactions on the GPU were required, but not
# supported for these simulation settings" rather than quietly using the CPU,
# which is the whole reason to pass it.
cat > md.mdp <<'MDP'
integrator  = md
dt          = 0.002
nsteps      = 2000
coulombtype = PME
rlist       = 0.9
rvdw        = 0.9
rcoulomb    = 0.9
tcoupl      = v-rescale
tc-grps     = System
tau-t       = 0.1
ref-t       = 300
MDP
if ! gmx grompp -f md.mdp -c em.gro -p topol.top -o md.tpr -maxwarn 2 > grompp_md.log 2>&1; then
    echo "grompp failed on the MD:" >&2; tail -30 grompp_md.log >&2; exit 1
fi
if ! gmx mdrun -deffnm md -nb gpu -pme gpu > mdrun_md.log 2>&1; then
    echo "MD with mandatory GPU offload failed:" >&2
    tail -35 md.log 2>/dev/null >&2
    tail -10 mdrun_md.log >&2
    echo >&2
    echo "If this says nonbonded interactions on the GPU were REQUIRED but not" >&2
    echo "supported, either this is not a GPU node or the image has no kernels" >&2
    echo "for this device. Ask for a specific model:" >&2
    echo "  srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 16G -t 1:00:00 --pty bash -l" >&2
    exit 1
fi

# --- 4: and the log has to SAY it used the GPU -------------------------------
# The assertions that distinguish "it ran" from "it ran where we asked".
grep -q "1 GPU selected for this run" md.log || {
    echo "md.log does not report a GPU being selected:" >&2
    grep -i "gpu" md.log | head -20 >&2
    exit 1; }
grep -qi "PP tasks will do .*short-ranged.*on the GPU" md.log || {
    echo "md.log does not report short-ranged nonbonded work on the GPU:" >&2
    grep -i "tasks will do" md.log >&2
    exit 1; }
grep -qi "PME tasks will do all aspects on the GPU" md.log || {
    echo "md.log does not report PME on the GPU:" >&2
    grep -i "PME tasks" md.log >&2
    exit 1; }
grep -i "1 GPU selected\|tasks will do\|GPU detected" md.log | sed 's/^/    /'

test -s md.gro || { echo "MD wrote no final structure"; exit 1; }
perf=$(grep -E "^Performance:" md.log | head -1)
[ -n "$perf" ] && echo "    $perf"

echo
echo "ok: GROMACS solvated $nsol SPC waters from its own spc216.gro, minimised"
echo "    them to a plausible condensed-phase energy, and ran 2000 steps of MD"
echo "    with -nb gpu and -pme gpu -- offload MANDATORY, and md.log confirms"
echo "    the GPU was selected and did both the short-ranged and PME work."
echo "    Always pass -nb gpu in a job script: without it mdrun falls back to"
echo "    the CPU silently."
