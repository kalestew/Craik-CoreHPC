#!/bin/sh
# RFD4-Proteina self-test: it loads, it composes two conditions in one input,
# it designs, and it holds a covalent bond.
# Run:  chpc-tool test rfd4-proteina
#
# Five stages, in increasing order of what they prove:
#   0. the model bundle deserialises and is the flow model
#   1. CUDA is present -- ASSERTED, not reported (see below)
#   2. a CDR-redesign condition and a covalent hapten condition compose in ONE
#      condition spec, over real 8UDR coordinates. No GPU, no weights.
#   3. a real generation at production step count
#   4. the hapten comes back ON the peptide cysteine it was declared bonded to
#
# WHY STAGE 1 ASSERTS RATHER THAN REPORTS, which is a difference from
# rfdiffusion3's test in this same registry. rfd3 runs on a CPU perfectly well,
# just slowly, so its test names the accelerator and carries on. RFD4 cannot:
# generate.py:707 is `L.Trainer(accelerator="gpu")` as a LITERAL, and
# `hardware.accelerator` is read only by train.py. So a CPU host here is not a
# slow success, it is a Lightning traceback, and a test that treated it as a
# skip would report "not checked" for the only thing stages 3 and 4 do.
#
# RFD4_TEST_CPU_ONLY=1 runs stages 0 and 2 and nothing else. That combination is
# genuinely useful -- stage 2 is where an input is validated and it needs
# neither a GPU nor the 1.7 GB bundle, and the CPU image is 817 MB against the
# cu13 image's 4.04 GB -- but it is NOT this entry's verification, and the final
# line says so rather than exiting 0 quietly.
#
# PRODUCTION DEFAULTS ON PURPOSE. nsteps stays at upstream's 60. A design
# sampled at 20 steps is a different model output from the one anyone runs, and
# a test that passes only at 20 steps is not testing this tool.
set -eu

: "${RFD4_BUNDLE:?not set -- run through chpc-tool, which exports it}"
: "${DATA_PATH:?not set -- run through chpc-tool, which exports it}"

# atomworks prints a six-line preamble about unset CCD_MIRROR_PATH and
# PDB_MIRROR_PATH on every import, plus "Field ... not found in file" notices
# for the conditioning annotations a deposited CIF naturally lacks. All benign,
# all unavoidable, and together they bury the lines that matter.
#
# The CCD_MIRROR_PATH warning is EXPECTED here and is not a gap to close: this
# entry deliberately exports no mirror, because atomworks treats a configured
# one as the only source of components and a partial mirror therefore makes
# every amino acid unknown. Measured in this image: a MOV-only mirror leaves 1
# standard CCD code and makes ALA raise, against 49195 with no mirror at all.
quiet() {
    grep -v -e 'Environment variable .* not set' \
            -e '^  ([0-9])' \
            -e '^To set it you may' \
            -e '^Will not be able to use' \
            -e 'WARNING:atomworks.io:Field .* not found in file, ignoring' \
            -e "WARNING:atomworks.io:We can't fix formal charges" \
            -e "matches neither standard nor alternative CCD names" \
            -e 'INFO:    Cleanup error: while stopping driver' \
            -e 'INFO:    gocryptfs not found' \
            "$1" || true
}

for f in config.json model.safetensors; do
    test -s "$RFD4_BUNDLE/$f" || {
        echo "missing $RFD4_BUNDLE/$f"
        echo "fetch with: tools/rfd4-proteina/fetch-weights.sh"; exit 1; }
done

# 8UDR and the manifest: on the share where fetch-weights.sh puts them, or in a
# repo checkout. Both stages 2 and 4 need them.
CIF="" MANIFEST=""
for c in "$DATA_PATH/8UDR.cif.gz" "$TOOLDIR/../../examples/p1b7/reference/8UDR.cif.gz"; do
    [ -f "$c" ] && { CIF="$c"; break; }
done
for m in "$DATA_PATH/manifest.json" "$TOOLDIR/../../examples/p1b7/manifest.json"; do
    [ -f "$m" ] && { MANIFEST="$m"; break; }
