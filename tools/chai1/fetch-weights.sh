#!/usr/bin/env bash
# Fetch Chai-1's model weights onto the FAC share. Login node only --
# compute nodes reach a proxy that denies chaiassets.com (doc 02).
#
#   corehpc/tools/chai1/fetch-weights.sh
#
# ~6.7 GB in three parts, which is the thing to know about this tool:
#   1. six TorchScript model components, via chai's chai1_component()
#   2. a conformers pickle
#   3. a traced ESM-2 3B (5.6 GB), from a DIFFERENT url prefix, fetched
#      lazily on first use because --use-esm-embeddings defaults to true
# Miss (3) and the cache looks complete, passes a file count, and fails at
# the first real fold on a node with no internet.
#
# Destination is whatever `chpc-tool export chai1` resolves CHAI_DOWNLOADS_DIR
# to. It is not an argument: chpc-tool exec exports the registry's value
# unconditionally, so a value passed here would be overridden inside the
# container and the files would land somewhere other than reported.
#
# Weights are Apache-2.0, same as the code -- the older non-commercial Chai
# Community License was replaced -- so there is nothing for chpc-assets to
# gate.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

eval "$("$CHPC_TOOL" export chai1)"
dest="$CHAI_DOWNLOADS_DIR"
echo "destination: $dest"
mkdir -p "$dest"

target_file="$dest/.esm-target"

# ---------------------------------------------------------------- components
# Call chai_lab's OWN download functions rather than curl-ing the URLs. The
# component list and the URL template both live in chai_lab.utils.paths, so a
# version bump that renames a component is an error here rather than a silent
# 404 written into a .pt-named file.
"$CHPC_TOOL" exec chai1 -- python - "$target_file" <<'PY'
import sys
from chai_lab.utils.paths import (
    chai1_component, cached_conformers, download_if_not_exists, downloads_path,
)
print("downloads_path resolves to", downloads_path, flush=True)

COMPONENTS = [
    "feature_embedding.pt", "bond_loss_input_proj.pt", "token_embedder.pt",
    "trunk.pt", "diffusion_module.pt", "confidence_head.pt",
]
for key in COMPONENTS:
    p = chai1_component(key)
    print(f"  {p.stat().st_size:>13,}  {key}", flush=True)

download_if_not_exists(cached_conformers.url, cached_conformers.path)
print(f"  {cached_conformers.path.stat().st_size:>13,}  {cached_conformers.path.name}")

# Hand the ESM url and path out to the shell, read from chai's own module so
# an upstream rename is an ImportError here and not a 404 later.
from chai_lab.data.dataset.embeddings.esm import ESM_URL, esm_cache_folder
esm_path = esm_cache_folder / ESM_URL.rsplit("/", 1)[-1]
with open(sys.argv[1], "w") as fh:
    fh.write(f"{ESM_URL}\n{esm_path}\n")
PY

# ----------------------------------------------------------------- esm trace
# curl, not chai's downloader. download_if_not_exists is plain `requests` with
# no retry and no resume -- fine for a 500 MB component, not for 5.6 GB over a
# proxy. The first attempt died with
#   IncompleteRead(4464902144 bytes read, 1214038322 more expected)
# and discarded 4.4 GB, because it writes to a temp name and only renames on
# success. curl -C - resumes into the same .part instead.
esm_url=$(sed -n 1p "$target_file")
esm_path=$(sed -n 2p "$target_file")
rm -f "$target_file"
mkdir -p "$(dirname "$esm_path")"

if [ -s "$esm_path" ]; then
  echo "have $(basename "$esm_path")"
else
  echo "fetching $(basename "$esm_path") (5.6 GB, resumable)"
  # --retry-all-errors so a mid-stream disconnect is retried, not just an
  # HTTP status; -C - so each retry continues rather than restarting.
  curl -fL --retry 10 --retry-delay 5 --retry-all-errors -C - \
       -o "$esm_path.part" "$esm_url"
  mv "$esm_path.part" "$esm_path"
fi

# ---------------------------------------------------------------- verify all
# torch.jit.load is the real check: every one of these is a TorchScript
# archive that either deserialises or does not, which needs no manifest --
# the same argument as the zipfile CRC check in the rfdiffusion fetch.
"$CHPC_TOOL" exec chai1 -- python - <<'PY'
import sys, torch
from chai_lab.utils.paths import chai1_component
from chai_lab.data.dataset.embeddings.esm import ESM_URL, esm_cache_folder

COMPONENTS = [
    "feature_embedding.pt", "bond_loss_input_proj.pt", "token_embedder.pt",
    "trunk.pt", "diffusion_module.pt", "confidence_head.pt",
]
targets = [(k, chai1_component(k)) for k in COMPONENTS]
esm_path = esm_cache_folder / ESM_URL.rsplit("/", 1)[-1]
targets.append((esm_path.name, esm_path))

bad = 0
for name, p in targets:
    try:
        torch.jit.load(str(p), map_location="cpu")
    except Exception as e:
        print(f"CORRUPT {name}: {type(e).__name__}: {e}", file=sys.stderr)
        bad += 1
if bad:
    print(f"FAILED: {bad} of {len(targets)} artefacts do not load", file=sys.stderr)
    sys.exit(1)
print(f"ok: all {len(targets)} TorchScript artefacts deserialise")
PY

# chai returns before taking its lock when the file already exists, so these
# are inert once the download is done.
find "$dest" -name '*.download_lock' -delete

echo
du -sh "$dest"
find "$dest" -type f -printf '%13s  %p\n' | sort -k2
