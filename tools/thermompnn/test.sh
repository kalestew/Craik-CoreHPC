#!/bin/sh
# ThermoMPNN self-test: reproduce upstream's own reference prediction.
# Run:  chpc-tool test thermompnn            (GPU node, ~60 s)
#
# THE FIXTURE IS UPSTREAM'S, AND SO IS THE ANSWER. The repo ships both
# examples/2OCJ.pdb and examples/ThermoMPNN_inference_2OCJ.csv -- the input and
# the output its authors got from it -- so this test does not have to invent a
# criterion for "a plausible ddG". It re-runs the prediction and correlates
# against the shipped reference, which is the strongest check available to any
# entry in this registry: a number this image produces is compared with a
# number the people who trained the model produced.
#
# That also settles the question the image had to guess at. This build
# deliberately ignores upstream's pins -- they ask for torch 2.5.1 on CUDA
# 12.1, which would cap the image below the Blackwell nodes -- and runs torch
# 2.14 on CUDA 13.2 instead. Whether that changes the ANSWERS is not something
# to reason about; it is something to measure, and r > 0.99 against the
# reference is the measurement.
#
# Correlation, not equality. Different torch and different cuDNN reorder
# floating-point reductions, so the last few digits will differ and demanding
# equality would fail on a correct image. Correlation over 3880 predictions is
# insensitive to that and ruinous to anything actually broken.
set -eu

: "${THERMOMPNN_DIR:?not set -- run through chpc-tool, which exports it}"
: "${THERMOMPNN_CKPT:?not set -- run through chpc-tool, which exports it}"

REF="$THERMOMPNN_DIR/examples/ThermoMPNN_inference_2OCJ.csv"
PDB="$THERMOMPNN_DIR/examples/2OCJ.pdb"

# --- the GPU has to be real ---------------------------------------------------
# ThermoMPNN's own inference script does
#   torch.device("cuda" if torch.cuda.is_available() else "cpu")
# so a CPU-only torch does not fail, it just predicts slowly and correctly --
# which is upstream's documented install failure ("may cause pytorch to install
# incorrectly (CPU version instead of GPU version)"). Assert the GPU before
# spending a minute finding out.
if ! "$CHPC_TOOL" exec thermompnn -- python - > gpu.log 2>&1 <<'PY'
import torch
assert torch.version.cuda is not None, "CPU-only torch build"
assert torch.cuda.is_available(), (
    "no CUDA device visible. This test needs a GPU node: "
    "srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 1:00:00 --pty bash -l")
# is_available() is True on a device the kernels do not cover, so launch one.
a = torch.randn(256, 256, device="cuda")
(a @ a).sum().item()
cc = torch.cuda.get_device_capability()
print("torch %s cuda %s on %s (sm_%d%d)"
      % (torch.__version__, torch.version.cuda,
         torch.cuda.get_device_name(0), cc[0], cc[1]))
print("arch flags", torch._C._cuda_getArchFlags())
PY
then
    echo "GPU check failed:" >&2; tail -20 gpu.log >&2; exit 1
fi
cat gpu.log

# --- run the prediction upstream shipped the answer for -----------------------
# custom_inference.py writes ThermoMPNN_inference_<pdbid>.csv into --out_dir.
if ! "$CHPC_TOOL" exec thermompnn -- python \
        "$THERMOMPNN_DIR/analysis/custom_inference.py" \
        --pdb "$PDB" --chain A --model_path "$THERMOMPNN_CKPT" --out_dir . \
        > infer.log 2>&1
then
    echo "custom_inference.py failed:" >&2
    tail -30 infer.log >&2
    echo >&2
    echo "A traceback inside train_thermompnn is expected to be an IMPORT of" >&2
    echo "wandb, not a training attempt: custom_inference imports that module" >&2
    echo "for TransferModelPL. The image installs wandb and sets" >&2
    echo "WANDB_MODE=disabled for exactly this." >&2
    exit 1
fi
test -s ThermoMPNN_inference_2OCJ.csv || {
    echo "no ThermoMPNN_inference_2OCJ.csv was written"; tail -20 infer.log; exit 1; }

# --- compare against upstream's reference -------------------------------------
if ! "$CHPC_TOOL" exec thermompnn -- python - \
        ThermoMPNN_inference_2OCJ.csv "$REF" > compare.log 2>&1 <<'PY'
import sys
import numpy as np
import pandas as pd