done
[ -n "$CIF" ] && [ -n "$MANIFEST" ] || {
    echo "no 8UDR.cif.gz and/or manifest.json for the covalent stages. Looked in:" >&2
    echo "  $DATA_PATH/" >&2
    echo "  $TOOLDIR/../../examples/p1b7/" >&2
    echo "Put them on the share with: tools/rfd4-proteina/fetch-weights.sh --fixture" >&2
    exit 1; }
echo "covalent fixture: $CIF"
echo "sequence source:  $MANIFEST"
gunzip -c "$CIF" > 8UDR.cif
cp "$MANIFEST" manifest.json

# ============================================================================
# 0. The model bundle
# ============================================================================
# The LOCAL-DIRECTORY route, asserted as such. utils/hub.py short-circuits
# snapshot_download when hf_ckpt_path names a directory, reads config.json plus
# model.safetensors, and forces autoencoder_ckpt_path=None because the bundle
# carries the autoencoder config inside it. That short-circuit is the whole
# reason this entry stages two files instead of two multi-gigabyte .ckpt files,
# and it is only verifiable with the network OFF -- with egress, a path that is
# not a directory falls through to the Hub and succeeds for the wrong reason.
# HF_HUB_OFFLINE=1 (from tool_exports) is what makes this an assertion.
if ! "$CHPC_TOOL" exec rfd4-proteina -- python - "$RFD4_BUNDLE" > bundle.log 2>&1 <<'PY'
import sys
from pathlib import Path

import torch
from safetensors import safe_open

b = Path(sys.argv[1])
assert b.is_dir(), f"{b} is not a directory -- the bundle route needs one"

# Count parameters from the file itself before asking the model to load, so a
# truncated download is distinguished from a model that will not construct.
with safe_open(b / "model.safetensors", framework="pt", device="cpu") as fh:
    keys = list(fh.keys())
    total = 0
    for k in keys:
        shape = fh.get_slice(k).get_shape()
        n = 1
        for d in shape:
            n *= d
        total += n
print(f"safetensors: {len(keys)} tensors, {total:,} parameters")
assert total > 1e7, ("parameter count too small to be the flow model", total)

from rfproteina.utils.hub import load_pretrained_bundle

out = load_pretrained_bundle(str(b))
print("load_pretrained_bundle returned:", type(out).__name__)
# It forces the autoencoder path to None precisely because the bundle carries
# the AE config. Upstream warns the flow model and the autoencoder "must be
# used together" and are not interchangeable across releases, so a route that
# quietly paired this flow model with a separately staged AE checkpoint is the
# failure worth excluding by construction.
if isinstance(out, (tuple, list)):
    print("  elements:", [type(o).__name__ for o in out])
print("torch", torch.__version__, "cuda", torch.version.cuda)
PY
then
    echo "the model bundle did not load:" >&2; tail -25 bundle.log >&2; exit 1
fi
quiet bundle.log | sed 's/^/    /'

# ============================================================================
# 1. CUDA, asserted
# ============================================================================
# NEVER read a "GPU information: NVIDIA RTX A6000" line as evidence of
# anything. That is cuequivariance_ops' cache manager falling back to a default
# map when pynvml fails, and printing it; on a CPU node with no driver at all it
# still claims an A6000. The matmul below is the evidence: is_available() lies
# on an architecture whose kernels the build is missing.
HAVE_GPU=no
if "$CHPC_TOOL" exec rfd4-proteina -- python -c \
        'import sys, torch; sys.exit(0 if torch.cuda.is_available() else 1)' \
        > acc.log 2>&1
then
    if "$CHPC_TOOL" exec rfd4-proteina -- python - > arch.log 2>&1 <<'PY'
import torch
a = torch.randn(256, 256, device="cuda")
(a @ a).sum().item()
cc = torch.cuda.get_device_capability()
print("accelerator: CUDA -- %s (sm_%d%d), torch %s cuda %s"
      % (torch.cuda.get_device_name(0), cc[0], cc[1],
         torch.__version__, torch.version.cuda))
