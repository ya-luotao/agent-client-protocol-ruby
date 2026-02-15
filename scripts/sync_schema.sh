#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="${1:-../agent-client-protocol/schema}"
TARGET_DIR="$(cd "$(dirname "$0")/.." && pwd)/schema"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "schema source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$SOURCE_DIR/schema.json" "$SOURCE_DIR/schema.unstable.json" "$SOURCE_DIR/meta.json" "$SOURCE_DIR/meta.unstable.json" "$TARGET_DIR/"

echo "Synced ACP schema files from $SOURCE_DIR to $TARGET_DIR"
