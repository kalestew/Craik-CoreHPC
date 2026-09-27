#!/bin/sh
# RFdiffusion3 self-test: it designs a backbone, and it holds a covalent bond.
# Run:  chpc-tool test rfdiffusion3      (CPU works; GPU is ~100x faster)
#
# Four stages, in increasing order of what they prove:
#   0. both checkpoints exist and deserialise
#   1. which accelerator is about to run, stated out loud
#   2. a 60-residue design from nothing, judged by upstream's own metrics
#   3. the deposited P1B7 covalent bond is PARSED and FLAGGED from 8UDR
#   4. a 120-residue de novo scaffold built around that covalent modification,
#      with the bond still 1.77 A in the output
#
# WHY STAGE 4 IS THE ONE THAT MATTERS. RFdiffusion3 has no syntax for declaring
# a covalent bond -- no `covalent_bonds`, no `bondedAtomPairs`, nothing in
# upstream's input.md. The support is a transform,
# FlagAndReassignCovalentModifications, that runs unconditionally in the
# inference pipeline and works off THE BONDLIST THE PARSER PRODUCED. So the
# bond is whatever was in the input file, and an input file without the
# _struct_conn record yields a FREE ligand, a plausible design, and no warning
# anywhere. That is the same failure that quarantined 1,726 Chai-1 results
# (../covalent-bonds.md), reached by a completely different route, and only
# coordinates catch it. Hence stage 3 asserts the bond went IN and stage 4
# asserts it came OUT.
#
# Production defaults on purpose: num_timesteps stays at upstream's 200. A
# design sampled at 20 steps is a different model output from the one anyone
# runs, and a test that passes only at 20 steps is not testing this tool.
set -eu

: "${FOUNDRY_CHECKPOINT_DIRS:?not set -- run through chpc-tool, which exports it}"
: "${RFD3_CKPT:?not set -- run through chpc-tool, which exports it}"

d="$FOUNDRY_CHECKPOINT_DIRS"
for f in rfd3_latest.ckpt rf3_foundry_01_24_latest_remapped.ckpt; do
    test -s "$d/$f" || {
        echo "missing $d/$f"
        echo "fetch with: tools/rfdiffusion3/fetch-weights.sh"; exit 1; }
done

# ============================================================================
# 0. The checkpoints
# ============================================================================
# Assert on the resolver INFERENCE uses, not on `foundry list-installed`.
# list-installed reports "No checkpoint files found in any checkpoint
# directory" even when FOUNDRY_CHECKPOINT_DIRS is set correctly and the
# files are visible from inside the container -- observed 2026-09-18. It
# resolves by some other route, probably the .env that WRITABLE_TMPFS
# discards. Whatever the reason, it is a reporting command, and a test that
# asserted on it would fail on a perfectly usable installation.
#
# checkpoint_registry.get_default_checkpoint_dirs() is what the engines call:
# it reads FOUNDRY_CHECKPOINT_DIRS, splits on colons, and appends
# ~/.foundry/checkpoints. That is the contract worth testing.
if ! "$CHPC_TOOL" exec rfdiffusion3 -- python - "$d" > res.log 2>&1 <<'PY'
import sys
from pathlib import Path
from foundry.inference_engines.checkpoint_registry import get_default_checkpoint_dirs
want = Path(sys.argv[1]).absolute()
dirs = get_default_checkpoint_dirs()
print("search path:", [str(p) for p in dirs])
assert want in dirs, f"{want} not in the resolver's search path"
print("ok: registry resolves", want)
PY
then
    echo "checkpoint resolution failed:"; tail -20 res.log; exit 1
fi
cat res.log

