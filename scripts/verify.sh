#!/usr/bin/env bash
set -euo pipefail

# verify.sh - run format -> analyze -> test -> coverage (mac/linux)
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if command -v fvm >/dev/null 2>&1; then
    DART_CMD="fvm dart"
else
    DART_CMD="dart"
fi

echo "[locale_sheet] running clean..."
if [ -f ./scripts/clean.sh ] || [ -x ./scripts/clean.sh ]; then
    ./scripts/clean.sh
else
    echo "[locale_sheet] ./scripts/clean.sh not found, skipping clean"
fi

echo "[locale_sheet] running format..."
./scripts/format.sh

echo "[locale_sheet] running static analysis..."
eval $DART_CMD analyze

echo "[locale_sheet] running tests..."
eval $DART_CMD test

echo "[locale_sheet] running coverage..."
./scripts/coverage.sh

echo "[locale_sheet] verify complete."
