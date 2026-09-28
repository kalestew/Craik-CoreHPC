#!/bin/sh
# IntelliFold self-test: fold a peptide, then fold a BONDED complex and prove
# the bond is where it was asked for.
# Run:  chpc-tool test intellifold        (GPU node)
#
# Case 2 was the QUALIFICATION of a capability upstream never claims: its README
# never mentions bondedAtomPairs, and bond support was inferred from the
# AlphaFold-3 dialect it says it speaks. That question is now SETTLED -- the keys
# are read and the bond is placed on the declared atom -- so case 2 is a
# regression gate rather than an open question, and case 3 was added for the
# chemistry this programme actually runs.
#
# Cases 2 and 3 are held to DIFFERENT standards, from 95 measured folds. Read the
# comment above case 2 before changing either threshold; the reason they differ is
# the most important thing this entry knows.
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

# --- case 2: bondedAtomPairs IS honoured, and this is the deterministic gate --
# MEASURED 2026-09-27 on ggpu1-06 (L40S), 95 folds across five configurations.
# The headline is not that the bond works -- it is WHAT DECIDES whether it works,
# which is neither the schema nor the chemistry:
#
#   peptide          bond                    draws at 1.2-2.1 A
#   N6-A7-T8         ASN ND2 -- NAG C1       15/15   1.336-1.478 A
#   N6-A7-K8         ASN ND2 -- NAG C1        0/25   free, 6.7-10.9 A
#   N6-A7-K8 rev     NAG C1 -- ASN ND2        0/15   free, 8.4-13.0 A
#   C6               CYS SG  -- MOV C25      17/25   never escapes
#   C6               CYS SG  -- ACT CH3      18/25   2 draws at 14-19 A
#
# Rows one and two differ by ONE RESIDUE, two positions away from the bond:
# N-A-T is an N-glycosylation sequon and N-A-K is not. Same JSON, same ligand,
# same atom names, same seeds. So a declared bond here is NOT A CONSTRAINT, it is
# a proposal the model's sequence prior can veto -- silently, with no warning in
# the log, no _struct_conn record either way, and no confidence score that moves.
# Row three rules out endpoint order as the explanation: reversing the pair
# changes nothing, so the pair is unordered as documented and the sequon is the
# whole variable.
#
# Case 2 therefore uses the sequon, because it is the configuration that isolates
# the QUESTION -- does this engine read bondedAtomPairs and place the bond on the
# declared atom -- from the model's willingness to believe any particular
# chemistry. 15/15 with a 0.14 A spread is a gate that means something and does
# not flake. Case 3 below carries the programme's own chemistry and its real rate.
cat > bonded.json <<'JSON'
{
  "name": "bonded_probe",
  "modelSeeds": [1],
  "sequences": [
    {
      "protein": {
        "id": "A",
        "sequence": "MKTAYNATQRQISFV",
        "unpairedMsa": "",
        "pairedMsa": "",
        "templates": []
      }
    },
    {
      "ligand": {
        "id": "B",
        "ccdCodes": ["NAG"]
      }
    }
  ],
  "bondedAtomPairs": [
    [["A", 6, "ND2"], ["B", 1, "C1"]]
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
    echo "bondedAtomPairs and userCCD are both READ by the vendored AF3 parser"
    echo "(measured 2026-09-25 and 2026-09-27), so a hard failure here is a"
    echo "change upstream, not the unqualified capability this block once was."
    tail -40 bond.log; exit 1
fi

# EVERY draw, not `find | head -1`. The version of this test that read one
# arbitrary sample reported FAIL for two days on a tool that was working: its
# fixture drew 2.231 A at seed-1/sample-0, which is the single worst draw of
# that seed's five. A property of one sample is not a property of the tool.
if ! "$CHPC_TOOL" exec intellifold -- python - > bond_check.log 2>&1 <<'PY'
import math, os, sys
from check_bond import parse

root, anchor, declared = "out_bond", "ND2", "C1"
STANDARD = set("""ALA ARG ASN ASP CYS GLN GLU GLY HIS ILE LEU LYS MET PHE PRO
SER THR TRP TYR VAL MSE SEC HOH""".split())
MIN, MAX = 1.2, 2.1

# Only the per-draw files. intellifold also writes a top-level copy of whichever
# draw it ranked first, and counting it twice would weight one sample double.
paths = sorted(os.path.join(d, f)
               for d, _, fs in os.walk(root) for f in fs
               if f.endswith(".cif") and "sample-" in f)
assert paths, "no per-sample cif under %s" % root

rows = []
for path in paths:
    atoms = parse(path)
    anc = [a for a in atoms if a["name"] == anchor and a["resname"] in STANDARD]
    lig = [a for a in atoms if a["resname"] not in STANDARD
           and a["element"] != "H"]
    assert len(anc) == 1, "%s: %d %s atoms" % (path, len(anc), anchor)
    assert lig, "%s: no ligand atoms" % path
    p = (anc[0]["x"], anc[0]["y"], anc[0]["z"])
    d = {a["name"]: math.dist(p, (a["x"], a["y"], a["z"])) for a in lig}
    near = min(d, key=d.get)
    rows.append((os.path.basename(path), d.get(declared, float("nan")), near, d[near]))

print("  %-42s %9s %9s %s" % ("draw", declared, "nearest", "which"))
for name, dd, near, dn in rows:
    print("  %-42s %9.3f %9.3f %s" % (name[-40:], dd, dn, near))

# The wrong-atom check is the one this registry exists for, and it is stated so
# that "not bonded" does not trip it: whatever is within bonding distance of the
# anchor must be the atom that was declared. HA-ADAPT's quarantined corpus is
# 1,726 structures bonded to an aromatic ring carbon at 1.68 A while the warhead
# sat at 13.59 A -- in range, and wrong.
wrong = [(n, near, dn) for n, dd, near, dn in rows if dn <= MAX and near != declared]
assert not wrong, (
    "bonded to the WRONG ATOM in %d draw(s): %s. This is the failure that no "
    "confidence score reports and that quarantined 1,726 results."
    % (len(wrong), ", ".join("%s -> %s at %.3f A" % w for w in wrong)))

inrange = [n for n, dd, _, _ in rows if MIN <= dd <= MAX]
print("%d/%d draws carry the declared bond at %.2f-%.2f A"
      % (len(inrange), len(rows), MIN, MAX))
assert len(inrange) == len(rows), (
    "the sequon case is the DETERMINISTIC gate and %d of %d draws missed it "
    "(distances: %s). 15/15 was measured on 2026-09-27 with a 0.14 A spread, so "
    "this is a real change, not sampling noise."
    % (len(rows) - len(inrange), len(rows),
       ", ".join("%.3f" % dd for _, dd, _, _ in rows)))
print("ok: bondedAtomPairs is honoured and the bond is on the declared atom in "
      "all %d draws" % len(rows))
PY
then
    echo "case 2 FAILED -- and this is the gate that does not flake:"
    cat bond_check.log
    echo
    echo "Do not record this as verified, and do not rank anything on it."
    exit 1
fi
cat bond_check.log

# --- case 3: the programme's own chemistry, and the rate it comes at ---------
# MOV is AMG 510 (bound form) -- sotorasib, in the CCD that ships inside this
# image, 41 heavy atoms, and the same component the P1B7 walkthrough folds. Its
# C25 is the acrylamide warhead carbon, and it is the atom the deposited 8UDR
# bonds to CYS SG at 1.765 A.
#
# This case exists because case 2's chemistry is the one the model is sure about
# and this one is the chemistry the programme actually runs. It is NOT held to
# case 2's every-draw standard, because 25 draws measured 17 in range: the bond
# comes out systematically LONG, clustered at 2.0-2.1 A against an ideal 1.81 A,
# right on the gate boundary. What it IS held to is the pair of properties that
# matter and that did hold 25/25:
#
#   * nothing is ever bonded to the wrong atom;
#   * the capability is real -- some draw closes the bond.
#
# The consequence for production is the third rule of ../covalent-bonds.md, and
# it is not optional here: fold several draws and screen EVERY one you keep.
cat > warhead.json <<'JSON'
{
  "name": "warhead_probe",
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
        "ccdCodes": ["MOV"]
      }
    }
  ],
  "bondedAtomPairs": [
    [["A", 6, "SG"], ["B", 1, "C25"]]
  ],
  "dialect": "alphafold3",
  "version": 1
}
JSON

