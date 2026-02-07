#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/local.build.env"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Missing $CONFIG_FILE"
  echo "Copy local.build.env.example to local.build.env and set your paths."
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${CIQ_SDK_BIN:-}" ] || [ -z "${DEVELOPER_KEY_PATH:-}" ]; then
  echo "CIQ_SDK_BIN and DEVELOPER_KEY_PATH are required in local.build.env"
  exit 1
fi

DEVICE_ID="${DEVICE_ID:-fenix7}"
OUT_DIR="$ROOT_DIR/bin"
OUT_FILE="$OUT_DIR/TopSnipes.prg"

mkdir -p "$OUT_DIR"

"$CIQ_SDK_BIN/monkeyc" \
  -f "$ROOT_DIR/monkey.jungle" \
  -o "$OUT_FILE" \
  -y "$DEVELOPER_KEY_PATH" \
  -d "$DEVICE_ID"

echo "Build complete: $OUT_FILE"
