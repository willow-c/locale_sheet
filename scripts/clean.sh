#!/usr/bin/env bash
set -euo pipefail

# locale_sheet: 生成物を削除するスクリプト
#
# 削除するのは、このリポジトリのビルド・テストが生成する既知のパスだけです。
# 名前による全体検索（`find . -name '*.arb'` など）は行いません。出力先は
# 利用者が `--out` で自由に指定できるため、リポジトリ全体を掃くと利用者の
# 作業結果まで消えてしまいます。
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[locale_sheet] removing generated files..."

# pub / テストの生成物
rm -rf .dart_tool/ build/ coverage/

# このリポジトリで生成されるローカライズ出力（.gitignore と対応）
rm -rf lib/l10n/ example/out/

echo "[locale_sheet] clean done."
