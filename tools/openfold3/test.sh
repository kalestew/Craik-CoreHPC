#!/bin/sh
# OpenFold3 self-test, in two phases.
# Run:  chpc-tool test openfold3          (GPU node)
#
# NEVER RUN. tools/openfold3 is STATUS=planned; there is no image.
#
# Phase 1 asks whether the image folds. Phase 2 asks the question this entry
# actually exists to answer: does OpenFold3 accept a covalent bond, and does it
# put it where it was told? Upstream's documentation does not mention
# bondedAtomPairs, covalent bonds, CCD codes, SMILES or ligand atom naming
# ANYWHERE, so there is no source for a confident answer and none is written
# here.
#
# BOTH phases are hard failures, and that is the design. The registry's ladder
# is planned -> built -> verified, and for this entry `verified` is defined as
# "a BONDED fold ran and the bond is in the right place". There is deliberately
# no environment variable that skips phase 2: an escape hatch is a thing that
# gets used at 6pm and then quoted back as a green test. If phase 2 cannot
# pass, the honest end state is STATUS=built forever, with the reason written
# into README.md -- which is a perfectly good outcome and considerably more
# useful than a green tick.
set -eu

: "${OPENFOLD3_WEIGHTS:?not set -- run through chpc-tool, which exports it}"

