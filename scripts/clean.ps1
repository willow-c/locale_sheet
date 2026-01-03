# PowerShell: locale_sheet クリーンアップスクリプト
$ErrorActionPreference = 'Stop'
Write-Host "[locale_sheet] cleaning generated/test files..."

# カバレッジ・テスト生成物
Remove-Item -Recurse -Force coverage, .dart_tool -ErrorAction SilentlyContinue

# l10n ディレクトリと .arb ファイル
Get-ChildItem -Recurse -Directory -Filter l10n | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem -Recurse -Filter *.arb | Remove-Item -Force -ErrorAction SilentlyContinue

# .DS_Store など
Get-ChildItem -Recurse -Filter .DS_Store | Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "[locale_sheet] clean done."