# GPU_MAX_CC is filled from THIS, not from torch.cuda.get_arch_list(): the
# rfdiffusion3 entry records one image answering the latter with an empty list
# while this answered correctly.
print("arch flags:  %s" % torch._C._cuda_getArchFlags())
PY
    then
        HAVE_GPU=yes
        cat arch.log
    else
        echo "torch.cuda.is_available() is true but a 256x256 matmul failed:" >&2
        tail -15 arch.log >&2
        echo "That is a kernel/architecture mismatch, not a missing device." >&2
        echo "Record the ceiling in GPU_MAX_CC and rebuild against this device's cc." >&2
        exit 1
    fi
fi

if [ "$HAVE_GPU" = no ]; then
    if [ "${RFD4_TEST_CPU_ONLY:-0}" = "1" ]; then
        echo "accelerator: CPU -- RFD4_TEST_CPU_ONLY=1, stages 3 and 4 will be SKIPPED."
    else
        echo "no CUDA device is visible, and rfd4-generate cannot run without one." >&2
        echo "  generate.py:707 is L.Trainer(accelerator='gpu') as a literal, and" >&2
        echo "  hardware.accelerator is read only by train.py -- so this is a" >&2
        echo "  traceback rather than a slow run. There is no CPU fallback to take." >&2
        echo >&2
        echo "  For the GPU path:" >&2
        echo "    srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 1:00:00 --pty bash -l" >&2
        echo "  To exercise only what runs without one (stages 0 and 2):" >&2
        echo "    RFD4_TEST_CPU_ONLY=1 chpc-tool test rfd4-proteina" >&2
        exit 1
    fi
fi

# ============================================================================
# 2. The composition question -- the stage this entry exists to answer
# ============================================================================
# The consuming project's ADR 0026 names exactly one claim no primary source
# states: whether a CDR redesign condition and a covalent hapten condition
# compose in a SINGLE run. Upstream documents the two modes separately and never
# together. This asks the layer that would REJECT the composition --
# build_annotated_atom_array_from_condition_spec -- which is CPU-only, needs no
# weights and no network, and is where an input is validated.
#
# Five things it has to get right, every one a silent failure rather than an
# error, and all five are requirements on any renderer for this tool:
#
#  (1) input_as_annotated_cif MUST be true. With false, the RCSB_WITH_METALS
#      preset's add_missing_atoms re-adds 31 NaN-coordinate hydrogens to the
#      hapten -- 72 ligand atoms instead of 41, 209 non-finite overall. (The
#      hydrogens come from the CCD template, which carries 73 atoms for MOV.)
#  (2) A C_CRDGRP group may NOT span the designed region.
#      materialize_internal_coords requires each group's live coordinates to be
#      entirely finite and a free CDR has none. It fails with "Coordinate group
#      2 needs finite live coordinates to materialize its targets", naming
#      neither the CDR nor the cause.
#  (3) The input must carry no non-finite coordinates in any conditioned group,
#      which deposited structures routinely do -- 8UDR has unresolved
#      heavy-chain backbone at 141-145 and 223-226 plus a non-finite atom at
#      every chain terminus. Cropping and dropping them is the renderer's job,
#      and the crop below is the prototype of it.
#  (4) C_SEQ's FREE value is the string '<M>' -- a residue-level str annotation
#      whose default_value is that mask token, not False, not "", not absence.
#      A check asserting falsiness reports every designed residue as
#      conditioned and passes nothing.
#  (5) The built annotation names are not the spec aliases: C_SEQ / C_CRD /
#      C_CRDGRP become condition_sequence_1_residue /
#      condition_coordinate_1_atom / condition_CoordinateGroup_1_atom.
#      C_INTCRD is never writable -- condition_spec.py:378 refuses it by name.
if ! "$CHPC_TOOL" exec rfd4-proteina -- python - 8UDR.cif manifest.json > compose.log 2>&1 <<'PY'
import json
import sys

import numpy as np
from atomworks.io.utils.io_utils import to_cif_file
from biotite.sequence import ProteinSequence
from biotite.structure import get_residue_starts
from rfproteina.inference_utils.condition_spec import (
    build_annotated_atom_array_from_condition_spec,
    load_condition_spec_inputs,
)

