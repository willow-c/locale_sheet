#!/usr/bin/env bash
set -euo pipefail

# locale_sheet: 開発用クリーンアップスクリプト
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[locale_sheet] cleaning generated/test files..."

echo "[locale_sheet] running Flutter clean (fvm/flutter if available)"
if command -v fvm >/dev/null 2>&1; then
	echo "[locale_sheet] running: fvm flutter clean"
	fvm flutter clean || true
elif command -v flutter >/dev/null 2>&1; then
	echo "[locale_sheet] running: flutter clean"
	flutter clean || true
else
	echo "[locale_sheet] flutter が見つかりません (skipping flutter clean)"
fi

# カバレッジ・テスト生成物
rm -rf coverage/
rm -rf .dart_tool/

# l10n/ ディレクトリや .arb ファイル（lib/l10n, test/l10n など）
find . -type d -name l10n -exec rm -rf {} +
find . -type f -name '*.arb' -delete

# .DS_Store など不要ファイル
find . -type f -name '.DS_Store' -delete

echo "[locale_sheet] clean done."
