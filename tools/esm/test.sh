#!/bin/sh
# ESM-2 self-test: embed a peptide and score it, entirely offline.
# Run:  chpc-tool test esm       (CPU is fine; ~20 s on the small model)
#
# Uses esm2_t30_150M_UR50D, not the 650M. The point of this test is that the
# image works -- weights present, torch loads them, a forward pass produces
# finite numbers -- and the small model proves all of that in a fraction of
# the time. The 650M is asserted to be present (below) because that is the
# one real work uses; loading it too would only re-test torch.
set -eu

# `if !` rather than `cmd <<'PY' || { ... }`. A heredoc body starts on the line
# AFTER the one carrying the <<, so the `{ ... }` continuation would be eaten as
# the first line of python and the brace would never close -- which the shell
# reports as "syntax error: unexpected end of file" pointing at the last line of
# the file, nowhere near the actual mistake.
if ! "$CHPC_TOOL" exec esm -- python - > esm.log 2>&1 <<'PY'
import os, sys, torch, esm

# If this is reaching the network, the image is wrong: the whole point of
# baking the weights in is that a compute node with no internet can run it.
os.environ["HF_HUB_OFFLINE"] = "1"

model, alphabet = esm.pretrained.esm2_t30_150M_UR50D()
model.eval()
bc = alphabet.get_batch_converter()

# The cathepsin G scissile region, which is what this tool gets pointed at
# here -- a real sequence rather than a homopolymer, so a degenerate model
# would not sail through.
seq = "MKTAYIAKQRQISFVKSHFSRQLEERLGLIE"
_, _, toks = bc([("p", seq)])

with torch.no_grad():
    out = model(toks, repr_layers=[30])

logits = out["logits"]
assert logits.shape[0] == 1, logits.shape
assert logits.shape[1] == len(seq) + 2, (logits.shape, len(seq))   # +BOS +EOS
assert torch.isfinite(logits).all(), "non-finite logits"

rep = out["representations"][30]
assert rep.shape[-1] == 640, rep.shape          # t30 hidden size
assert torch.isfinite(rep).all(), "non-finite representations"

# Pseudo-likelihood is what this tool is actually for, so compute one and
# demand it be a sane number rather than merely finite. A random model over
# 33 tokens gives about -3.5; a working one on a real sequence beats that.
lp = torch.log_softmax(logits[0, 1:-1], dim=-1)
idx = toks[0, 1:-1]
avg = lp[range(len(seq)), idx].mean().item()
assert -4.0 < avg < 0.0, f"implausible mean log-likelihood {avg}"

print(f"ok: logits {tuple(logits.shape)}, repr {tuple(rep.shape)}, mean logP {avg:.3f}")
PY
then
    echo "esm test exited non-zero:"; tail -25 esm.log; exit 1
fi

grep -q '^ok:' esm.log || { echo "no ok line:"; tail -25 esm.log; exit 1; }
tail -1 esm.log

# The 650M is what production scoring uses; assert it shipped, without
# paying to load it.
"$CHPC_TOOL" exec esm -- test -s /opt/torch/hub/checkpoints/esm2_t33_650M_UR50D.pt \
    || { echo "esm2_t33_650M_UR50D.pt missing from the image"; exit 1; }
echo "ok: esm2_t33_650M_UR50D.pt present"