if ! "$CHPC_TOOL" exec intellifold -- intellifold predict warhead.json \
        --model-dir="$INTELLIFOLD_MODEL_DIR" --output-dir=out_warhead \
        -- --norun_data_pipeline > warhead.log 2>&1
then
    echo "case 3 exited non-zero while case 2 passed, so bondedAtomPairs is"
    echo "fine and the LIGAND is the problem. MOV is resolved from the CCD"
    echo "baked into this image; if a rebuild changed that table, say so in"
    echo "README.md rather than swapping the fixture quietly."
    tail -40 warhead.log; exit 1
fi

if ! "$CHPC_TOOL" exec intellifold -- python - > warhead_check.log 2>&1 <<'PY'
import math, os, sys
from check_bond import parse

root, anchor, declared = "out_warhead", "SG", "C25"
STANDARD = set("""ALA ARG ASN ASP CYS GLN GLU GLY HIS ILE LEU LYS MET PHE PRO
SER THR TRP TYR VAL MSE SEC HOH""".split())
MIN, MAX = 1.2, 2.1

paths = sorted(os.path.join(d, f)
               for d, _, fs in os.walk(root) for f in fs
               if f.endswith(".cif") and "sample-" in f)
assert paths, "no per-sample cif under %s" % root

rows = []
for path in paths:
    atoms = parse(path)
    anc = [a for a in atoms if a["name"] == anchor and a["resname"] in STANDARD]
    lig = [a for a in atoms if a["resname"] not in STANDARD
           and a["element"] != "H"]
    assert len(anc) == 1, "%s: %d %s atoms" % (path, len(anc), anchor)
    p = (anc[0]["x"], anc[0]["y"], anc[0]["z"])
    d = {a["name"]: math.dist(p, (a["x"], a["y"], a["z"])) for a in lig}
    near = min(d, key=d.get)
    rows.append((os.path.basename(path), d.get(declared, float("nan")), near, d[near]))

