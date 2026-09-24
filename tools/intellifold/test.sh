#!/bin/sh
# IntelliFold self-test: fold a peptide, then fold a BONDED complex and prove
# the bond is where it was asked for.
# Run:  chpc-tool test intellifold        (GPU node)
#
# NEVER RUN. tools/intellifold is STATUS=planned; there is no image. What is
# written here is what `verified` will have to mean.
#
# Case 2 is doing double duty. It is the bond regression this programme needs
# on any covalent predictor -- and it is also the QUALIFICATION of a capability
# this entry does not claim: upstream's README never mentions bondedAtomPairs.
# Bond support here is inferred from the AlphaFold-3 dialect it says it speaks.
# If case 2 fails, the finding is not "the test is broken", it is "IntelliFold
# does not take AF3 bonds" -- write that in README.md and leave STATUS at
# `built`.
set -eu

: "${INTELLIFOLD_MODEL_DIR:?not set -- run through chpc-tool, which exports it}"

case "$INTELLIFOLD_MODEL_DIR" in
  /*) ;;
  *)  echo "INTELLIFOLD_MODEL_DIR must be absolute, got: $INTELLIFOLD_MODEL_DIR"; exit 1 ;;
esac

# Fail fast on the unmeasured ceiling. chpc-tool compares GPU_MAX_CC with awk,
# awk reads UNMEASURED as 0, and every device is above 0 -- so exec would
# refuse with a message about compute capability that reads like a hardware
# problem. Say what it actually is, and where the answer comes from, because
# there is no torch in this image to ask.
if grep -q '^GPU_MAX_CC=UNMEASURED' "$TOOLDIR/tool.conf" 2>/dev/null; then
    echo "GPU_MAX_CC is still UNMEASURED in $TOOLDIR/tool.conf, so chpc-tool"
    echo "will refuse to exec on any GPU node."
    echo "There is NO torch in this image, so the usual"
    echo "  torch._C._cuda_getArchFlags()"
    echo "route does not exist. See README.md: the honest answer is one small"
    echo "fold on each device class (L40S 8.9, H100 NVL 9.0, Blackwell 12.0),"
    echo "with the job ids written down."
    exit 1
fi

ck=$(find "$INTELLIFOLD_MODEL_DIR" -maxdepth 2 -type f \( -name '*.bin.zst' -o -name '*.bin' \) 2>/dev/null | head -1 || true)
[ -n "$ck" ] || {
    echo "no checkpoint under $INTELLIFOLD_MODEL_DIR"
    echo "fetch with: tools/intellifold/fetch-weights.sh"; exit 1; }
fo=$(find "$INTELLIFOLD_MODEL_DIR" -maxdepth 2 -type f -name '*.npz' 2>/dev/null | head -1 || true)
[ -n "$fo" ] || {
    echo "checkpoint present but no *.npz -- half a download. Re-run fetch-weights.sh"; exit 1; }

sh "$TOOLDIR/../_template/check_covalent_bond.sh" > check_bond.py

# --norun_data_pipeline everywhere below. The data pipeline reaches the
# internet; a compute node has none. Empty unpairedMsa/pairedMsa is AF3's
# single-sequence mode and is used here for the same reason colabfold's test
# passes --msa-mode single_sequence: a test that depends on a remote MSA server
# passes on the login node and fails in every job.

# --- case 1: does it fold at all --------------------------------------------
cat > plain.json <<'JSON'
{
  "name": "plain_probe",
  "modelSeeds": [1],
  "sequences": [
    {
      "protein": {
        "id": "A",
        "sequence": "MKTAYIAKQRQISFVKSHFSRQLEERLGLIE",
        "unpairedMsa": "",
        "pairedMsa": "",
        "templates": []
      }
    }
  ],
  "dialect": "alphafold3",
  "version": 1
}
JSON

if ! "$CHPC_TOOL" exec intellifold -- intellifold predict plain.json \
        --model-dir="$INTELLIFOLD_MODEL_DIR" --output-dir=out_plain \
        -- --norun_data_pipeline > plain.log 2>&1
then
    echo "intellifold predict exited non-zero on the plain case."
    echo "triage:"
    echo "  * dialect  -- the JSON here is UNCONFIRMED against a running"
    echo "                IntelliFold; grep the log for a schema error."
    echo "  * MSA      -- if an empty unpairedMsa is rejected, generate one on"
    echo "                the LOGIN node and paste the a3m in. Do not reach for"
    echo "                the data pipeline; this node has no internet."
    echo "  * XLA      -- a long silence then an OOM or a compile error is the"
    echo "                XLA_FLAGS case; %environment sets"
    echo "                --xla_gpu_enable_triton_gemm=false already."
    tail -40 plain.log; exit 1
fi

cif=$(find out_plain -type f \( -name '*.cif' -o -name '*.pdb' \) 2>/dev/null | head -1)
[ -n "$cif" ] || { echo "no structure written by the plain case"
                   find out_plain -type f 2>/dev/null | head -20; tail -30 plain.log; exit 1; }

if ! "$CHPC_TOOL" exec intellifold -- python - "$cif" > plain_check.log 2>&1 <<'PY'
import math, sys
from check_bond import parse
atoms = parse(sys.argv[1])
ca = [a for a in atoms if a["name"] == "CA"]
assert len(ca) == 31, "expected 31 CA atoms for a 31-mer, got %d" % len(ca)
for a in atoms:
    for c in "xyz":
        assert not (math.isnan(a[c]) or math.isinf(a[c])), "non-finite coordinate"
n = len(ca)
m = [sum(a[c] for a in ca) / n for c in "xyz"]
var = sum(sum((a[c] - m[i]) ** 2 for a in ca) for i, c in enumerate("xyz")) / n
rg = math.sqrt(var)
assert rg > 3.0, "CA radius of gyration %.2f A is too small to be a fold" % rg
print("ok: %d CA atoms, CA spread %.2f A" % (n, rg))
PY
then
    echo "the plain structure did not pass its geometry checks:"
    cat plain_check.log; exit 1
fi
cat plain_check.log

# --- case 2: the bonded case, which is the QUALIFICATION --------------------
# bondedAtomPairs, AF3 dialect: a list of pairs, each endpoint
# [entity_id, residue_id, atom_name] with 1-BASED residue ids. entity_id is the
# chain LABEL ("A", "B") -- note this is NOT protenix's convention, which is a
# 1-based INDEX into the sequences list. Neither errors on the other's input;
# both produce a structure.
#
# The ligand is a registered CCD code, not a SMILES, and that is deliberate.
# AlphaFold 3's documentation is explicit that a SMILES ligand cannot carry a
# bond -- "there is no atom name that could be used to define the bond" -- and
# this engine is AF3's. If that rule carries over, `smiles` here would fail in
# a way that looks like a broken bond rather than an unsupported input.
# UNCONFIRMED: that the rule does carry over, and that ACT's atom name for the
# methyl carbon is CH3. If upstream rejects either, the log names it; swap to a
# thiol-reactive CCD code or a userCCD block and RECORD WHICH ONE in README.md.
#
# The peptide and the ligand here are TEST FIXTURES, not this programme's
# chemistry: bonding a cysteine to acetate's methyl is not a reaction, it is a
# geometry with the right topology for the checker. The campaign's hapten lives
# in Hap108or-data/targets/<id>/ and never in a tool registry -- HA-ADAPT's
# sotorasib SMILES was a different molecule for months precisely because it was
# checked into code, where nobody diffs it.
cat > bonded.json <<'JSON'
{
  "name": "bonded_probe",
  "modelSeeds": [1],
  "sequences": [
    {
      "protein": {
        "id": "A",
        "sequence": "MKTAYCAKQRQISFV",
        "unpairedMsa": "",
        "pairedMsa": "",
        "templates": []
      }
    },
    {
      "ligand": {
        "id": "B",
        "ccdCodes": ["ACT"]
      }
    }
  ],
  "bondedAtomPairs": [
    [["A", 6, "SG"], ["B", 1, "CH3"]]
  ],
  "dialect": "alphafold3",
  "version": 1
}
JSON

if ! "$CHPC_TOOL" exec intellifold -- intellifold predict bonded.json \
        --model-dir="$INTELLIFOLD_MODEL_DIR" --output-dir=out_bond \
        -- --norun_data_pipeline > bond.log 2>&1
then
    echo "intellifold predict exited non-zero on the BONDED case while the"
    echo "plain case passed. The image and the weights are fine."
    echo
    echo "This is the finding, not a test failure. Upstream's README never"
    echo "claims bondedAtomPairs; this case is what was supposed to settle it."
    echo "Write what the log actually says into tools/intellifold/README.md,"
    echo "under 'What was verified', and leave STATUS at built."
    tail -40 bond.log; exit 1
fi

bcif=$(find out_bond -type f \( -name '*.cif' -o -name '*.pdb' \) 2>/dev/null | head -1)
[ -n "$bcif" ] || { echo "no structure written by the bonded case"; tail -30 bond.log; exit 1; }

# Exit 0 and a plausible CIF is not evidence. HA-ADAPT's Chai-1 corpus -- 1,726
# results, quarantined -- was the free drug folded while DECLARED bonded, and
# ipTM moved 0.710 -> 0.698 between the wrong attachment and the right one.
# Geometry is the only check that catches it.
if ! "$CHPC_TOOL" exec intellifold -- python check_bond.py "$bcif" \
        --anchor SG --min 1.2 --max 2.1 > bond_check.log 2>&1
then
    echo "intellifold ACCEPTED bondedAtomPairs and produced a structure whose"
    echo "bond is WRONG -- which is worse than rejecting it, because nothing"
    echo "downstream can tell:"
    cat bond_check.log
    echo
    echo "Do not record this as verified, and do not rank anything on it."
    exit 1
fi
cat bond_check.log

echo "ok: intellifold folds, honours bondedAtomPairs, and puts the bond where it was declared"
