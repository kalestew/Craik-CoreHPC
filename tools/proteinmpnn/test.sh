#!/bin/sh
# ProteinMPNN self-test: design sequences for a generated backbone.
# Run:  chpc-tool test proteinmpnn      (GPU job; passes on CPU too, slower)
set -eu
mkdir -p in
sh "$TOOLDIR/../_template/make_test_pdb.sh" 40 A > in/t.pdb

# `python` is spelled out. ENTRY is only prepended when the first argument
# starts with a dash, so handing exec a bare script path makes apptainer try
# to execute the .py itself -- which fails with "FATAL: permission denied"
# and no hint that an interpreter was what was missing.
"$CHPC_TOOL" exec proteinmpnn -- python \
    /opt/ProteinMPNN/helper_scripts/parse_multiple_chains.py \
    --input_path=in --output_path=parsed.jsonl > mpnn.log 2>&1
test -s parsed.jsonl || { echo "parse_multiple_chains wrote nothing"; tail -15 mpnn.log; exit 1; }

"$CHPC_TOOL" exec proteinmpnn -- python \
    /opt/ProteinMPNN/protein_mpnn_run.py \
    --jsonl_path parsed.jsonl --out_folder out \
    --num_seq_per_target 2 --sampling_temp 0.1 --seed 37 --batch_size 1 >> mpnn.log 2>&1

# Check the output file, not the exit code: the point of the test is that
# sequences came out, and a tool that prints a traceback and exits 0 is exactly
# the failure a `test -x` style check misses.
test -s out/seqs/t.fa || { echo "no sequences written"; tail -20 mpnn.log; exit 1; }
n=$(grep -c '^>' out/seqs/t.fa)
[ "$n" -ge 3 ] || { echo "expected 1 native + 2 designs, got $n records"; exit 1; }
echo "ok: $n records in out/seqs/t.fa"
