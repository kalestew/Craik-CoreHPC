#!/bin/sh
# OpenFold3 self-test, in two phases.
# Run:  chpc-tool test openfold3          (GPU node)
#
# Phase 1 first ran 2026-09-27 on ggpu4-04 (H100 NVL) and folded.
# Phase 2 was rewritten 2026-09-27: it had carried AlphaFold 3's bond
# spelling, which this tool's schema cannot accept at all, so it was
# testing the wrong key. What it tests now is written at the block.
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
# "a covalently modified fold ran and the modification is a real bond". There is
# deliberately no environment variable that skips phase 2: an escape hatch is a
# thing that gets used at 6pm and then quoted back as a green test.
#
# That definition was met on 2026-09-27, but NOT through the field this entry
# was built to test. `covalent_bonds` is dead and phase 2a now asserts that it
# stays dead; the capability lives in non_canonical_residues and phase 2b
# asserts that. Read the block above phase 2 before editing either.
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
    # THE MSA FLAGS IN THE QUERY DO NOT STOP THE NETWORK CALL. All three --
    # use_msas, use_paired_msas, use_main_msas -- default to True and are set
    # false here, and that is still not enough: the fetch is gated by a
    # SEPARATE experiment setting, `use_msa_server`, which is a CLI flag on
    # `run_openfold predict` and not a field of the query at all. With the query
    # flags false and the CLI flag left alone, openfold3 still goes to the
    # network and dies on a compute node with
    #   requests.exceptions.ProxyError: HTTPSConnectionPool(
    #     host='api.colabfold.com', port=443) ... Failed to establish a new
    #     connection: [Errno 113] No route to host
    # after forty-five seconds, having already loaded 2.3 GB of weights. So
    # `--use-msa-server=False` is passed below, and the query flags are kept
    # false as well because they are what the MSA pipeline itself reads
    # (msa_pipeline_configs.py:109).
    #
    # It calls the PUBLIC ColabFold MSA server by default, which matters well
    # beyond this test: compute nodes here have no internet at all (docs/02), so
    # a production fold must either pass --use-msa-server=False and supply its
    # own MSAs through the per-chain main_msa_file_paths / paired_msa_file_paths
    # fields, or not run on a compute node. Phase 1 asks for no MSAs at all.
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
        --query_json=plain.json --output_dir=out_plain \
        --use-msa-server=False --use-templates=False > plain.log 2>&1
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

# --- phase 2: the covalent qualification ------------------------------------
# SETTLED 2026-09-27 on this image, by measurement rather than by reading the
# documentation -- which still mentions bonds nowhere. The conclusion REVERSES
# this entry's earlier one, so read it before changing anything here.
#
# OpenFold3 DOES fold covalent modifications, correctly, in every draw. What it
# does not do is read the field named for them.
#
#   covalent_bonds          declared on Query and read by NOTHING. Its sibling
#                           field pocket_constraint, in the same model, has a
#                           full consumer chain (config -> featurization ->
#                           diffusion_module -> its own tests). covalent_bonds
#                           has one occurrence in the package: the declaration.
#   non_canonical_residues  the route that works. A modified residue named by
#                           CCD code goes into the polymer chain, biotite's
#                           connect_via_residue_names() bonds it, and the bond
#                           IS in atom_array.bonds -- which is the only thing
#                           create_token_bonds() reads. So it reaches the model
#                           as a real token_bonds feature.
#
# The two halves below assert OPPOSITE things on purpose. 2a asserts the dead
# field is still dead, as a tripwire: if upstream ever wires it up, this test
# fails and the failure message says to go and use it. 2b asserts the live route
# still works.
#
# The shared checker is NOT used here, and cannot be. It assumes one polymer
# chain and one non-polymer ligand within bonding distance of an anchor; the
# route that works on this tool has no ligand chain at all, because the
# modification IS a residue. That is a real difference in kind from the other
# five covalent entries, not a convenience -- see ../covalent-bonds.md.

