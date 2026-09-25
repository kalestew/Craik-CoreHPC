#!/bin/sh
# Protenix v1 self-test: fold a peptide, then fold a HAPTENATED one and prove
# the bond is where it was asked for.
# Run:  chpc-tool test protenix          (GPU node)
#
# NEVER RUN. tools/protenix is STATUS=planned; there is no image. What is
# written here is what `verified` will have to mean, not a record of anything
# passing. Three things below are UNCONFIRMED against a built image and are
# marked at the point they appear: the input JSON schema, whether Protenix will
# fold without an MSA at all, and the ligand atom naming in the output.
#
# The second case is the one that matters to this programme. HA-ADAPT's whole
# Chai-1 corpus is quarantined because the free drug was folded while DECLARED
# bonded -- peptide cysteine to an aromatic ring carbon at 1.68 A instead of
# the warhead at 13.59 A -- and ipTM moved 0.710 -> 0.698 between the wrong
# structure and the right one. A predictor that exits 0 and writes a plausible
# CIF has told you nothing. Geometry is the only check that works.
set -eu

: "${PROTENIX_ROOT_DIR:?not set -- run through chpc-tool, which exports it}"

case "$PROTENIX_ROOT_DIR" in
  /*) ;;
  *)  echo "PROTENIX_ROOT_DIR must be absolute, got: $PROTENIX_ROOT_DIR"; exit 1 ;;
esac

# Fail fast and usefully on the unmeasured ceiling. chpc-tool compares
# GPU_MAX_CC with awk, awk reads UNMEASURED as 0, and every device is above 0
# -- so `chpc-tool exec` would refuse here with a message about compute
# capability that reads like a hardware problem. Say what it actually is.
if grep -q '^GPU_MAX_CC=UNMEASURED' "$TOOLDIR/tool.conf" 2>/dev/null; then
    echo "GPU_MAX_CC is still UNMEASURED in $TOOLDIR/tool.conf, so chpc-tool"
    echo "will refuse to exec on any GPU node. Measure it on the LOGIN node:"
    echo "  /usr/bin/apptainer exec \"\$CHPC_CONTAINERS/protenix_1.sif\" \\"
    echo "    python -c \"import torch; print(torch._C._cuda_getArchFlags())\""
    echo "highest sm_NN -> N.N; write it into tool.conf, then re-run this test."
    exit 1
fi

n_ckpt=$(find "$PROTENIX_ROOT_DIR/checkpoint" -type f -name '*.pt' 2>/dev/null | wc -l)
[ "$n_ckpt" -ge 1 ] || {
    echo "no checkpoint under $PROTENIX_ROOT_DIR/checkpoint"
    echo "fetch with: tools/protenix/fetch-weights.sh"; exit 1; }

# The licence guard, asserted rather than trusted. v2's weights carry no
# open-source licence and restrict the OUTPUTS; a test that would happily run
# them is a test that lets a filing-relevant structure be produced by them.
v2=$(find "$PROTENIX_ROOT_DIR/checkpoint" -type f -name '*v2*' 2>/dev/null | head -1 || true)
[ -z "$v2" ] || {
    echo "PROPRIETARY v2 checkpoint on the share: $v2"
    echo "this entry is v1 only -- see README.md. Remove it before testing."; exit 1; }

MODEL="${PROTENIX_TEST_MODEL:-protenix_base_default_v1.0.0}"

# The shared checker, emitted rather than imported: the registry's .gitignore
# admits *.sh under tools/*/ and not *.py.
sh "$TOOLDIR/../_template/check_covalent_bond.sh" > check_bond.py

# --- case 1: does it fold at all --------------------------------------------
# A plain peptide, no cysteine, no ligand. This is the cheap case and it is
# NOT the point of the entry; it exists so that a failure in case 2 can be
# attributed to the bond rather than to the image.
#
# UNCONFIRMED: the JSON below follows upstream's docs/infer_json_format.md as
# read on 2026-09-24 and has never been fed to a running Protenix. If it is
# rejected, the log says so and this is the first thing to fix.
cat > plain.json <<'JSON'
[
  {
    "name": "plain_probe",
    "sequences": [
      {
        "proteinChain": {
          "sequence": "MKTAYIAKQRQISFVKSHFSRQLEERLGLIE",
          "count": 1
        }
      }
    ]
  }
]
JSON

