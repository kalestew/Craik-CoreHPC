#!/usr/bin/env bash
# Fetch Chai-1's model components onto the FAC share. Login node only --
# compute nodes reach a proxy that denies chaiassets.com (doc 02).
#
#   corehpc/tools/chai1/fetch-weights.sh
#
# Destination is whatever `chpc-tool export chai1` resolves CHAI_DOWNLOADS_DIR
# to, which is $CHPC_REFDATA/chai1. It is not an argument: chpc-tool exec
# exports the registry's value unconditionally, so a value passed here would
# be overridden inside the container and the files would land somewhere other
# than where this script said they went.
#
# Weights are Apache-2.0, same as the code -- the older non-commercial Chai
# Community License was replaced -- so there is nothing licensed here and
# nothing for chpc-assets to gate.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

eval "$("$CHPC_TOOL" export chai1)"
dest="$CHAI_DOWNLOADS_DIR"
echo "destination: $dest"
mkdir -p "$dest"

# Call chai_lab's OWN download functions rather than curl-ing the URLs. The
# component list and the URL template both live in chai_lab.utils.paths, so
# going through them means a version bump that renames a component is a
# different error here than a silent 404 into a .pt-named HTML file. The six
# keys are the ones chai1.py:633-638 loads.
"$CHPC_TOOL" exec chai1 -- python - <<'PY'
import logging, sys
logging.basicConfig(level=logging.INFO, format="%(message)s")
from chai_lab.utils.paths import (
    chai1_component, cached_conformers, download_if_not_exists, downloads_path,
)

print("downloads_path resolves to", downloads_path, flush=True)

COMPONENTS = [
    "feature_embedding.pt",
    "bond_loss_input_proj.pt",
    "token_embedder.pt",
    "trunk.pt",
    "diffusion_module.pt",
    "confidence_head.pt",
]

for key in COMPONENTS:
    p = chai1_component(key)
    print(f"  {p.stat().st_size:>13,}  {key}", flush=True)

download_if_not_exists(cached_conformers.url, cached_conformers.path)
print(f"  {cached_conformers.path.stat().st_size:>13,}  {cached_conformers.path.name}")

# torch.jit.load is the real check. A truncated download is still a file, and
# every one of these is a TorchScript archive that either deserialises or does
# not -- which is the same kind of structural check the rfdiffusion fetch uses
# zipfile for, and it needs no manifest either.
import torch
bad = 0
for key in COMPONENTS:
    p = chai1_component(key)
    try:
        torch.jit.load(str(p), map_location="cpu")
    except Exception as e:
        print(f"CORRUPT {key}: {type(e).__name__}: {e}", file=sys.stderr)
        bad += 1
if bad:
    print(f"FAILED: {bad} of {len(COMPONENTS)} components do not load", file=sys.stderr)
    sys.exit(1)
print(f"ok: all {len(COMPONENTS)} components deserialise")
PY

echo
du -sh "$dest"
find "$dest" -type f | sort | sed 's/^/  /'