case "$OPENFOLD3_WEIGHTS" in
  /*) ;;
  *)  echo "OPENFOLD3_WEIGHTS must be absolute, got: $OPENFOLD3_WEIGHTS"; exit 1 ;;
esac

# Fail fast and usefully on the unmeasured ceiling: chpc-tool compares
# GPU_MAX_CC with awk, awk reads UNMEASURED as 0, every device is above 0, and
# exec would refuse with a message about compute capability that reads like a
# hardware fault.
if grep -q '^GPU_MAX_CC=UNMEASURED' "$TOOLDIR/tool.conf" 2>/dev/null; then
    echo "GPU_MAX_CC is still UNMEASURED in $TOOLDIR/tool.conf, so chpc-tool"
    echo "will refuse to exec on any GPU node. Measure it on the LOGIN node:"
    echo "  /usr/bin/apptainer exec \"\$CHPC_CONTAINERS/openfold3_3.sif\" \\"
    echo "    python -c \"import torch; print(torch._C._cuda_getArchFlags())\""
    echo "highest sm_NN -> N.N; write it into tool.conf, then re-run this test."
    exit 1
fi

n=$(find "$OPENFOLD3_WEIGHTS" -type f \( -name '*.pt' -o -name '*.ckpt' -o -name '*.safetensors' \) 2>/dev/null | wc -l)
[ "$n" -ge 1 ] || {
    echo "no model parameters under $OPENFOLD3_WEIGHTS"
    echo "fetch with: tools/openfold3/fetch-weights.sh"; exit 1; }

sh "$TOOLDIR/../_template/check_covalent_bond.sh" > check_bond.py

# --- phase 1: does the image fold anything ----------------------------------
# Upstream's OWN example is preferred over a schema copied out of a README.
# The query format is unconfirmed, and this is the cheapest way not to guess:
# whatever ships inside the image is, by construction, the schema that version
# accepts.
q=$("$CHPC_TOOL" exec openfold3 -- sh -c \
      'find / -xdev -path "*example*" -name "query_*.json" 2>/dev/null | head -1' || true)
if [ -n "$q" ]; then
    echo "phase 1 input: upstream's own $q"
    "$CHPC_TOOL" exec openfold3 -- cat "$q" > plain.json
else
    echo "phase 1 input: no upstream example inside the image; schema read"
    echo "  out of the installed package (see the comment below)"
    # THE SCHEMA IS NO LONGER A GUESS. It was, and the guess was the AlphaFold 3
    # spelling -- {"name", "sequences":[{"protein":{"id","sequence"}}]} -- which
    # openfold3 rejects with
    #   ValidationError: 1 validation error for InferenceQuerySet
    #   queries  Field required
    # Read off InferenceQuerySet and Query in
    # openfold3/projects/of3_all_atom/config/inference_query_format.py, 2026-09-27:
    #
    #   InferenceQuerySet: seeds: list[int], queries: dict[str, Query]
    #   Query: query_name, chains (REQUIRED), use_msas, use_paired_msas,
    #          use_main_msas, covalent_bonds, pocket_constraint
    #   Chain: molecule_type, chain_ids: list[str], sequence, smiles,
    #          ccd_codes, cyclic, and the msa/template path fields
    #   MoleculeType: PROTEIN=0  RNA=1  DNA=2  LIGAND=3
    #
    # Note what is NOT here: no per-chain "id", it is "chain_ids" and a LIST;
    # molecule_type is an INTEGER ENUM rather than the key name; and the queries
    # are a DICT keyed by name, not an array. Nothing about that is guessable
    # from the AF3 format the README cites.
    #
    # ALL THREE MSA FLAGS MUST BE FALSE, and each defaults to True. Setting
    # use_msas alone is not enough: with use_paired_msas and use_main_msas still
    # true, openfold3 goes to the network and dies on a compute node with
    #   requests.exceptions.ProxyError: HTTPSConnectionPool(
    #     host='api.colabfold.com', port=443) ... Failed to establish a new
    #     connection: [Errno 113] No route to host
    # after fifty seconds, having already loaded the weights. It calls the PUBLIC
    # ColabFold MSA server by default -- worth knowing for its own sake, since
    # compute nodes here have no internet at all (docs/02) and a production fold
    # therefore needs its MSAs supplied through the per-chain
    # main_msa_file_paths / paired_msa_file_paths fields rather than fetched.
    # Phase 1 is asking whether the image folds at all, so it asks for none.
    cat > plain.json <<'JSON'
{
  "seeds": [1],
  "queries": {
    "plain_probe": {
      "chains": [
        {
          "molecule_type": 0,
          "chain_ids": ["A"],
          "sequence": "MKTAYIAKQRQISFVKSHFSRQLEERLGLIE"
        }
      ],
      "use_msas": false,
      "use_paired_msas": false,
      "use_main_msas": false
    }
  }
}
JSON
fi

if ! "$CHPC_TOOL" exec openfold3 -- run_openfold predict \
        --query_json=plain.json --output_dir=out_plain > plain.log 2>&1
then
    echo "run_openfold exited non-zero on phase 1."
    echo "triage, in the order these have bitten this registry:"
    if grep -qi "failed to find c compiler\|triton" plain.log 2>/dev/null; then
        echo "  * C COMPILER -- cuEquivariance's Triton kernels could not build."
        echo "    The .def installs build-essential precisely for this, so the"
        echo "    image in use was NOT built from it. This is boltz's failure"
        echo "    exactly: four seconds in, nothing written."
    fi
    if grep -qi "deepspeed\|ninja\|nvcc" plain.log 2>/dev/null; then
        echo "  * DEEPSPEED OP BUILDER -- needs nvcc, a C++ compiler and ninja"
        echo "    at RUN time. TORCH_EXTENSIONS_DIR is set to /tmp in the .def;"
        echo "    if it is pointing at \$HOME here, two array tasks are fighting"
        echo "    over one build tree."
    fi
    echo "  * MSA -- anything reaching a remote MSA server fails on a compute"
    echo "    node, which has no internet. Precompute on the login node."
    echo "  * --output_dir may not be the flag this version takes."
    tail -40 plain.log; exit 1
fi

cif=$(find out_plain -type f \( -name '*.cif' -o -name '*.pdb' \) 2>/dev/null | head -1)
[ -n "$cif" ] || { echo "phase 1 wrote no structure"
                   find out_plain -type f 2>/dev/null | head -20; tail -30 plain.log; exit 1; }

# Assert the fold, not the file. A collapsed point cloud is valid mmCIF; only
# the spread separates "wrote a structure" from "ran the diffusion module".
# The residue count is not asserted, because phase 1's input may be upstream's
# example rather than ours.
if ! "$CHPC_TOOL" exec openfold3 -- python - "$cif" > plain_check.log 2>&1 <<'PY'
import math, sys
from check_bond import parse
atoms = parse(sys.argv[1])
ca = [a for a in atoms if a["name"] == "CA"]
assert len(ca) >= 20, "only %d CA atoms -- that is not a fold" % len(ca)
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
    echo "phase 1 structure did not pass its geometry checks:"
    cat plain_check.log; exit 1
fi
cat plain_check.log
echo "phase 1 ok -- the image folds. This does NOT qualify it for this programme."

# --- phase 2: the qualification ---------------------------------------------
# Everything below is a HYPOTHESIS. Upstream says OpenFold3 "replicates the
# input features described in the AlphaFold3 publication"; it does not say the
# input FORMAT is AlphaFold 3's, and it never mentions bonds. So the AF3
# spelling is tried because it is the only documented candidate, not because
# there is any source for it.
#
# Read the failure carefully when it comes. There are three different outcomes
# and they mean different things:
#   a. schema error naming bondedAtomPairs   -> the key is wrong; find the
#      right one in the installed package's schema and write it in README.md.
#   b. schema accepted, bond silently ignored -> the checker below catches it
#      as a free ligand metres away. This is the dangerous one.
#   c. schema accepted, bond honoured        -> qualified. Record the exact
#      JSON that worked in README.md, because it is not in any upstream doc.
#
# The ligand is a registered CCD code rather than a SMILES because AlphaFold 3
# cannot bond a SMILES ligand at all -- "there is no atom name that could be
# used to define the bond" -- and a tool replicating AF3's features plausibly
# inherits that. UNCONFIRMED, like everything else in this block.
#
# The peptide and the ligand are TEST FIXTURES, not this programme's chemistry.
# The campaign's hapten lives in Hap108or-data/targets/<id>/ and never in a
# tool registry: HA-ADAPT's sotorasib SMILES was a different molecule for
# months precisely because it was checked into code, where nobody diffs it.
cat > bonded.json <<'JSON'
{
  "name": "bonded_probe",
  "sequences": [
    {"protein": {"id": "A", "sequence": "MKTAYCAKQRQISFV"}},
    {"ligand": {"id": "B", "ccdCodes": ["ACT"]}}
  ],
  "bondedAtomPairs": [
    [["A", 6, "SG"], ["B", 1, "CH3"]]
  ]
}
JSON

if ! "$CHPC_TOOL" exec openfold3 -- run_openfold predict \
        --query_json=bonded.json --output_dir=out_bond > bond.log 2>&1
then
    echo
    echo "PHASE 2 FAILED, and phase 1 passed -- so the image and the weights"
    echo "are fine and the BOND SPECIFICATION is the problem."
    echo
    echo "This is the finding this entry was created to produce. Do the"
    echo "following before anything else:"
    echo "  1. read the error below and decide which of (a)/(b)/(c) it is"
    echo "     (see the comment above this block);"
    echo "  2. if the key is simply wrong, find the real one --"
    echo "       chpc-tool exec openfold3 -- python -c \\"
    echo "         \"import openfold3, pathlib; print(pathlib.Path(openfold3.__file__).parent)\""
    echo "     then grep that tree for the query schema;"
    echo "  3. write what you found into tools/openfold3/README.md under"
    echo "     'Covalent support', replacing the unqualified paragraph;"
    echo "  4. leave STATUS=built. Do not set verified."
    echo
    tail -40 bond.log; exit 1
fi

bcif=$(find out_bond -type f \( -name '*.cif' -o -name '*.pdb' \) 2>/dev/null | head -1)
[ -n "$bcif" ] || { echo "phase 2 wrote no structure"; tail -30 bond.log; exit 1; }

# Accepting the input is NOT the qualification. Outcome (b) above -- schema
# accepted, bond quietly ignored -- produces a perfectly plausible structure
# with the ligand docked somewhere nearby, and no score detects it: HA-ADAPT's
# Chai-1 corpus (1,726 results, quarantined) is exactly that, and ipTM moved
# 0.710 -> 0.698 between the wrong attachment and the right one.
if ! "$CHPC_TOOL" exec openfold3 -- python check_bond.py "$bcif" \
        --anchor SG --min 1.2 --max 2.1 > bond_check.log 2>&1
then
    echo
    echo "PHASE 2: OpenFold3 ACCEPTED the bond specification and then did not"
    echo "honour it. This is the worst of the three outcomes, because the run"
    echo "succeeds and the structure looks fine:"
    cat bond_check.log
    echo
    echo "Record it in README.md as 'accepts the key, ignores the bond' --"
    echo "that sentence is worth more than this test. Leave STATUS=built."
    exit 1
fi
cat bond_check.log

echo
echo "ok: openfold3 folds, accepts a covalent bond, and puts it where it was"
echo "declared. Copy bonded.json into README.md -- it is the only record of a"
echo "working bond input for this tool, since upstream documents none."