# --- 2a: covalent_bonds is inert, and this is the tripwire ------------------
# No GPU, no weights, no fold. The model's only bond input is token_bonds and
# create_token_bonds() reads atom_array.bonds and nothing else, so the question
# is settled on the AtomArray: build one from a query that declares a bond,
# build one from the same query without it, and compare.
if ! "$CHPC_TOOL" exec openfold3 -- python - > cov_field.log 2>&1 <<'PY'
import numpy as np
from openfold3.projects.of3_all_atom.config.inference_query_format import Query
from openfold3.core.data.primitives.structure.query import (
    structure_with_ref_mols_from_query,
)

PEPTIDE = "MKTAYCAKQRQISFV"        # cysteine at 1-based position 6
CHAINS = [
    {"molecule_type": 0, "chain_ids": ["A"], "sequence": PEPTIDE},
    {"molecule_type": 3, "chain_ids": ["B"], "ccd_codes": ["ACT"]},
]

apo, _ = structure_with_ref_mols_from_query(Query(chains=CHAINS))
# atom_id is typed int on Bond.Atom, so there is no way to NAME SG here: an
# index is the only address the schema offers. That is reason enough not to use
# this field even if it worked.
cov, _ = structure_with_ref_mols_from_query(Query(
    chains=CHAINS, covalent_bonds=[(("A", 6, 5), ("B", 1, 3))]))


def crossing(aa):
    return [(i, j) for i, j in aa.bonds.as_array()[:, :2]
            if aa.chain_id[i] != aa.chain_id[j]]


n_apo, n_cov = len(crossing(apo)), len(crossing(cov))
print("apo query          : %d atoms, %d bonds, %d crossing a chain boundary"
      % (len(apo), len(apo.bonds.as_array()), n_apo))
print("covalent_bonds set : %d atoms, %d bonds, %d crossing a chain boundary"
      % (len(cov), len(cov.bonds.as_array()), n_cov))

assert n_apo == 0, "the apo query already has an inter-chain bond -- read this test again"
assert n_cov == 0, (
    "covalent_bonds PRODUCED A BOND (%d of them). This is GOOD NEWS and this "
    "test is now wrong: upstream has wired the field up since 2026-09-27. Go "
    "and use it -- rewrite this block to assert the bond is on the declared "
    "atom, and use ../_template/check_covalent_bond.sh, which now applies "
    "because there is a ligand chain again." % n_cov)
assert np.array_equal(apo.bonds.as_array(), cov.bonds.as_array()), (
    "the bond lists differ although neither crosses a chain boundary -- "
    "covalent_bonds is doing SOMETHING. Find out what before trusting either.")
print("ok: covalent_bonds is declared, parsed, and dropped -- the AtomArray is "
      "byte-identical with and without it")
PY
then
    echo "phase 2a did not run:"
    cat cov_field.log; exit 1
fi
cat cov_field.log

# --- 2b: the modified-residue route, which is the capability ----------------
# YCM is S-(2-amino-2-oxoethyl)-L-cysteine: the iodoacetamide-cysteine adduct,
# a real covalent modification carried as ONE CCD residue inside the polymer.
# The thioether SG-CD is the bond under test, ideal 1.81 A.
#
# non_canonical_residues is a dict keyed by 1-BASED RESIDUE ID -- JSON keys are
# strings and _cast_keys_to_int converts them. The residue it replaces does not
# have to be the same amino acid as the sequence letter; the letter is what the
# MSA and the templates see and the CCD code is what is built, so keep them
# consistent or the two disagree silently.
#
# NOTE what is NOT honoured here: "seeds" in the query JSON. InferenceQuerySet
# declares it, the runner reads experiment_settings.seeds instead, and the
# default is [42] -- so a query asking for seeds [1,2,3] folds seed 42 and says
# nothing. Seed count comes from --num-model-seeds and the seeds themselves from
# the runner yaml. This test does not pass either, so it gets seed 42 and five
# diffusion samples; it asserts on ALL of them.
cat > ycm.json <<'JSON'
{
  "queries": {
    "ycm_probe": {
      "chains": [
        {
          "molecule_type": 0,
          "chain_ids": ["A"],
          "sequence": "MKTAYCAKQRQISFV",
          "non_canonical_residues": {"6": "YCM"}
        }
      ],
      "use_msas": false,
      "use_paired_msas": false,
      "use_main_msas": false
    }
  }
}
JSON

