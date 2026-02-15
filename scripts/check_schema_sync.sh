#!/usr/bin/env bash
# Verifies that local schema files match the upstream ACP schema.
# Usage: ./scripts/check_schema_sync.sh [upstream_schema_dir]
# Exit 0 if in sync, exit 1 with details if any file differs.
set -euo pipefail

SOURCE_DIR="${1:-../agent-client-protocol/schema}"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)/schema"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "upstream schema directory not found: $SOURCE_DIR" >&2
  echo "pass the path as the first argument or clone agent-client-protocol next to this repo" >&2
  exit 1
fi

FILES=("schema.json" "schema.unstable.json" "meta.json" "meta.unstable.json")
DRIFTED=0

for file in "${FILES[@]}"; do
  upstream="$SOURCE_DIR/$file"
  local="$LOCAL_DIR/$file"

  if [ ! -f "$upstream" ]; then
    echo "SKIP  $file (not in upstream)"
    continue
  fi

  if [ ! -f "$local" ]; then
    echo "MISSING  $file (not in local schema/)"
    DRIFTED=1
    continue
  fi

  if ! diff -q "$upstream" "$local" > /dev/null 2>&1; then
    echo "DRIFT  $file differs from upstream"
    DRIFTED=1
  else
    echo "OK     $file"
  fi
done

if [ "$DRIFTED" -ne 0 ]; then
  echo ""
  echo "Schema drift detected. Run ./scripts/sync_schema.sh to update."
  exit 1
fi

echo ""
echo "All schema files are in sync."