# Deserialise both checkpoints. A truncated download is still a file and
# still passes `test -s`; torch.load is what distinguishes them, and it is
# the same structural argument as the zip CRC check in the rfdiffusion fetch.
if ! "$CHPC_TOOL" exec rfdiffusion3 -- python - "$d" > load.log 2>&1 <<'PY'
import sys, torch
from pathlib import Path
d = Path(sys.argv[1])
for name in ("rfd3_latest.ckpt", "rf3_foundry_01_24_latest_remapped.ckpt"):
    obj = torch.load(d / name, map_location="cpu", weights_only=False)
    assert isinstance(obj, dict), (name, type(obj))
    # foundry's checkpoints put the weights under 'model', not 'state_dict'
    # or 'model_state_dict'. Measured: the top level is
    #   model (OrderedDict, 1616 keys) / optimizer / scheduler_cfg /
    #   global_step / current_epoch / train_cfg
    # so a chain that only tried the two conventional names fell through to
    # the top-level dict, whose values are an OrderedDict and some ints --
    # none with .numel(), giving a parameter count of exactly 0. Try the
    # names, then verify the one chosen actually holds tensors.
    sd = None
    for key in ("model", "state_dict", "model_state_dict"):
        if isinstance(obj.get(key), dict):
            sd = obj[key]
            break
    assert sd is not None, (name, "no weights dict among", list(obj)[:8])
    # Not every entry is a tensor: 'model.use_rmsnorm' is a bool.
    n = sum(v.numel() for v in sd.values() if hasattr(v, "numel"))
    assert n > 1e7, (name, "parameter count", n)
    print(f"ok {name}: {len(sd)} entries, {n:,} parameters")
PY
then
    echo "checkpoint load failed:"; tail -20 load.log; exit 1
fi
cat load.log

# ============================================================================
# 1. Name the accelerator before using it
# ============================================================================
# rfd3 runs on the CPU perfectly well and says so at ERROR level --
#   "No GPUs/XPUs/MPS available - Setting accelerator to 'cpu'"
# -- then produces a correct design about 100x slower. So the CPU path is not
# a failure and this test does not treat it as one. What it refuses to do is
# leave the log ambiguous: the accelerator is decided here, printed here, and
# named again in the final ok line, so nobody can quote a CPU run as GPU
# coverage.
#
# NEVER read the "GPU information: NVIDIA RTX A6000, ..." line as evidence of
# anything. That is cuequivariance_ops/triton/cache_manager.py falling back to
# default_map["NVIDIA RTX A6000"] when pynvml fails, and PRINTING it. On a CPU
# node with no driver at all it still claims an A6000.
if "$CHPC_TOOL" exec rfdiffusion3 -- python -c \
        'import sys, torch; sys.exit(0 if torch.cuda.is_available() else 1)' \
        > acc.log 2>&1
then
    HAVE_GPU=yes
    "$CHPC_TOOL" exec rfdiffusion3 -- python - <<'PY'
import torch
a = torch.randn(256, 256, device="cuda")   # is_available() lies on an
(a @ a).sum().item()                       # architecture the kernels miss
cc = torch.cuda.get_device_capability()
print("accelerator: CUDA -- %s (sm_%d%d), torch %s cuda %s"
      % (torch.cuda.get_device_name(0), cc[0], cc[1],
         torch.__version__, torch.version.cuda))
PY
else
    HAVE_GPU=no
    echo "accelerator: CPU -- no CUDA device visible."
    echo "  Designs below still run and are still asserted; they take minutes"
    echo "  instead of seconds. For the GPU path:"
    echo "  srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 1:00:00 --pty bash -l"
fi

# ============================================================================
# 2. A design, from nothing
# ============================================================================
# `inputs=null` with a length override is upstream's own smoke invocation
# (docs/input.md). Note the leading `+`: `specification` is an empty dict in
# rfdiffusion3.yaml, so hydra refuses `specification.length=60` with
# "Could not override 'specification.length'" and tells you to append instead.
# Upstream's documentation writes it without the +, and it does not work.
rm -rf uncond
if ! "$CHPC_TOOL" exec rfdiffusion3 -- rfd3 design \
        inputs=null +specification.length=60 out_dir=uncond \
        ckpt_path="$RFD3_CKPT" diffusion_batch_size=1 n_batches=1 \
        > uncond.log 2>&1