SRC, MANIFEST = sys.argv[1], sys.argv[2]

# Chains as atomworks parses 8UDR (label asym ids). MHC alpha, b2m and peptide
# are the target; D/E are the Fab; F is sotorasib.
MHC, B2M, PEPTIDE, HEAVY, LIGHT, LIGAND = "A", "B", "C", "D", "E", "F"
TARGET = [MHC, B2M, PEPTIDE]
VH_N, VL_N = 123, 110          # the Fv, i.e. the part the pool's sequences cover

# The two CDR3 loops, as 1-based res_id spans on the deposited chains. Declared
# here and CHECKSUMMED below against the manifest's own Fab sequences, which is
# the assertion that catches an off-by-one: a hand calculation using VL=109 put
# all four heavy-chain loops one residue high, and nothing about the resulting
# run would have looked wrong.
CDR3A = (89, 99)               # light chain
CDR3B = (101, 112)             # heavy chain

manifest = json.load(open(MANIFEST))
seqs = {c["chain"]: c["sequence"] for c in manifest["chains"]}
bond = manifest["bond"]
lig = manifest["ligand"]
failures = []


def one_letter(sub):
    starts = get_residue_starts(sub, add_exclusive_stop=True)
    out = []
    for name in sub.res_name[starts[:-1]]:
        try:
            out.append(ProteinSequence.convert_letter_3to1(name))
        except KeyError:
            out.append("X")
    return "".join(out), sub.res_id[starts[:-1]]


# --- crop: Fv + target + hapten, dropping non-finite atoms ------------------
# This is finding (3), and it is the renderer's job rather than the tool's.
raw = load_condition_spec_inputs([SRC], as_annotated_cif=False)
keep = (
    np.isin(raw.chain_id, TARGET + [LIGAND])
    | ((raw.chain_id == HEAVY) & (raw.res_id <= VH_N))
    | ((raw.chain_id == LIGHT) & (raw.res_id <= VL_N))
)
finite = np.isfinite(raw.coord).all(axis=1)
sub = raw[keep & finite]
print(f"  cropped {raw.array_length()} -> {sub.array_length()} atoms "
      f"(dropped {int((keep & ~finite).sum())} non-finite inside the crop)")
to_cif_file(sub, "cropped.cif", include_entity_categories=False,
            author="chpc-tool", date="2026-01-01")

# --- the annotated-CIF route, which is finding (1) --------------------------
arr = load_condition_spec_inputs(["cropped.cif"], as_annotated_cif=True)
nlig = int((arr.chain_id == LIGAND).sum())
nnf = int((~np.isfinite(arr.coord).all(axis=1)).sum())
print(f"  annotated CIF: {nlig} ligand atoms, {nnf} non-finite")
if nlig != lig["heavy_atoms"]:
    failures.append(
        f"{nlig} ligand atoms, manifest says {lig['heavy_atoms']} heavy atoms. With "
        "input_as_annotated_cif=false the RCSB preset re-adds NaN hydrogens from the "
        "CCD template; this is that failure, or the crop lost atoms."
    )
if nnf:
    failures.append(f"{nnf} non-finite coordinates survived the crop")

# --- the checksum: do the declared spans hold the sequences they should? ----
for chain, n, label, span, flat in (
    (LIGHT, VL_N, "light", CDR3A, 0),
    (HEAVY, VH_N, "heavy", CDR3B, 0),
):
    text, ids = one_letter(arr[arr.chain_id == chain])
    want_chain = seqs[chain][:n]
    if not text.startswith(want_chain):
        off = next((i for i in range(min(len(text), n)) if text[i] != want_chain[i]), None)
        failures.append(
            f"chain {chain} does not start with the manifest's {label} chain; "
            f"first difference at offset {off}"
        )
        continue
    got = text[span[0] - 1: span[1]]
    want = want_chain[span[0] - 1: span[1]]
    if got != want:
        failures.append(f"chain {chain} {span[0]}-{span[1]} is {got!r}, manifest says {want!r}")
    else:
        print(f"  OK chain {chain} 1-{n} == manifest {label} chain; "
              f"{span[0]}-{span[1]} == {got!r}")

