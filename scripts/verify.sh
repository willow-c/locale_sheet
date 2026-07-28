#!/usr/bin/env bash
set -euo pipefail

# verify.sh - run format -> fix check -> analyze -> test -> coverage (mac/linux)
#
# 生成物の削除は行いません。検証コマンドがファイルを消すのは予期できない
# ためです。作業ディレクトリを綺麗にしたい場合は `make clean` を明示的に
# 実行してください。
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if command -v fvm >/dev/null 2>&1; then
    DART_CMD="fvm dart"
else
    DART_CMD="dart"
fi

echo "[locale_sheet] fetching packages..."
eval $DART_CMD pub get

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
