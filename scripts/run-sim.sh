#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$ROOT_DIR/local.build.env"
OUT_FILE="$ROOT_DIR/bin/TopSnipes.prg"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Missing $CONFIG_FILE"
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG_FILE"

if [ -z "${CIQ_SDK_BIN:-}" ]; then
  echo "CIQ_SDK_BIN is required in local.build.env"
  exit 1
fi

DEVICE_ID="${DEVICE_ID:-fenix7}"

if [ ! -f "$OUT_FILE" ]; then
  echo "Missing $OUT_FILE. Run ./scripts/build.sh first."
  exit 1
fi

"$CIQ_SDK_BIN/monkeydo" "$OUT_FILE" "$DEVICE_ID"