free_l = f"(chain_id == '{LIGHT}' and res_id >= {CDR3A[0]} and res_id <= {CDR3A[1]})"
free_h = f"(chain_id == '{HEAVY}' and res_id >= {CDR3B[0]} and res_id <= {CDR3B[1]})"
free = f"({free_l} or {free_h})"
fv = f"chain_id in ['{LIGHT}', '{HEAVY}']"

# Selections are PYTHON BOOLEAN EXPRESSIONS over per-atom annotations
# (utils/mask_spec.py:resolve_mask) -- there is no structured combinator syntax
# -- they resolve against PRE-CONTIG res_id, and values apply in DECLARATION
# ORDER with last write winning. Hence a fixed, documented order here.
spec = {
    "input": "cropped.cif",
    "input_as_annotated_cif": True,          # finding (1)
    "conditions": {
        # target sequence held; framework and every non-designed CDR held
        "C_SEQ": {True: [{"select": "chain_id in " + repr(TARGET)},
                         {"select": f"{fv} and not {free}"}]},
        # Target COORDINATES held, WITH THE LIGAND CHAIN NAMED EXPLICITLY.
        # Copying the Ig task's p_target_bb_only branch literally would gate on
        # is_protein_backbone, and a ligand atom never is -- leaving the hapten
        # unconditioned. That is not a cosmetic miss: metrics/hotspots.py:81
        # defines "binder" as ~current_chain & ~coordinate_conditioned, so an
        # unconditioned hapten COUNTS AS BINDER and satisfies MHC hotspots by
        # itself, making a steering reward read high for a design that touches
        # nothing.
        "C_CRD": {True: [{"select": "chain_id in " + repr(TARGET + [LIGAND])}]},
        # Framework as two independent rigid bodies, FRAMEWORK ONLY -- finding (2).
        "C_CRDGRP": {
            1: [{"select": f"chain_id == '{LIGHT}' and not {free}"}],
            2: [{"select": f"chain_id == '{HEAVY}' and not {free}"}],
        },
    },
}

built = build_annotated_atom_array_from_condition_spec(
    spec, spec_dir=".", example_id="compose_check", strict=True, validate=True
)
out = built["atom_array"] if isinstance(built, dict) else built
if isinstance(built, dict):
    print("  returned keys:", sorted(built))
cats = set(out.get_annotation_categories())

# --- 1. the covalent bond survived composition -----------------------------
inter = []
if out.bonds is not None:
    for i, j, t in out.bonds.as_array():
        if out.chain_id[i] != out.chain_id[j]:
            d = float(np.linalg.norm(out.coord[i] - out.coord[j]))
            inter.append((i, j, t, d))
if len(inter) != 1:
    failures.append(f"expected exactly one inter-chain bond, got {len(inter)}")
else:
    i, j, t, d = inter[0]
    print(f"  bond: {out.chain_id[i]}/{out.res_name[i]}{out.res_id[i]}/{out.atom_name[i]} -- "
          f"{out.chain_id[j]}/{out.res_name[j]}{out.res_id[j]}/{out.atom_name[j]} "
          f"type={t} d={d:.3f}A")
    names = {out.atom_name[i], out.atom_name[j]}
    if names != {bond["atom"], lig["ccd_attachment"]}:
        failures.append(
            f"the surviving bond is {sorted(names)}, not the declared "
            f"{sorted([bond['atom'], lig['ccd_attachment']])}"
        )
    if abs(d - bond["reference_distance_angstrom"]) > 0.05:
        failures.append(
            f"bond length {d:.3f}A against the deposited "
            f"{bond['reference_distance_angstrom']}A -- composition moved it"
        )

# --- 2. the hapten is coordinate-conditioned (the hotspot-binder trap) -----
crd = None
for cand in ("condition_coordinate_1_atom", "C_CRD"):   # finding (5)
    if cand in cats:
        rawm = np.asarray(out.get_annotation(cand))
        # C_CRD carries xyz per atom, NaN where unset -- not a boolean.
        crd = np.isfinite(rawm).all(axis=1) if rawm.ndim == 2 else rawm.astype(bool)
        print(f"  coordinate mask read from {cand!r}")
        break