then
    echo "unconditional design failed:" >&2; tail -30 uncond.log >&2; exit 1
fi
test -s uncond/_0_model_0.json || {
    echo "no design metadata written; out tree was:"; find uncond -type f; exit 1; }

# Upstream computes its own design metrics and writes them beside every
# structure, so the criteria here are the model authors' and not invented by
# this file. A collapsed or fragmented backbone fails them; a real one does not.
if ! "$CHPC_TOOL" exec rfdiffusion3 -- python - \
        uncond/_0_model_0.json uncond/_0_model_0.cif.gz 60 > uncond_check.log 2>&1 <<'PY'
import gzip, json, math, sys

meta = json.load(open(sys.argv[1]))
m, want = meta["metrics"], int(sys.argv[3])
for k in ("num_residues", "n_chainbreaks", "radius_of_gyration",
          "helix_fraction", "loop_fraction", "max_ca_deviation"):
    assert k in m, (k, sorted(m))
print("num_residues        %s  (asked for %d)" % (m["num_residues"], want))
print("n_chainbreaks       %s" % m["n_chainbreaks"])
print("clashes bb/sc       %s / %s" % (m["n_clashing.interresidue_clashes_w_backbone"],
                                       m["n_clashing.interresidue_clashes_w_sidechain"]))
print("radius_of_gyration  %.2f A" % m["radius_of_gyration"])
print("helix / loop        %.2f / %.2f" % (m["helix_fraction"], m["loop_fraction"]))
print("max_ca_deviation    %.3f A" % m["max_ca_deviation"])

assert m["num_residues"] == want, ("length override ignored", m["num_residues"])
assert m["n_chainbreaks"] == 0, ("chain breaks in a single designed chain",
                                 m["n_chainbreaks"])
assert m["n_clashing.interresidue_clashes_w_backbone"] == 0, m
assert m["n_clashing.interresidue_clashes_w_sidechain"] == 0, m
# A 60-residue globular protein has Rg near 10 A. The band is wide because
# this asserts "compact, not a ribbon and not a dot", not a published number:
# an extended 60mer is ~30 A and a collapsed one under 6 A.
assert 7.0 < m["radius_of_gyration"] < 16.0, ("Rg implausible for 60 residues",
                                              m["radius_of_gyration"])
# max_ca_deviation is upstream's own check that the final coordinates match
# the last denoising step. Sub-angstrom or the sampler did not converge.
assert m["max_ca_deviation"] < 1.0, m["max_ca_deviation"]

# --- and the coordinates, independently of upstream's metrics ---------------
# Everything above came out of the same JSON. This reads the structure.
cols, rows, inloop = [], [], False
for line in gzip.open(sys.argv[2], "rt"):
    s = line.strip()
    if s.startswith("_atom_site."):
        cols.append(s.split(".", 1)[1]); inloop = True
    elif inloop and (s.startswith("ATOM") or s.startswith("HETATM")):
        rows.append(s.split())
ix = {c: i for i, c in enumerate(cols)}
ca = [r for r in rows if r[ix["label_atom_id"]] == "CA"]
assert len(ca) == want, ("CA atoms in the structure", len(ca))
xyz = [tuple(float(r[ix[k]]) for k in ("Cartn_x", "Cartn_y", "Cartn_z")) for r in ca]
steps = [math.dist(a, b) for a, b in zip(xyz, xyz[1:])]
lo, hi = min(steps), max(steps)
print("CA-CA spacing       %.3f - %.3f A over %d bonds" % (lo, hi, len(steps)))
# A trans peptide fixes consecutive CA-CA at 3.80 A. This is the assertion
# that cannot be satisfied by a plausible-looking metrics dict: it is chemistry.
assert 3.7 < lo and hi < 3.95, ("CA-CA spacing is not peptide geometry", lo, hi)
PY
then
    echo "the unconditional design is not a usable protein:" >&2
    tail -25 uncond_check.log >&2; exit 1