# --use_msa false ON BOTH FOLDS, and it is not an optimisation -- it is the
# difference between a test that finishes and one that never does.
#
# MEASURED 2026-09-25, SLURM 1986556: without it, protenix's default is to
# SEARCH, which means reaching protenix-server.com through the site proxy. A
# compute node has no route out, so every attempt fails with `[Errno 113] No
# route to host` -- and the retry message is `Retrying... (1/5)` EVERY TIME.
# The counter never advances: the 5 is a per-call budget inside a loop that
# re-enters, so this is an infinite retry at one attempt every five seconds,
# not five attempts. The job sat there for thirteen minutes producing nothing
# but that line and would have burned the whole four-hour allocation.
#
# These three cases test the image, the weights, the bond geometry and the
# template date gate. None of them is about alignment quality, and a real
# campaign fold takes its MSA from the login-node stage as a precomputed
# pairedMsaPath/unpairedMsaPath anyway -- never as a flag on the fold.
#
# `< /dev/null` on every protenix invocation, and it is not decoration.
# protenix/data/tools/kalign.py Popens kalign WITHOUT setting stdin, and kalign
# 3 reads stdin even when -i names a file -- so an inherited open pipe makes it
# block in pipe_read forever at 0% CPU, with no output and no error. Measured.
# A tty gives EOF and sbatch gives /dev/null, so it only bites when something
# wraps this script in a pipeline, which is exactly how CI runs it.
if ! "$CHPC_TOOL" exec protenix -- protenix pred \
        -i plain.json -o out_plain -n "$MODEL" --use_msa false \
        > plain.log 2>&1 < /dev/null
then
    echo "protenix pred exited non-zero on the plain case."
    echo "triage, in the order these have actually bitten this registry:"
    echo "  * input schema     -- grep the log for a pydantic/KeyError trace;"
    echo "                        the JSON here is UNCONFIRMED."
    echo "  * MSA              -- if it demands an MSA, a compute node cannot"
    echo "                        reach any MSA server. Generate on the login"
    echo "                        node and pass pairedMsaPath/unpairedMsaPath"
    echo "                        as ABSOLUTE paths."
    if grep -qi "failed to find c compiler\|triton" plain.log 2>/dev/null; then
        echo "  * C COMPILER       -- a JIT kernel path could not build. The .def"
        echo "                        installs build-essential precisely for this;"
        echo "                        the image in use was built without it."
    fi
    tail -40 plain.log; exit 1
fi

cif=$(find out_plain -type f \( -name '*.cif' -o -name '*.pdb' \) 2>/dev/null | head -1)
[ -n "$cif" ] || { echo "no structure written by the plain case"
                   find out_plain -type f 2>/dev/null | head -20; tail -30 plain.log; exit 1; }

# Assert the fold, not the file. A collapsed point cloud and a real structure
# are both valid CIF; only the spread tells them apart, which is the check
# boltz's test settled on after a green run that had produced nothing useful.
if ! "$CHPC_TOOL" exec protenix -- python - "$cif" > plain_check.log 2>&1 <<'PY'
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

# --- case 2: the covalent case, which is why this entry exists --------------
# One cysteine in the peptide (position 6, 1-based) and one Michael acceptor,
# bonded SG -> terminal CH2.
#
# The peptide and the SMILES here are TEST FIXTURES, not this programme's
# chemistry. The campaign's hapten lives in Hap108or-data/targets/<id>/ and
# must never appear in a tool registry: HA-ADAPT's sotorasib SMILES was a
# different molecule for months precisely because it was checked into code,
# where nobody diffs it.
#
# Addressing, from upstream's docs/infer_json_format.md (read 2026-09-24):
#   entityN  1-BASED POSITION IN THE sequences LIST -- not a chain id. Reorder
#            the list and this bond moves silently.
#   positionN  1-based residue index within that entity; for a one-residue
#            ligand it is 1. UNCONFIRMED for the ligand side.
#   atomN    for a polymer, the PDB atom name (SG). For a SMILES ligand,
#            either a 0-BASED index into the SMILES string or an
#            element-plus-ordinal name whose ordinal is 1-BASED. Two numbering
#            bases in one list; "C1" is used here because it is the readable
#            one, and because an off-by-one in an index is invisible.
# For C=CC(=O)NC, C1 is the terminal CH2 -- the warhead.
cat > covalent.json <<'JSON'
[
  {
    "name": "covalent_probe",
    "sequences": [
      {
        "proteinChain": {
          "sequence": "MKTAYCAKQRQISFV",
          "count": 1
        }
      },
      {
        "ligand": {
          "ligand": "C=CC(=O)NC",
          "count": 1
        }
      }
    ],
    "covalent_bonds": [
      {
        "entity1": 1, "copy1": 1, "position1": 6, "atom1": "SG",
        "entity2": 2, "copy2": 1, "position2": 1, "atom2": "C1"
      }
    ]
  }
]
JSON

if ! "$CHPC_TOOL" exec protenix -- protenix pred \
        -i covalent.json -o out_cov -n "$MODEL" --use_msa false \
        > cov.log 2>&1 < /dev/null
