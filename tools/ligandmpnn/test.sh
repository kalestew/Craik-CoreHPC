#!/bin/sh
# LigandMPNN self-test: design sequences for a generated backbone.
# Run:  chpc-tool test ligandmpnn      (GPU job; passes on CPU too, slower)
#
# Exercises the ligand_mpnn model type rather than protein_mpnn, even though
# the test backbone has no ligand. LigandMPNN ships both, and the protein_mpnn
# path would pass on an image where only the ProteinMPNN weights downloaded --
# which is the failure this test exists to catch, since get_model_params.sh
# fetches the two sets separately.
set -eu
sh "$TOOLDIR/../_template/make_test_pdb.sh" 40 A > t.pdb

# Discover the checkpoint, but the glob must be `ligandmpnn_v_*`, NOT
# `ligandmpnn_*`. The model_params directory also holds
# ligandmpnn_sc_v_32_002_16.pt, which is the SIDE-CHAIN PACKING network --
# a different architecture belonging to --checkpoint_path_sc. It sorts first
# alphabetically, so `ligandmpnn_*.pt | head -1` selects it, and run.py then
# loads side-chain weights into the sequence-design model and dies with
#
#   RuntimeError: Error(s) in loading state_dict for ProteinMPNN:
#     Unexpected key(s): W_v_sc, W_torsions, features.W_XY_project_down1 ...
#
# which reads as a corrupt download rather than the wrong file. Prefer
# upstream's default (0.10 A noise) and fall back to any sequence-design
# checkpoint.
ckpt=$("$CHPC_TOOL" exec ligandmpnn -- sh -c \
    'ls -1 /opt/LigandMPNN/model_params/ligandmpnn_v_32_010_25.pt 2>/dev/null \
     || ls -1 /opt/LigandMPNN/model_params/ligandmpnn_v_*.pt 2>/dev/null | head -1' | tr -d '\r')
[ -n "$ckpt" ] || {
    echo "no ligandmpnn_v_*.pt in /opt/LigandMPNN/model_params -- get_model_params.sh"
    echo "fetched the ProteinMPNN set but not the LigandMPNN one"
    "$CHPC_TOOL" exec ligandmpnn -- ls -1 /opt/LigandMPNN/model_params/ || true
    exit 1; }
echo "using checkpoint $ckpt"

# `python` spelled out: ENTRY is only prepended when the first argument starts
# with a dash, so a bare script path makes apptainer try to exec the .py and
# fail with "permission denied" and no mention of a missing interpreter.
"$CHPC_TOOL" exec ligandmpnn -- python /opt/LigandMPNN/run.py \
    --model_type ligand_mpnn \
    --checkpoint_ligand_mpnn "$ckpt" \
    --pdb_path t.pdb --out_folder out \
    --number_of_batches 1 --batch_size 2 --temperature 0.1 --seed 37 \
    > lmpnn.log 2>&1 || { echo "run.py exited non-zero:"; tail -25 lmpnn.log; exit 1; }

# Check the artefact, not the exit code: a traceback printed under exit 0 is
# exactly what a status-only check misses.
fa=out/seqs/t.fa
"$CHPC_TOOL" exec ligandmpnn -- test -s "$fa" 2>/dev/null || test -s "$fa" || {
    echo "no sequences at $fa"; ls -R out 2>/dev/null | head -20; tail -25 lmpnn.log; exit 1; }

n=$(grep -c '^>' "$fa")
[ "$n" -ge 3 ] || { echo "expected 1 native + 2 designs, got $n records"; cat "$fa"; exit 1; }

# The designs must differ from each other, or sampling is not happening --
# a temperature-0.1 run that returns the same string twice usually means the
# model never loaded and something echoed the input back.
uniq_seqs=$(grep -v '^>' "$fa" | sort -u | wc -l)
[ "$uniq_seqs" -ge 2 ] || { echo "all $n records carry the same sequence"; cat "$fa"; exit 1; }

echo "ok: $n records, $uniq_seqs distinct sequences in $fa"