fi
sed 's/^/    /' uncond_check.log

# ============================================================================
# 3. The P1B7 covalent bond, going in
# ============================================================================
# 8UDR is sotorasib (CCD MOV) bonded to the KRAS G12C cysteine of a peptide
# presented by HLA-A*03:01. The deposited _struct_conn says C/CYS6/SG to
# F/MOV/C25 at 1.765 A (../../examples/p1b7/manifest.json). Two places to
# find it: the share, where fetch-weights.sh puts it, or a repo checkout.
CIF=""
for c in "$d/8UDR.cif.gz" "$TOOLDIR/../../examples/p1b7/reference/8UDR.cif.gz"; do
    [ -f "$c" ] && { CIF="$c"; break; }
done
[ -n "$CIF" ] || {
    echo "no 8UDR.cif.gz for the covalent stages. Looked in:" >&2
    echo "  $d/8UDR.cif.gz" >&2
    echo "  $TOOLDIR/../../examples/p1b7/reference/8UDR.cif.gz" >&2
    echo "Put it on the share with: tools/rfdiffusion3/fetch-weights.sh --fixture" >&2
    exit 1; }
echo "covalent fixture: $CIF"
gunzip -c "$CIF" > 8UDR.cif

if ! "$CHPC_TOOL" exec rfdiffusion3 -- python - 8UDR.cif > cov_in.log 2>&1 <<'PY'
import sys
import numpy as np
from rfd3.utils.inference import inference_load_
from atomworks.ml.transforms.covalent_modifications import (
    flag_and_reassign_covalent_modifications,
)

aa = inference_load_(sys.argv[1])["atom_array"]
print("parsed %d atoms, chains %s" % (len(aa), sorted(set(aa.chain_id.tolist()))))
assert aa.bonds is not None, "atomworks parsed no BondList -- nothing to flag"
bonds = aa.bonds.as_array()

mov = np.where(aa.res_name == "MOV")[0]
assert len(mov) == 41, ("MOV heavy atoms", len(mov))   # manifest.json says 41
movset = set(mov.tolist())

# Every bond with exactly one end inside the ligand. There must be exactly one:
# a ligand bonded twice, or to the wrong thing, is a different molecule.
cross = [b for b in bonds if (b[0] in movset) != (b[1] in movset)]
assert len(cross) == 1, ("bonds crossing the MOV boundary", len(cross))
i, j = (cross[0][0], cross[0][1]) if cross[0][0] in movset else (cross[0][1], cross[0][0])
dist = float(np.linalg.norm(aa.coord[i] - aa.coord[j]))
print("bond: MOV %s -- %s %s%d %s  %.3f A"
      % (aa.atom_name[i], aa.res_name[j], aa.chain_id[j], aa.res_id[j],
         aa.atom_name[j], dist))
assert aa.atom_name[i] == "C25", ("ligand-side atom", aa.atom_name[i])
assert aa.atom_name[j] == "SG" and aa.res_name[j] == "CYS", (aa.atom_name[j], aa.res_name[j])
assert abs(dist - 1.765) < 0.05, ("deposited distance is 1.765 A", dist)

# --- the transform that is the whole of rfd3's covalent support ------------
before = aa.copy()
aa = flag_and_reassign_covalent_modifications(aa)
cys = (aa.chain_id == before.chain_id[j]) & (aa.res_id == before.res_id[j])
print("flagged %d atoms = %d ligand + %d in the bonded cysteine"
      % (int(aa.is_covalent_modification.sum()), len(mov), int(cys.sum())))
