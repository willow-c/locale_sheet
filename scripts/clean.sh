#!/usr/bin/env bash
set -euo pipefail

# locale_sheet: 開発用クリーンアップスクリプト
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[locale_sheet] cleaning generated/test files..."

# カバレッジ・テスト生成物
rm -rf coverage/
rm -rf .dart_tool/

# l10n/ ディレクトリや .arb ファイル（lib/l10n, test/l10n など）
find . -type d -name l10n -exec rm -rf {} +
find . -type f -name '*.arb' -delete

# .DS_Store など不要ファイル
find . -type f -name '.DS_Store' -delete

echo "[locale_sheet] clean done."
