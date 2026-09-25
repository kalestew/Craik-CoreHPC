#!/bin/sh
# Chai-1 self-test: fold a short peptide end to end.
# Run:  chpc-tool test chai1
#
# MUST run on an L40S or H100/H200. Measured, not inferred: chai's torch is
# 2.6.0+cu124 and torch._C._cuda_getArchFlags() reports
#   sm_50 sm_60 sm_70 sm_75 sm_80 sm_86 sm_90
# with no sm_120, so on a Blackwell node (ggpu1-[13-19]) this dies at the
# first kernel launch. Ask for --gres=gpu:nvidia_l40s:1, never --gres=gpu:1.
set -eu

: "${CHAI_DOWNLOADS_DIR:?not set -- run through chpc-tool, which exports it}"

# All three parts of the cache, because a missing ESM trace is the failure
# that otherwise shows up minutes into a fold rather than here. The trace is
# a separate 5.6 GB download from a different URL than the six components;
# tools/chai1/fetch-weights.sh gets all of it.
for f in models_v2/trunk.pt models_v2/diffusion_module.pt \
         models_v2/confidence_head.pt conformers_v1.apkl \
         esm/traced_sdpa_esm2_t36_3B_UR50D_fp16.pt; do
    test -s "$CHAI_DOWNLOADS_DIR/$f" || {
        echo "missing $CHAI_DOWNLOADS_DIR/$f"
        echo "fetch with: tools/chai1/fetch-weights.sh"; exit 1; }
done

# chai's header grammar is 'protein|name=...' (inference_dataset.py:239-246).
# A plain '>seq' header parses as a fasta record and then fails entity-type
# dispatch, which is a confusing error for a simple mistake.
cat > in.fasta <<'EOF'
>protein|name=test-peptide
MKTAYIAKQRQISFVKSHFSRQLEERLGLIE
EOF

# Cheapest settings that still exercise every stage. Defaults are 3 trunk
# recycles, 200 diffusion timesteps and 5 samples; this is one of each and 20
# steps, which runs the same code paths in a fraction of the time. Not
# --no-use-esm-embeddings: leaving embeddings ON is the point, since that is
# the path that needs the 5.6 GB trace and the one most likely to be missing.
if ! "$CHPC_TOOL" exec chai1 -- chai-lab fold \
        --num-trunk-recycles 1 --num-diffn-timesteps 20 \
        --num-diffn-samples 1 --num-trunk-samples 1 --seed 37 \
        in.fasta out > chai.log 2>&1
then
    echo "chai-lab fold exited non-zero:"
    if grep -q "no kernel image is available" chai.log; then
        echo
        echo ">>> sm_120: the job landed on a Blackwell node. chai's torch is"
        echo ">>> cu124 and has no kernels for it. Use --gres=gpu:nvidia_l40s:1."
        echo
    fi
    tail -30 chai.log; exit 1
fi