assert aa.is_covalent_modification[mov].all(), "the ligand was not flagged"
assert aa.is_covalent_modification[cys].all(), (
    "the cysteine the ligand is bonded to was not flagged, so rfd3 would treat "
    "the modification as a free ligand sitting near a residue")
# atomize is the consequence that matters: the pair is tokenized per atom
# rather than as a residue plus a blob, which is how the geometry is kept.
assert aa.atomize[mov].all() and aa.atomize[cys].all(), "not marked for atomization"
assert set(aa.pn_unit_iid[cys].tolist()) == set(aa.pn_unit_iid[mov].tolist()), (
    "the cysteine was not reassigned into the ligand's PN unit: %s stayed %s"
    % (set(before.pn_unit_iid[cys].tolist()), set(aa.pn_unit_iid[cys].tolist())))
print("cysteine PN unit reassigned %s -> %s"
      % (set(before.pn_unit_iid[cys].tolist()), set(aa.pn_unit_iid[cys].tolist())))
PY
then
    echo "rfd3 did not read the deposited covalent bond:" >&2
    tail -25 cov_in.log >&2; exit 1
fi
sed 's/^/    /' cov_in.log

# ============================================================================
# 4. And coming out of a design
# ============================================================================
# Scaffold a new 120-residue protein around the modified cysteine and its
# ligand. `unindex` lets the model choose where in the new sequence the
# cysteine lands; both it and the ligand are fixed in space, so if the bond is
# still 1.77 A in the output then the covalent modification survived design.
cat > p1b7-cov.json <<JSON
{
  "p1b7_cov_scaffold": {
    "input": "$PWD/8UDR.cif",
    "ligand": "MOV",
    "unindex": "C6",
    "length": "120-120",
    "select_fixed_atoms": { "C6": "ALL", "MOV": "ALL" }
  }
}
JSON
rm -rf cov
if ! "$CHPC_TOOL" exec rfdiffusion3 -- rfd3 design \
        inputs=p1b7-cov.json out_dir=cov \
        ckpt_path="$RFD3_CKPT" diffusion_batch_size=1 n_batches=1 \
        > cov.log 2>&1
then
    echo "the covalent scaffolding design failed:" >&2; tail -30 cov.log >&2; exit 1
fi
OUT=cov/p1b7-cov_p1b7_cov_scaffold_0_model_0
test -s "$OUT.json" || {
    echo "expected $OUT.json; out tree was:"; find cov -type f; exit 1; }

if ! "$CHPC_TOOL" exec rfdiffusion3 -- python - \
        "$OUT.json" "$OUT.cif.gz" > cov_out.log 2>&1 <<'PY'
import gzip, json, math, sys

m = json.load(open(sys.argv[1]))["metrics"]
print("num_residues        %s" % m["num_residues"])
print("ligand clashes      %s   (min distance %.2f A)"
      % (m["n_clashing.ligand_clashes"], m["n_clashing.ligand_min_distance"]))
print("insertion_rmsd      %.3f A" % m["insertion_rmsd"])
assert m["num_residues"] == 120, m["num_residues"]
assert m["n_chainbreaks"] == 0, m["n_chainbreaks"]
# A scaffold that solved the problem by moving away from the ligand is not a
# binding pocket. A scaffold that solved it by overlapping the ligand is not a
# structure. Both are excluded.
assert m["n_clashing.ligand_clashes"] == 0, m["n_clashing.ligand_clashes"]
assert m["n_clashing.ligand_min_distance"] < 6.0, (
    "nothing in the design comes within 6 A of the ligand", 
    m["n_clashing.ligand_min_distance"])
# Upstream's own measure of how well the fixed motif was reproduced.
assert m["insertion_rmsd"] < 2.0, ("the motif was not held", m["insertion_rmsd"])

