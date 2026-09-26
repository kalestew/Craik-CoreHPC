#!/usr/bin/env bash
# Fetch a Foldseek database onto the FAC share. Login node only -- compute
# nodes reach a proxy that denies the download hosts (doc 02).
#
#   corehpc/tools/foldseek/fetch-db.sh [<name> [<destination>]]
#
# <name> is any name `foldseek databases` lists (PDB, Alphafold/Swiss-Prot,
# Alphafold/Proteome, CATH50, ...); the default is PDB, the set a design is
# first searched against. The destination defaults to
# $CHPC_REFDATA/foldseek/<slug>, where the slug is the name lower-cased with
# `/` as `_`, and the database is the prefix <destination>/<slug>: the form
# `foldseek easy-search` takes, and what `chpc-tool export foldseek` puts in
# FOLDSEEK_DB_PDB for the default. Sizes on disk: PDB 3.1 GB (fetched
# 2026-09-26), Alphafold/Swiss-Prot several GB, Alphafold/UniProt far too big
# for this share without a conversation first.
#
# A partly-written database is worse than none, so the download lands in a
# temporary directory beside the destination and is moved into place only
# when foldseek exits 0.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

name="${1:-PDB}"
slug=$(printf '%s' "$name" | tr '[:upper:]/' '[:lower:]_')
eval "$("$CHPC_TOOL" export foldseek)"
dest="${2:-$FOLDSEEK_DB_DIR/$slug}"
echo "database: $name -> $dest/$slug"

parent=$(dirname "$dest")
mkdir -p "$parent"
stage=$(mktemp -d "$parent/.fetch-$slug.XXXXXX")
tmp="${CHPC_USER_SCRATCH:-${TMPDIR:-/tmp}}/foldseek-db-$$"
mkdir -p "$tmp"
trap 'rm -rf "$stage" "$tmp"' EXIT

"$CHPC_TOOL" exec foldseek -- foldseek databases "$name" "$stage/$slug" "$tmp" --threads 4
[ -f "$stage/$slug" ] || { echo "foldseek wrote no $slug in $stage" >&2; exit 1; }

rm -rf "$dest"
mv "$stage" "$dest"
trap 'rm -rf "$tmp"' EXIT
# The share's inheritable ACL denies the owner on anything new (doc 02,
# lab/README.md); repair it so you can read back what you just wrote.
case "$dest" in /mnt/fac/*) "$(dirname "$CHPC_TOOL")/chpc-fac-fixacl" "$dest" || true ;; esac
chmod -R g+rX,o-rwx "$dest"
echo "done: $(du -sh "$dest" | cut -f1) at $dest"
echo "check: chpc-tool doctor foldseek"