if crd is None:
    failures.append(f"no coordinate-conditioning annotation; have {sorted(cats)}")
else:
    ligm = out.chain_id == LIGAND
    if not crd[ligm].all():
        failures.append(f"hapten NOT fully coordinate-conditioned: "
                        f"{int(crd[ligm].sum())}/{int(ligm.sum())}")
    else:
        print(f"  OK all {int(ligm.sum())} hapten atoms are coordinate-conditioned")

# --- 3. designed CDRs are sequence-FREE, framework is conditioned ----------
seqm = None
for cand in ("condition_sequence_1_residue", "C_SEQ"):  # finding (5)
    if cand in cats:
        vals = np.asarray(out.get_annotation(cand))
        seqm = vals != "<M>"                            # finding (4)
        print(f"  sequence mask read from {cand!r} (masked={int((~seqm).sum())} atoms)")
        break
if seqm is None:
    failures.append(f"no sequence-conditioning annotation; have {sorted(cats)}")
else:
    designed = (
        ((out.chain_id == LIGHT) & (out.res_id >= CDR3A[0]) & (out.res_id <= CDR3A[1]))
        | ((out.chain_id == HEAVY) & (out.res_id >= CDR3B[0]) & (out.res_id <= CDR3B[1]))
    )
    fwk = ((out.chain_id == LIGHT) | (out.chain_id == HEAVY)) & ~designed
    if seqm[designed].any():
        failures.append(f"{int(seqm[designed].sum())} designed CDR atoms are "
                        "sequence-conditioned and should be free")
    else:
        print(f"  OK all {int(designed.sum())} designed CDR atoms are sequence-FREE")
    if not seqm[fwk].all():
        failures.append(f"framework not fully sequence-conditioned: "
                        f"{int(seqm[fwk].sum())}/{int(fwk.sum())}")
    else:
        print(f"  OK all {int(fwk.sum())} framework/other-CDR atoms are conditioned")

# --- 4. C_INTCRD is refused by name, so nothing writes it by accident ------
try:
    build_annotated_atom_array_from_condition_spec(
        {"input": "cropped.cif", "input_as_annotated_cif": True,
         "conditions": {"C_INTCRD": {True: [{"select": fv}]}}},
        spec_dir=".", example_id="intcrd_check", strict=True, validate=True,
    )
    failures.append("C_INTCRD was ACCEPTED; upstream is documented to refuse it by name")
except Exception as exc:
    print(f"  OK C_INTCRD refused by name: {type(exc).__name__}")

if failures:
    print("\nCOMPOSITION FAILED:")
    for f in failures:
        print("  -", f)
    sys.exit(1)
print("\nok: CDR redesign conditioning and a covalent hapten bond compose in one spec")
PY
then
    echo "the two conditions do not compose:" >&2
    quiet compose.log | tail -30 >&2; exit 1
fi
quiet compose.log | sed 's/^/    /'

if [ "$HAVE_GPU" = no ]; then
    echo
    echo "PARTIAL: stages 0 and 2 passed on the CPU. Stages 3 and 4 did not run."
    echo "  This is NOT verification of this entry. rfd4-generate cannot run"
    echo "  without CUDA, so nothing here has generated a design or shown that"
    echo "  the hapten comes back attached. Do not set STATUS=verified from this."
    exit 0
fi

