#!/usr/bin/env bash
set -euo pipefail

# Run tests and produce lcov coverage file (fvm優先、なければdart)
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

# fvmが使えるか判定
if command -v fvm >/dev/null 2>&1; then
	DART_CMD="fvm dart"
else
	DART_CMD="dart"
fi

echo "[locale_sheet] fetching packages..."
$DART_CMD pub get

echo "[locale_sheet] running tests with coverage..."
$DART_CMD test --coverage=coverage

echo "[locale_sheet] formatting coverage to lcov..."
$DART_CMD pub global run coverage:format_coverage --packages=.dart_tool/package_config.json --in=coverage --out=coverage/lcov.info --lcov

echo "[locale_sheet] generating HTML report..."
if command -v genhtml >/dev/null 2>&1; then
	genhtml coverage/lcov.info --output-directory coverage/html
	echo "[locale_sheet] HTML report -> coverage/html/index.html"
else
	echo "[locale_sheet] genhtml コマンドが見つかりません (HTMLレポートは未生成)"
fi

echo "[locale_sheet] done. lcov -> coverage/lcov.info"