# --- THE ASSERTION THIS FILE EXISTS FOR ------------------------------------
cols, rows, inloop = [], [], False
for line in gzip.open(sys.argv[2], "rt"):
    s = line.strip()
    if s.startswith("_atom_site."):
        cols.append(s.split(".", 1)[1]); inloop = True
    elif inloop and (s.startswith("ATOM") or s.startswith("HETATM")):
        rows.append(s.split())
ix = {c: i for i, c in enumerate(cols)}
def at(r, k): return r[ix[k]]
def xyz(r): return tuple(float(at(r, c)) for c in ("Cartn_x", "Cartn_y", "Cartn_z"))

mov = [r for r in rows if at(r, "label_comp_id") == "MOV"]
assert len(mov) == 41, ("MOV atoms in the output", len(mov))
c25 = [r for r in mov if at(r, "label_atom_id") == "C25"]
assert len(c25) == 1, ("C25 in the output", len(c25))
sg = [r for r in rows if at(r, "label_atom_id") == "SG"]
assert sg, "the output has no SG at all -- the cysteine was not carried over"

# 1. Nearest SG to the warhead carbon is at bonding distance.
dist, near = min((math.dist(xyz(c25[0]), xyz(s)), s) for s in sg)
print("MOV C25 -- nearest SG  %.3f A  (%s %s%s)"
      % (dist, at(near, "label_comp_id"), at(near, "label_asym_id"),
         at(near, "label_seq_id")))
assert at(near, "label_comp_id") == "CYS", at(near, "label_comp_id")
assert abs(dist - 1.765) < 0.10, (
    "the covalent bond did not survive the design: %.3f A against the "
    "deposited 1.765 A. Both the ligand and the cysteine were declared fixed, "
    "so this distance should not have moved at all." % dist)

# 2. And C25 is the ligand atom it is bonded to, not merely a nearby one.
#    This is the check that separates the right attachment from a warhead
#    pointing 13 A away while an aromatic carbon sits at 1.7 (../covalent-bonds.md).
order = sorted((math.dist(xyz(near), xyz(m)), at(m, "label_atom_id")) for m in mov)
print("ligand atoms nearest that SG: " + ", ".join("%s %.2f" % (n, x) for x, n in order[:3]))
assert order[0][1] == "C25", (
    "the ligand atom closest to the cysteine sulfur is %s at %.3f A, not C25"
    % (order[0][1], order[0][0]))
assert order[1][0] > 2.2, (
    "a second ligand atom is also at bonding distance (%s, %.3f A)"
    % (order[1][1], order[1][0]))
print("chains in the output: %s" % sorted({at(r, "label_asym_id") for r in rows}))
PY
then
    echo "the covalent modification did not survive the design:" >&2
    tail -30 cov_out.log >&2; exit 1
fi
sed 's/^/    /' cov_out.log

# ============================================================================
# The accelerator claim, settled against the logs
# ============================================================================
# If a CUDA device was visible, neither design is allowed to have fallen back.
if [ "$HAVE_GPU" = yes ]; then
    if grep -q "Setting accelerator to 'cpu'" uncond.log cov.log; then
        echo "a CUDA device is visible but rfd3 ran on the CPU anyway:" >&2
        grep -n "Setting accelerator" uncond.log cov.log >&2
        exit 1
    fi
    echo "ok: both designs ran on CUDA (no accelerator fallback in either log)"
    RAN=CUDA
else
    RAN=CPU
fi

echo
echo "ok: RFdiffusion3 designed a 60-residue backbone with peptide CA-CA"
echo "    geometry and no clashes, then built a 120-residue de novo scaffold"
echo "    around the P1B7 sotorasib-modified cysteine from 8UDR -- with the"
echo "    MOV C25 to CYS SG bond still at bonding distance in the output, and"
echo "    C25 still the attached atom. Ran on: $RAN."
echo
echo "    rfd3 has NO way to declare a covalent bond. It reads the bonds in"
echo "    your input file. Strip the _struct_conn record and you get a free"
echo "    ligand, a plausible design, and no warning -- see ../covalent-bonds.md."