# ============================================================================
# 3. A real generation
# ============================================================================
# `inference_experiment=quickstart` is upstream's own first-run preset and is
# the right shape here for a reason worth stating: it does NOT compose the
# `metrics` group at all, so no refolding oracle and no metric dependency is
# reachable. The consuming project rules out AlphaFold2/AlphaFold3/OpenFold3 as
# a second scoring path outside its own objective versioning, and this is that
# exclusion enforced by config rather than remembered.
#
# `metrics_tags=[antibody]` would SILENTLY ENABLE ALPHAFOLD-3: the antibody tag
# gates both inline_metrics/antibody_metrics.yaml's antibody_contacts and
# refolding_oracles/af3.yaml's oracle_ppi. quickstart leaves metrics_tags empty
# and this test never sets it.
#
# skip_existing=false is NOT tidiness. It defaults TRUE, and generate.py:548
# routes existing outputs to an eval-from-disk path -- so a re-run into a
# populated out_dir republishes the previous run's structures as its own. The
# out tree is removed below as well, because the two guards fail differently:
# one covers a stale structure, the other a stale results CSV.
rm -rf gen
if ! "$CHPC_TOOL" exec rfd4-proteina -- rfd4-generate \
        inference_experiment=quickstart \
        inputs="$PWD/cropped.cif" \
        out_dir="$PWD/gen" \
        hf_ckpt_path="$RFD4_BUNDLE" \
        seed=1 \
        skip_existing=false \
        num_replicates=1 \
        batch_size=1 \
        generation.args.nsteps=60 \
        > gen.log 2>&1
then
    echo "generation failed:" >&2; tail -40 gen.log >&2; exit 1
fi

# `cfg.seed = base_seed + job_id` (generate.py:640) with job_id defaulting to 0,
# so a declared seed of 1 must appear as 1. Asserted because this is the
# property a reproducible draw rests on, and the consuming project plans one
# draw per invocation precisely so that the resolved seed and the identity agree.
grep -q "Seeding everything to seed 1" gen.log || {
    echo "the resolved seed is not 1 -- base_seed + job_id did not behave as read:" >&2
    grep -n "seed" gen.log | head -5 >&2; exit 1; }
echo "    resolved seed: 1 (base 1 + job_id 0)"

OUT=$(find gen/inference_samples -name '*_generated.cif' | head -1)
[ -n "$OUT" ] || {
    echo "no *_generated.cif under gen/inference_samples; out tree was:" >&2
    find gen -type f | head -20 >&2; exit 1; }
echo "    wrote $OUT"

# ============================================================================
# 4. And the hapten came back ATTACHED
# ============================================================================
# THE ASSERTION THIS FILE EXISTS FOR, and the one upstream's own documentation
# says cannot be assumed: its conditions are soft -- "not hard output
# constraints, check adherence when exclusions matter" -- so a declared bond is
# a REQUEST. The consuming project has met the other side of this twice: 18 of
# its own structures have the hapten off the declared residue, and a good RF3
# fold and a bad one sit in the same array job with byte-identical covalent_bond
# blocks. ipTM moved 0.710 -> 0.698 between a right and a wrong attachment, so
# confidence does not detect it and only coordinates do.
#
# GATE ON PLACEMENT, NOT ON BOND LENGTH. A flow model producing a strained
# covalent bond is an expected artefact: record the geometry and carry on. What
# must not happen is the adduct sitting tens of angstrom from the residue it is
# declared bonded to. Hence 5.0 A here, with the deposited 1.765 A printed
# beside it as the reference rather than as the threshold.
if ! "$CHPC_TOOL" exec rfd4-proteina -- python - "$OUT" manifest.json > cov.log 2>&1 <<'PY'
import json
import sys

import numpy as np
from atomworks.io import parse

PLACEMENT_CEILING_A = 5.0

out, manifest = sys.argv[1], json.load(open(sys.argv[2]))
lig, bond = manifest["ligand"], manifest["bond"]
deposited = bond["reference_distance_angstrom"]

# atomworks.io.parse returns a DICT of assemblies/asym_unit/chain_info/..., and
# `asym_unit` is an AtomArrayStack rather than an AtomArray -- so `["atom_array"]`
# is a KeyError and a bare stack is an IndexError two calls later. Measured
# 2026-11-17; the keys are
# ['assemblies', 'asym_unit', 'chain_info', 'extra_info', 'ligand_info', 'metadata'].
# Note this is also a DIFFERENT parse from the composition stage's
# `load_condition_spec_inputs(as_annotated_cif=True)`: on the same file the
# default preset gave 9698 atoms against 9497, because add_missing_atoms re-adds
# what finding (1) is about. For a placement check that does not matter -- the
# added atoms are hydrogens with no coordinates -- but do not compare the two
# counts and conclude something moved.
parsed = parse(out)
aa = parsed["asym_unit"]
if hasattr(aa, "stack_depth"):
    aa = aa[0]