if ! "$CHPC_TOOL" exec openfold3 -- run_openfold predict \
        --query_json=ycm.json --output_dir=out_ycm \
        --use-msa-server=False --use-templates=False > ycm.log 2>&1
then
    echo "phase 2b: the modified-residue fold exited non-zero while phase 1"
    echo "passed, so the image and the weights are fine."
    echo
    echo "The likely cause is the CCD. YCM is resolved through biotite's"
    echo "bundled component dictionary, not through anything this registry"
    echo "stages, and get_structure_with_ref_mols() is a staticmethod that"
    echo "never receives the ccd_file_path setting -- so a custom component"
    echo "CANNOT be supplied here and a missing one cannot be worked around."
    tail -40 ycm.log; exit 1
fi

n_ycm=$(find out_ycm -name '*.cif' 2>/dev/null | wc -l)
[ "$n_ycm" -ge 1 ] || { echo "phase 2b wrote no structure"; tail -30 ycm.log; exit 1; }

# EVERY draw, not the first one. This registry has already been bitten by a test
# that read `find | head -1` and so asserted a property of one arbitrary sample
# rather than of the tool: intellifold's case 2 failed for two days on a draw
# that was the one bad one in its seed. Five samples cost nothing to check.
if ! "$CHPC_TOOL" exec openfold3 -- python - out_ycm > ycm_check.log 2>&1 <<'PY'
import math, os, sys

MIN, MAX, IDEAL = 1.2, 2.1, 1.81


def atoms(path):
    out, cols = [], {}
    for line in open(path, errors="replace"):
        s = line.strip()
        if s == "loop_":
            cols = {}
            continue
        if s.startswith("_atom_site."):
            cols[s.split(".", 1)[1]] = len(cols)
            continue
        if cols and (s.startswith("ATOM ") or s.startswith("HETATM")):
            f = s.split()
            out.append((f[cols["label_comp_id"]], f[cols["label_atom_id"]],
                        tuple(float(f[cols["Cartn_" + c]]) for c in "xyz")))
    return out


paths = []
for root, _, files in os.walk(sys.argv[1]):
    paths += [os.path.join(root, f) for f in files if f.endswith(".cif")]
assert paths, "no cif under %s" % sys.argv[1]

dists = []
for path in sorted(paths):
    aa = atoms(path)
    ycm = {n: xyz for res, n, xyz in aa if res == "YCM"}
    assert ycm, "%s has no YCM residue: the modification was not built" % path
    for need in ("SG", "CD", "CE", "OZ1", "NZ2"):
        assert need in ycm, "%s: YCM is missing %s" % (path, need)
    d = math.dist(ycm["SG"], ycm["CD"])
    dists.append((d, os.path.basename(path)))
    print("  %-52s SG-CD %.3f A" % (os.path.basename(path)[-50:], d))

bad = [(d, n) for d, n in dists if not (MIN <= d <= MAX)]
lo, hi = min(d for d, _ in dists), max(d for d, _ in dists)
print("%d draws, SG-CD %.3f-%.3f A against the CCD ideal %.2f A"
      % (len(dists), lo, hi, IDEAL))
assert not bad, (
    "the covalent modification is NOT a bond in %d of %d draws: %s. The "
    "modified residue was built but the thioether was not closed, which no "
    "confidence score and no exit status reports."
    % (len(bad), len(dists), ", ".join("%s %.3f A" % (n, d) for d, n in bad)))
print("ok: SG-CD is a real thioether in all %d draws" % len(dists))
PY
then
    echo "phase 2b: the modification did not come out as a bond:"
    cat ycm_check.log
    echo
    echo "This is the finding, and it reverses the entry. Record it in"
    echo "README.md under 'Covalent support' and leave STATUS=built."
    exit 1
fi
cat ycm_check.log

echo
echo "ok: openfold3 folds; covalent_bonds is still inert; and a covalent"
echo "modification declared through non_canonical_residues is built as a real"
echo "bond in every draw."
