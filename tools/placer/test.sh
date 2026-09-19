#!/bin/sh
# PLACER self-test: stochastic repacking of a real ligand pocket.
# Run:  chpc-tool test placer
#
# MUST run on an L40S or H100/H200. Measured in the image: torch 2.3.1,
# cuda 12.1, arch flags sm_50..sm_90 with no sm_120, so on a Blackwell node
# (ggpu1-[13-19]) this dies at the first kernel launch. Ask for
# --gres=gpu:nvidia_l40s:1, never a bare --gres=gpu:1.
set -eu

: "${PLACER_DIR:?not set -- run through chpc-tool, which exports it}"

test -f "$PLACER_DIR/run_PLACER.py" || { echo "no run_PLACER.py under $PLACER_DIR"; exit 1; }
test -s "$PLACER_DIR/weights/PLACER_model_1.pt" || {
    echo "no weights under $PLACER_DIR/weights"
    echo "the image is an ENVIRONMENT; the checkout and weights live on FAC:"
    echo "  git clone https://github.com/baker-laboratory/PLACER \$CHPC_LAB/data/placer"; exit 1; }

# Upstream's own example (examples/commandline_examples.sh:141) rather than a
# generated backbone: PLACER's job is ligand-pocket repacking, and
# run_PLACER.py requires --target_res when the input has no ligands at all.
# Testing the thing the tool is for beats testing the path around it.
IN="$PLACER_DIR/examples/inputs/4dtz.cif"
test -f "$IN" || { echo "missing example input $IN"; exit 1; }

N=3
# `python` spelled out: ENTRY is not prepended in front of a bare script path.
if ! "$CHPC_TOOL" exec placer -- python "$PLACER_DIR/run_PLACER.py" \
        --ifile "$IN" --odir out --suffix selftest -n "$N" \
        --predict_ligand D-LDP-501 --rerank prmsd > placer.log 2>&1
then
    echo "run_PLACER.py exited non-zero:"
    if grep -q "no kernel image is available" placer.log; then
        echo
        echo ">>> sm_120: the job landed on a Blackwell node. This image is"
        echo ">>> cu121/dgl. Use --gres=gpu:nvidia_l40s:1."
        echo
    fi
    tail -30 placer.log; exit 1
fi

pdb=$(find out -name '*.pdb' -type f 2>/dev/null | head -1)
[ -n "$pdb" ] || { echo "no .pdb written"; find out -type f 2>/dev/null | head; tail -30 placer.log; exit 1; }

# The ensemble must actually contain N models. This is the assertion that
# encodes the trap: PLACER's output is MULTI-MODEL, and a scorer that reads
# model 0 will happily score sample 1 n times and report a preorganisation
# fraction of exactly 0.000 or 1.000 -- the degeneracy PLACER was added to
# remove. If this count is ever 1, every downstream number is meaningless.
n_models=$(grep -c '^MODEL' "$pdb" || true)
[ "$n_models" -eq "$N" ] || {
    echo "expected $N MODEL records in $pdb, got $n_models"
    echo "PLACER output must be a multi-model ensemble; a single model means"
    echo "sampling did not happen and any spread computed from it is fictional"
    exit 1; }

# And the samples must differ. Identical models would satisfy the count while
# still being one structure repeated -- the same failure wearing a disguise.
uniq_first=$(awk '/^MODEL/{m++} m && /^(ATOM|HETATM)/ {print m, substr($0,31,24)}' "$pdb" \
             | awk '{print $2, $3, $4}' | sort -u | wc -l)
n_atoms=$(awk '/^MODEL/{m++} m==1 && /^(ATOM|HETATM)/{c++} END{print c+0}' "$pdb")
[ "$uniq_first" -gt "$n_atoms" ] || {
    echo "all $N models share identical coordinates ($uniq_first distinct positions"
    echo "across $n_atoms atoms) -- PLACER sampled nothing"; exit 1; }

csv=$(find out -name '*.csv' -type f 2>/dev/null | head -1)
[ -n "$csv" ] && rows=$(( $(wc -l < "$csv") - 1 )) || rows="?"

echo "ok: $n_models models in $(basename "$pdb"), coordinates differ between samples, $rows score rows"
