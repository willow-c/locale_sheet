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

echo "[locale_sheet] running dart fix check..."
# Run dart fix in dry-run mode to check if any fixes are needed
FIX_OUTPUT=$(eval $DART_CMD fix --dry-run 2>&1)
FIX_EXIT_CODE=$?
echo "$FIX_OUTPUT"
# First, fail if dart fix itself failed (non-zero exit code)
if [ $FIX_EXIT_CODE -ne 0 ]; then
    echo "[locale_sheet] ERROR: 'dart fix --dry-run' failed with exit code $FIX_EXIT_CODE."
    exit $FIX_EXIT_CODE
fi
# Then, check if any fixes would be applied (output contains "computed fixes")
if echo "$FIX_OUTPUT" | grep -q "computed fixes"; then
    echo "[locale_sheet] ERROR: dart fix would apply changes. Please run 'dart fix --apply' locally."
    exit 1
fi

echo "[locale_sheet] running static analysis..."
eval $DART_CMD analyze

echo "[locale_sheet] running tests..."
eval $DART_CMD test

echo "[locale_sheet] running coverage..."
./scripts/coverage.sh

echo "[locale_sheet] verify complete."