got = pd.read_csv(sys.argv[1])
ref = pd.read_csv(sys.argv[2])

# 1. Shape. 2OCJ chain A gives every non-wildtype substitution at every
#    position; upstream's reference has 3880 of them.
assert len(ref) == 3880, ("the reference itself is not 3880 rows", len(ref))
assert len(got) == len(ref), ("row count", len(got), "vs reference", len(ref))
for col in ("ddG_pred", "position", "wildtype", "mutation"):
    assert col in got.columns, (col, list(got.columns))

# 2. Same mutations, in the same order. If the parse or the enumeration drifted,
#    a correlation would be comparing unrelated pairs and could still look fine.
key = ["position", "wildtype", "mutation"]
assert got[key].equals(ref[key]), "the mutation list differs from the reference"

g = got["ddG_pred"].to_numpy(dtype=float)
r = ref["ddG_pred"].to_numpy(dtype=float)

# 3. The predictions actually vary. A model loaded with the wrong weights, or
#    one whose features never reached it, tends to emit near-constant output --
#    which correlates with nothing and would fail check 4, but says so less
#    clearly than this does.
assert g.std() > 0.5, ("predictions barely vary; std = %.4f" % g.std())

# 4. THE CHECK THIS FILE EXISTS FOR. Correlate with upstream's own answer.
pearson = float(np.corrcoef(g, r)[0, 1])
max_abs = float(np.abs(g - r).max())
mean_abs = float(np.abs(g - r).mean())
print("pearson r vs upstream reference : %.6f" % pearson)
print("mean |difference|               : %.4f kcal/mol" % mean_abs)
print("max  |difference|               : %.4f kcal/mol" % max_abs)
assert pearson > 0.99, (
    "r = %.4f against upstream's reference prediction. This image runs a "
    "different torch and CUDA than upstream pinned, on purpose; r > 0.99 is "
    "what says that choice did not change the answers. It did." % pearson)

# 5. The sign convention, asserted rather than trusted, because getting it
#    backwards is the single most damaging mistake available with this tool:
#    a stability consensus that averages a sign-flipped ThermoMPNN against
#    FoldX and Rosetta cancels instead of agreeing.
#    POSITIVE ddG_pred IS DESTABILISING here. Upstream negates the Megascale
#    ddG_ML at training time (datasets.py), so the sign is the opposite of that
#    dataset's. Proline substitutions break backbone hydrogen bonding and are
#    destabilising on average, so their mean must sit ABOVE the overall mean.
overall = float(got["ddG_pred"].mean())
to_pro = float(got.loc[got["mutation"] == "P", "ddG_pred"].mean())
print("mean ddG_pred all substitutions : %+.4f" % overall)
print("mean ddG_pred X->Pro            : %+.4f" % to_pro)
assert to_pro > overall, (
    "substitutions to proline are not destabilising relative to the mean "
    "(%.4f vs %.4f). Either the sign convention flipped upstream or the "
    "model is not the one this test was written against." % (to_pro, overall))

# 6. And a specific, large, known contrast from the reference: a buried
#    isoleucine to aspartate against a small-to-large hydrophobic swap.
def one(df, pos, wt, mut):
    row = df[(df["position"] == pos) & (df["wildtype"] == wt) & (df["mutation"] == mut)]
    assert len(row) == 1, (pos, wt, mut, len(row))
    return float(row["ddG_pred"].iloc[0])

i159d = one(got, 159, "I", "D")
a63i = one(got, 63, "A", "I")
print("I159D (buried I->D)             : %+.4f" % i159d)
print("A63I  (small->large hydrophobic): %+.4f" % a63i)
assert i159d - a63i > 6.0, (
    "the spread between the reference's most destabilising and most "
    "stabilising substitutions collapsed: %.3f - %.3f = %.3f, expected > 6"
    % (i159d, a63i, i159d - a63i))
print("spread                          : %.4f kcal/mol" % (i159d - a63i))
PY
then
    echo "comparison against upstream's reference failed:" >&2
    tail -30 compare.log >&2
    exit 1
fi
cat compare.log

echo
echo "ok: 3880 predictions over the same mutation list as upstream's shipped"
echo "    reference, correlating above 0.99 with it, on a torch and CUDA this"
echo "    build chose over upstream's pins. Positive ddG_pred is DESTABILISING,"
echo "    and 'position' is a 0-based index into the parsed chain, NOT a PDB"
echo "    residue number -- map it back before quoting a mutation to anyone."