print("chains in the output:", sorted(set(aa.chain_id.tolist())))

# Whether the hapten's atoms come back AT ALL is the first open question: the
# generated array merges atom37 for indexed tokens with preserved unindexed
# atoms, and that an atomized non-polymer survives is not established from
# reading the code. If it does not, there is nothing to measure and saying so
# is the result.
ligm = aa.res_name == lig["ccd"]
print(f"{lig['ccd']} atoms in the output: {int(ligm.sum())} "
      f"(input had {lig['heavy_atoms']})")
assert ligm.sum() > 0, (
    f"the output contains no {lig['ccd']} atoms at all. The hapten did not "
    "survive generation, so nothing downstream can gate on its placement."
)

# Select by ATOM NAME and CHAIN, never by component name alone for the sulfur:
# the peptide cysteine is an ordinary CYS and there may be others.
sg = np.where((aa.atom_name == bond["atom"]) & (aa.res_name == "CYS"))[0]
assert len(sg), f"no CYS {bond['atom']} in the output -- the cysteine was not carried over"

warhead = np.where(ligm & (aa.atom_name == lig["ccd_attachment"]))[0]
assert len(warhead) == 1, (
    f"{len(warhead)} atoms named {lig['ccd_attachment']} in the ligand, expected 1"
)
w = warhead[0]

d = np.linalg.norm(aa.coord[sg] - aa.coord[w], axis=1)
best = int(np.argmin(d))
sep = float(d[best])
print(f"{lig['ccd']} {lig['ccd_attachment']} -- nearest CYS {bond['atom']}: {sep:.3f} A"
      f"   (8UDR deposited: {deposited} A)")

# And the warhead is the ligand atom nearest that sulfur, not merely a nearby
# one. This is the check that separates the right attachment from a warhead
# pointing 13 A away while an aromatic carbon sits at 1.68 -- which is the
# bug that quarantined 1,726 Chai-1 results. See ../covalent-bonds.md.
s = sg[best]
order = sorted(
    (float(np.linalg.norm(aa.coord[s] - aa.coord[k])), str(aa.atom_name[k]))
    for k in np.where(ligm)[0]
)
print("ligand atoms nearest that sulfur: "
      + ", ".join(f"{n} {x:.2f}" for x, n in order[:3]))

assert sep <= PLACEMENT_CEILING_A, (
    f"the hapten is {sep:.3f} A from the cysteine it was declared bonded to, past "
    f"the {PLACEMENT_CEILING_A} A placement ceiling. That is a DETACHED hapten, not "
    "a strained bond: the condition was declared and the model did not honour it."
)
assert order[0][1] == lig["ccd_attachment"], (
    f"the ligand atom closest to the sulfur is {order[0][1]} at {order[0][0]:.3f} A, "
    f"not the warhead {lig['ccd_attachment']}. The adduct is near the right residue "
    "by the wrong atom, which is the 2026 contamination exactly."
)
if abs(sep - deposited) > 0.5:
    print(f"note: {sep:.3f} A is {sep - deposited:+.3f} A from the deposited length. "
          "Strain is expected and recorded as data; placement is what gates.")
print("ok: the hapten came back on the declared residue, by the declared atom")
PY
then
    echo "the hapten did not come back attached:" >&2
    quiet cov.log | tail -30 >&2; exit 1
fi
quiet cov.log | sed 's/^/    /'

echo
echo "ok: RFD4-Proteina loaded from a local bundle with the network off, composed"
echo "    a CDR-redesign condition and a covalent hapten condition in ONE spec"
echo "    over real 8UDR coordinates, generated a design at 60 steps from seed 1,"
echo "    and brought the sotorasib adduct back on the peptide cysteine by its"
echo "    warhead atom. Ran on: CUDA."
echo
echo "    Its conditions are SOFT by upstream's own account. This run says they"
echo "    were honoured once, on one draw, for this input -- not that they will"
echo "    be. A caller must gate on the output's geometry every time; see"
echo "    ../covalent-bonds.md and tool.conf's NOTE."
