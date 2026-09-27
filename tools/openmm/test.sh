#!/bin/sh
# OpenMM self-test: the CUDA platform REGISTERS and computes the right number.
# Run:  chpc-tool test openmm              (GPU NODE REQUIRED, ~20 s)
#
# This test must run on a GPU node and there is deliberately no way to skip the
# CUDA half. The image's own %test covers the CPU platform, because %test runs
# wherever the build ran and the login node -- the only node with internet, so
# the only node that can build -- has no NVIDIA driver and cannot register CUDA
# at all. Everything CUDA is therefore owed here, and an escape hatch would be
# used at 6pm and then quoted back as a green test.
#
# WHY AN IMPORT PROVES NOTHING. openmm/__init__.py calls
# Platform.loadPluginsFromDirectory and NEVER RAISES when a plugin fails to
# load; the errors are only retrievable through
# openmm.Platform.getPluginLoadFailures(). So a CPU-only or mis-solved
# installation imports cleanly, reports a version, and runs every simulation
# correctly on the CPU platform -- at which point an MD run that should have
# taken an hour takes a week and nothing anywhere says why. That is the failure
# this file exists to catch.
set -eu

: "${OPENMM_PYTHON:?not set -- run through chpc-tool, which exports it}"

if ! "$CHPC_TOOL" exec openmm -- python - > cuda.log 2>&1 <<'PY'
import sys
import openmm as mm
import openmm.unit as u

print("openmm", mm.__version__)

# 1. Plugin load failures, first. This is the diagnostic the import swallowed,
#    and reading it before anything else means a broken CUDA stack reports the
#    REASON rather than just its consequence.
fails = mm.Platform.getPluginLoadFailures()
for f in fails:
    print("plugin load failure:", f, file=sys.stderr)
assert not fails, (
    "OpenMM failed to load %d plugin(s) -- see above. This is what an import "
    "hides: the module is fine and the CUDA platform is gone." % len(fails))
print("no plugin load failures")

# 2. The platform must be REGISTERED. Listing the names is the check that
#    corresponds to the run-time error people actually hit,
#    'There is no registered Platform called "CUDA"'.
names = [mm.Platform.getPlatform(i).getName() for i in range(mm.Platform.getNumPlatforms())]
print("platforms", names)
assert "CUDA" in names, (
    "no CUDA platform registered; only %s. Either this is not a GPU node, or "
    "the image is a CPU-only openmm. tool_doctor reports the plugin file "
    "separately, which distinguishes the two." % names)
platform = mm.Platform.getPlatformByName("CUDA")

# 3. Build a Context on it, which is what forces the kernels to compile. This
#    is the step that catches a CUDA build mismatched to the driver --
#    CUDA_ERROR_UNSUPPORTED_PTX_VERSION -- and it cannot be reached by
#    inspecting the installation, only by running it.
system = mm.System()
system.addParticle(1.0 * u.amu)
system.addParticle(1.0 * u.amu)
force = mm.HarmonicBondForce()
force.addBond(0, 1, 0.1 * u.nanometer, 100.0 * u.kilojoule_per_mole / u.nanometer ** 2)
system.addForce(force)
context = mm.Context(system, mm.VerletIntegrator(0.001 * u.picoseconds), platform)
assert context.getPlatform().getName() == "CUDA", context.getPlatform().getName()

# 4. And the number has to be right. A harmonic bond stretched 0.1 nm past its
#    0.1 nm equilibrium at k = 100 kJ/mol/nm^2 is exactly
#    E = 0.5 * 100 * (0.2 - 0.1)^2 = 0.5 kJ/mol.
#    Arithmetic, not a tolerance dressed up as one: a GPU that computed on
#    uninitialised memory, or a kernel built for the wrong architecture, does
#    not land on 0.5.
context.setPositions([mm.Vec3(0, 0, 0), mm.Vec3(0.2, 0, 0)] * u.nanometer)
e = context.getState(getEnergy=True).getPotentialEnergy().value_in_unit(u.kilojoule_per_mole)
print("CUDA harmonic-bond energy %.6f kJ/mol (expected 0.500000)" % e)
assert abs(e - 0.5) < 1e-5, ("CUDA computed %r, expected 0.5" % e)

# 5. Cross-check CUDA against the Reference platform on the same system. Two
#    independent implementations agreeing is a stronger statement than either
#    matching a number written in this file, and it is what
#    openmm.testInstallation does.
ref = mm.Context(system, mm.VerletIntegrator(0.001 * u.picoseconds),
                 mm.Platform.getPlatformByName("Reference"))
ref.setPositions([mm.Vec3(0, 0, 0), mm.Vec3(0.2, 0, 0)] * u.nanometer)
e_ref = ref.getState(getEnergy=True).getPotentialEnergy().value_in_unit(u.kilojoule_per_mole)
print("Reference platform %.6f kJ/mol" % e_ref)
assert abs(e - e_ref) < 1e-5, ("CUDA %r disagrees with Reference %r" % (e, e_ref))

# 6. Record what it ran on, so the log says which architecture was proven.
print("device", platform.getPropertyValue(context, "DeviceName"))
print("precision", platform.getPropertyValue(context, "Precision"))
PY
then
    echo "openmm CUDA check failed:" >&2
    tail -30 cuda.log >&2
    echo >&2
    echo "If this says 'no CUDA platform registered', check whether you are on a" >&2
    echo "GPU node: srun -p gpu --gres=gpu:nvidia_l40s:1 ... and try again." >&2
    exit 1
fi
cat cuda.log

# openmm's own installation check, which cross-validates forces between every
# registered platform. Slower than the above and worth running once here.
if ! "$CHPC_TOOL" exec openmm -- python -m openmm.testInstallation > install.log 2>&1; then
    echo "openmm.testInstallation failed:" >&2; tail -25 install.log >&2; exit 1
fi
grep -q 'CUDA' install.log || { echo "testInstallation did not exercise CUDA:"; cat install.log; exit 1; }
tail -20 install.log

echo
echo "ok: the CUDA platform registers with no plugin load failures, builds a"
echo "    Context (so kernels compiled against this driver), computes the"
echo "    harmonic-bond energy as 0.5 kJ/mol, and agrees with the Reference"
echo "    platform. Remember to NAME the platform in your own scripts: OpenMM"
echo "    falls back to CPU silently."