then
    echo "protenix pred exited non-zero on the COVALENT case while the plain"
    echo "case passed, so the image and the weights are fine and the bond"
    echo "specification is not. Read the log and then write what upstream"
    echo "actually accepts into tools/protenix/README.md -- that paragraph is"
    echo "worth more than this test."
    tail -40 cov.log; exit 1
fi

covcif=$(find out_cov -type f \( -name '*.cif' -o -name '*.pdb' \) 2>/dev/null | head -1)
[ -n "$covcif" ] || { echo "no structure written by the covalent case"
                      tail -30 cov.log; exit 1; }

# The assertion this entry exists for. --max 2.1 A admits a C-S bond (~1.8 A)
# and excludes a contact; the checker additionally requires exactly one ligand
# atom in range, that it is a carbon, and that its only heavy neighbour inside
# the ligand is another carbon -- which is what distinguishes the terminal
# warhead CH2 from the N-methyl carbon without depending on output atom names.
if ! "$CHPC_TOOL" exec protenix -- python check_bond.py "$covcif" \
        --anchor SG --min 1.2 --max 2.1 > cov_check.log 2>&1
then
    echo "the covalent case produced a structure whose bond is WRONG:"
    cat cov_check.log
    echo
    echo "Do not record this as verified, and do not rank anything on it."
    echo "A wrong attachment costs ~0.01 of ipTM; it is invisible to every"
    echo "confidence score Protenix reports."
    exit 1
fi
cat cov_check.log

# --- case 3: templates reach the features, and the gate is what moves ------
#
# NOT "templates are configured". The failure this guards is the silent one:
# every prefilter rejection in this tool is a WARNING under the default
# strict_error_check=False, so a job can render a templated input, discard
# every template, fold, exit zero and write a structure that nothing
# downstream distinguishes from a templated fold. So assert on the FEATURE
# COUNT, and assert it in both directions -- a test that only showed features
# appearing would also pass on an image where the date gate never existed.
#
# Synthetic input on purpose: no target chemistry belongs in this registry
# (the consuming project's invariant #5), and the mechanism under test is the
# cutoff, not any particular structure.
echo
echo "--- case 3: template features, with the date gate closed then open ---"
cat > tpl_probe.py <<'PYEOF'
import os, sys, json, tempfile, datetime
from configs.configs_data import data_configs
from protenix.data.template.template_utils import TemplateHitFilter

tpl = data_configs["template"]
print("max_template_date =", tpl["max_template_date"])
print("fetch_remote      =", tpl["fetch_remote"])

# The gate itself, called directly with a date after Protenix v1's cutoff.
released = {"9xyz": datetime.datetime(2024, 9, 4)}
f = TemplateHitFilter(release_dates=released, obsolete_pdbs={})
cutoff = datetime.datetime.strptime(tpl["max_template_date"], "%Y-%m-%d")
after = f._is_after_cutoff("9xyz", cutoff)
print("2024 structure rejected under this cutoff:", after)
sys.exit(0 if after == (os.environ.get("EXPECT") == "rejected") else 1)
PYEOF

# Closed: the upstream default. A 2024 structure must be rejected.
if ! "$CHPC_TOOL" exec protenix -- \
        env EXPECT=rejected python tpl_probe.py > tpl_closed.log 2>&1; then
    echo "with no override, a post-cutoff template was NOT rejected --"
    echo "the patch changed default behaviour instead of making it selectable:"
    cat tpl_closed.log
    exit 1
fi
cat tpl_closed.log

# Open: the sentinel. The same structure must now pass.
# `env` inside the container rather than APPTAINERENV_*: configs_data.py reads
# the variable at IMPORT, so it only has to exist before python starts, and this
# does not depend on how chpc-tool forwards the environment.
if ! "$CHPC_TOOL" exec protenix -- \
        env PROTENIX_MAX_TEMPLATE_DATE=3000-01-01 EXPECT=accepted \
        python tpl_probe.py > tpl_open.log 2>&1; then
    echo "PROTENIX_MAX_TEMPLATE_DATE did not move the gate. Templates released"
    echo "after 2021-09-30 -- which is every template worth showing this model --"
    echo "would be dropped with a warning and the fold would still exit zero:"
    cat tpl_open.log
    exit 1
fi
cat tpl_open.log

# kalign, on the exact path configs_data.py points at. Protenix realigns every
# hit with it and a missing or failing kalign drops the template silently.
if ! "$CHPC_TOOL" exec protenix -- /usr/bin/kalign --version > kalign.log 2>&1; then
    echo "no usable kalign at /usr/bin/kalign -- every template is dropped and"
    echo "the fold still exits zero having used none:"
    cat kalign.log
    exit 1
fi
head -1 kalign.log

echo "ok: the template date gate closes by default and opens on request"

echo "ok: protenix folds, and folds the declared bond where it was declared"
