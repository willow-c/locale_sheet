#!/usr/bin/env bash
set -euo pipefail

# format.sh - Run `dart format` across the repo (mac/linux)
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# prefer fvm when available
if command -v fvm >/dev/null 2>&1; then
    DART_CMD="fvm dart"
else
    DART_CMD="dart"
fi

echo "[locale_sheet] fetching packages..."
eval $DART_CMD pub get

echo "[locale_sheet] running dart format..."
eval $DART_CMD format .

echo "[locale_sheet] format complete."