print("  %-42s %9s %9s %s" % ("draw", declared, "nearest", "which"))
for name, dd, near, dn in rows:
    print("  %-42s %9.3f %9.3f %s" % (name[-40:], dd, dn, near))

wrong = [(n, near, dn) for n, dd, near, dn in rows if dn <= MAX and near != declared]
assert not wrong, (
    "the warhead is bonded to the WRONG ATOM in %d draw(s): %s. Measured "
    "25/25 correct on 2026-09-27, so this is a real regression -- and it is the "
    "exact failure that quarantined 1,726 results." 
    % (len(wrong), ", ".join("%s -> %s at %.3f A" % w for w in wrong)))

inrange = [dd for _, dd, _, _ in rows if MIN <= dd <= MAX]
lo = min(dd for _, dd, _, _ in rows)
print("%d/%d draws close the bond; best %.3f A against 1.765 A in deposited 8UDR"
      % (len(inrange), len(rows), lo))
assert inrange, (
    "NO draw closed the warhead bond -- best was %.3f A. Measured 17/25 in "
    "range on 2026-09-27; zero of %d is a different tool. Check first whether "
    "the peptide still has its cysteine at position 6, because the sequence "
    "prior can veto a declared bond outright (case 2's comment)." % (lo, len(rows)))
print("ok: the sotorasib warhead bond is on C25 in every draw and closed in %d "
      "of %d -- screen every draw you keep" % (len(inrange), len(rows)))
PY
then
    echo "case 3 FAILED:"
    cat warhead_check.log
    echo
    echo "Do not record this as verified, and do not rank anything on it."
    exit 1
fi
cat warhead_check.log

echo
echo "ok: intellifold folds, honours bondedAtomPairs, and puts the bond on the"
echo "declared atom -- deterministically on glycosylation, and on the sotorasib"
echo "warhead in every draw though only some draws close it."
