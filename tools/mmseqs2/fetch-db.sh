#!/usr/bin/env bash
# Fetch an MMseqs2 sequence database onto the FAC share. Login node only --
# compute nodes reach a proxy that denies the download hosts (doc 02).
#
#   corehpc/tools/mmseqs2/fetch-db.sh [<name> [<destination>]]
#
# <name> is any name `mmseqs databases` lists (UniProtKB/Swiss-Prot, UniRef50,
# PDB, NR, ...); the default is UniProtKB/Swiss-Prot, small (about 300 MB
# built) and curated, which is the right first target for "what is this
# sequence". The destination defaults to $CHPC_REFDATA/mmseqs2/<slug>, where
# the slug is the name lower-cased, `/` as `_` and `uniprotkb_` dropped, so
# the default is $CHPC_REFDATA/mmseqs2/swiss-prot/swiss-prot: the prefix
# `mmseqs easy-search` takes, and what `chpc-tool export mmseqs2` puts in
# MMSEQS2_DB_SWISSPROT.
#
# Not this script's business: the ColabFold databases under
# $CHPC_REFDATA/mmseqs2/colabfold_uniref30_2302_envdb_202108 (about 1 TB),
# built 2026-09-24 by their own build_dbs.sbatch with the mmseqs inside
# colabfold_1.5.5.sif, for colabfold_search. Their index is written by that
# binary and is not a search target for the mmseqs2_18 image.
#
# The download lands in a temporary directory beside the destination and is
# moved into place only when mmseqs exits 0.
set -euo pipefail

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
CHPC_TOOL="${CHPC_TOOL:-$SELF_DIR/../../lab/bin/chpc-tool}"
[ -x "$CHPC_TOOL" ] || { echo "no chpc-tool at $CHPC_TOOL" >&2; exit 1; }

name="${1:-UniProtKB/Swiss-Prot}"
slug=$(printf '%s' "$name" | tr '[:upper:]/' '[:lower:]_' | sed 's/^uniprotkb_//')
eval "$("$CHPC_TOOL" export mmseqs2)"
dest="${2:-$MMSEQS2_DB_DIR/$slug}"
echo "database: $name -> $dest/$slug"

parent=$(dirname "$dest")
mkdir -p "$parent"
stage=$(mktemp -d "$parent/.fetch-$slug.XXXXXX")
tmp="${CHPC_USER_SCRATCH:-${TMPDIR:-/tmp}}/mmseqs-db-$$"
mkdir -p "$tmp"
trap 'rm -rf "$stage" "$tmp"' EXIT

"$CHPC_TOOL" exec mmseqs2 -- mmseqs databases "$name" "$stage/$slug" "$tmp" --threads 4
[ -f "$stage/$slug" ] || { echo "mmseqs wrote no $slug in $stage" >&2; exit 1; }

rm -rf "$dest"
mv "$stage" "$dest"
trap 'rm -rf "$tmp"' EXIT
case "$dest" in /mnt/fac/*) "$(dirname "$CHPC_TOOL")/chpc-fac-fixacl" "$dest" || true ;; esac
chmod -R g+rX,o-rwx "$dest"
echo "done: $(du -sh "$dest" | cut -f1) at $dest"
echo "check: chpc-tool doctor mmseqs2"