cif=$(ls -1 out/*.cif 2>/dev/null | head -1 || true)
[ -n "$cif" ] || { echo "no .cif written"; ls -R out 2>/dev/null | head -20; tail -30 chai.log; exit 1; }

# Assert on the structure, not the exit code. Chai can write a well-formed
# file of degenerate coordinates and exit 0.
n_ca=$(grep -c ' CA ' "$cif" || true)
[ "$n_ca" -ge 31 ] || { echo "expected >=31 CA records for a 31-mer, got $n_ca"; exit 1; }

# Check the COORDINATE FIELDS, not the whole file. `grep -i nan` over a CIF
# matches `_chem_comp.ma_provenance` -- "nan" inside "provenance" -- and
# fails a perfectly good structure. In chai's _atom_site layout the Cartesian
# columns are fields 11-13:
#   ATOM 1 N N . MET 1 1 ? A -22.294 4.872 -1.149 1.000 1 A MET 82.550 1
# Capture the output; do NOT write `if awk ... | head -3; then`. In a
# pipeline the `if` tests the LAST command's status, which is head's, and
# head always succeeds -- so that form reports a failure on every run,
# including a perfect one. It did exactly that here before this fix.
bad=$(awk '/^ATOM/ { for (i = 11; i <= 13; i++)
                       if ($i !~ /^-?([0-9]+\.?[0-9]*|\.[0-9]+)$/) print }' "$cif" | head -3)
if [ -n "$bad" ]; then
    echo "non-numeric coordinates in $cif:"; echo "$bad"; exit 1
fi

# A folded peptide is not a point cloud at the origin: demand real spread.
# This is what separates "wrote a CIF" from "ran the diffusion module".
spread=$(awk '/ CA /{n++; x+=$11; y+=$12; z+=$13; xx+=$11*$11; yy+=$12*$12; zz+=$13*$13}
              END{ if(n<2){print 0; exit}
                   vx=xx/n-(x/n)^2; vy=yy/n-(y/n)^2; vz=zz/n-(z/n)^2;
                   printf "%.2f", sqrt(vx+vy+vz) }' "$cif")
awk -v s="$spread" 'BEGIN{ exit !(s > 3.0) }' \
    || { echo "CA radius of gyration $spread A is too small to be a fold"; exit 1; }

echo "ok: $n_ca CA records in $(basename "$cif"), CA spread ${spread} A"

# --- case 2: the covalent case, and the NAME the bond landed on -------------
#
# Case 1 folds a bare peptide. It proves the image starts, the weights load and
# the diffusion module runs, and it says NOTHING about the failure that got
# every HA-ADAPT chai1 result quarantined: 1,726 structures in which the free
# drug was folded while DECLARED bonded, the peptide cysteine attached to an
# aromatic ring carbon at 1.68 A instead of to the warhead 13.59 A away. Both
# distances are bond-plausible. ipTM moved 0.710 -> 0.698 between the wrong
# structure and the right one, so no confidence score separates them.
#
# The root cause was a NAME read in the wrong vocabulary -- `C25` is the
# warhead in CCD naming and an aromatic ring CH in SMILES order -- and Chai-1
# is the tool most exposed to it, because it has no CCD input path at all and
# its ligand atom names come from the RDKit version pinned inside THIS image.
# So the assertion has to be made against this image, at qualification time,
# or it is not an assertion about anything that will still be true after a
# rebuild.
#
# FIXTURE CHEMISTRY, not the campaign's. The programme's hapten lives in the
# data repo and must never appear in a tool registry (the consuming project's
# invariant #5). One cysteine at position 6 and one Michael acceptor is the
# same shape and costs a fraction of the time.
echo
echo "--- case 2: a declared covalent bond, and the atom it reached ---"

sh "$TOOLDIR/../_template/check_covalent_bond.sh" > check_bond.py

cat > cov.fasta <<'EOF'
>protein|name=pep
MKTAYCAKQRQISFV
>ligand|name=lig
C=CC(=O)NC
EOF

# COMMA-delimited, with a header. The .m8 template table next door is TAB
# separated with no header -- the same tool, two delimiters, and getting this
# one wrong yields a file chai parses into zero restraints and folds anyway.
# Chains are assigned POSITIONALLY from the FASTA: entity 1 -> A, entity 2 -> B.
# The atom follows an `@`, and residues are 1-indexed.
#
# `@C1` is the terminal CH2 of C=CC(=O)NC. Chai names a SMILES ligand's atoms
# element-plus-1-based-ordinal in RDKit atom order, so the carbons of this
# SMILES are C1 C2 C3 (backbone, in written order) and C4 (the N-methyl).
cat > cov.restraints <<'EOF'
chainA,res_idxA,chainB,res_idxB,connection_type,confidence,min_distance_angstrom,max_distance_angstrom,comment,restraint_id
A,C6@SG,B,@C1,covalent,1.0,0.0,0.0,peptide-hapten,bond1
EOF

if ! "$CHPC_TOOL" exec chai1 -- chai-lab fold \
        --constraint-path cov.restraints \
        --num-trunk-recycles 1 --num-diffn-timesteps 40 \
        --num-diffn-samples 1 --num-trunk-samples 1 --seed 37 \
        cov.fasta out_cov > cov.log 2>&1
then
    echo "chai-lab fold exited non-zero on the COVALENT case while the plain"
    echo "case passed, so the image and the weights are fine and the restraint"
    echo "file is not. Read the log, then write what chai actually accepts into"
    echo "tools/chai1/README.md -- that paragraph is worth more than this test."
    tail -40 cov.log; exit 1
fi

covcif=$(ls -1 out_cov/*.cif 2>/dev/null | head -1 || true)
[ -n "$covcif" ] || { echo "no .cif written by the covalent case"
                      ls -R out_cov 2>/dev/null | head -20; tail -30 cov.log; exit 1; }

# Geometry first, and by CONNECTIVITY rather than by name: exactly one ligand
# heavy atom within bonding distance of the SG, it is a carbon, and its only
# heavy neighbour inside the ligand is another carbon. That last clause is what
# separates a terminal warhead CH2 from the N-methyl carbon without trusting
# any label, so it stays true whatever this image decides to call things.
if ! "$CHPC_TOOL" exec chai1 -- python check_bond.py "$covcif" \
        --anchor SG --min 1.2 --max 2.1 > cov_check.log 2>&1
then
    echo "the covalent case produced a structure whose bond is WRONG:"
    cat cov_check.log
    echo
    echo "Do not record this as verified and do not rank anything on it."
    echo "A wrong attachment costs ~0.01 of ipTM; every confidence score"
    echo "Chai-1 reports is blind to it."
    exit 1
fi
cat cov_check.log

# THEN the name, which is the half the geometry cannot cover. A bond that is
# chemically sound but landed on a carbon this image calls something else means
# the coordinator and the tool disagree about the vocabulary -- and a
# coordinator that renders `@C1` while the image numbers its atoms differently
# writes a restraint that silently addresses the wrong carbon.
# check_bond.py prints: `ok: SG-<atom> <d> A (...)`. Chai suffixes every ligand
# atom with its entity copy (`C1_1`), so strip that before comparing.
bonded=$(sed -n 's/^ok: SG-\([^ ]*\) .*/\1/p' cov_check.log | head -1)
bare=$(echo "$bonded" | sed 's/_[0-9][0-9]*$//')
echo "chai-lab named the bonded atom: $bonded  (bare: $bare)"
if [ "$bare" != "C1" ]; then
    echo
    echo "THE BOND IS SOUND AND THE NAME IS NOT. The restraint asked for C1 --"
    echo "the terminal CH2 of C=CC(=O)NC in element-plus-ordinal RDKit order --"
    echo "and the atom the bond reached is called '$bare' in this image."
    echo "Chai-1's ligand atom names come from the RDKit pinned inside the"
    echo "image, so a rebuild can renumber them. Every restraint this project"
    echo "renders addresses atoms BY NAME, so until the vocabularies agree"
    echo "again, a rendered bond may land on the wrong carbon and still fold,"
    echo "still exit zero and still score well. That is the exact shape of the"
    echo "defect behind the quarantined corpus."
    exit 1
fi

# And the whole ligand's naming, printed rather than merely checked: the next
# person to debug a vocabulary drift wants the list, not a boolean.
"$CHPC_TOOL" exec chai1 -- python - "$covcif" <<'PY' || exit 1
import sys
from check_bond import parse, STANDARD, IONS
atoms = parse(sys.argv[1])
lig = [a for a in atoms
       if a["resname"] not in STANDARD and a["resname"] not in IONS
       and a["element"] not in ("H", "D")]
names = [a["name"] for a in lig]
print("ligand heavy atoms as this image names them: %s" % " ".join(names))
bare = [n.rsplit("_", 1)[0] if n.rsplit("_", 1)[-1].isdigit() else n for n in names]
want = {"C1", "C2", "C3", "C4", "O1", "N1"}
got = set(bare)
if got != want:
    print("FAIL: expected %s, got %s" % (sorted(want), sorted(got)))
    raise SystemExit(1)
print("ok: the six heavy atoms carry the element-plus-ordinal names the "
      "coordinator renders against")
PY

echo
echo "ok: chai1 folds, folds the declared bond where it was declared, and"
echo "    names the ligand atoms the way the restraint renderer assumes"
