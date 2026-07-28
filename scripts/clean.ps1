# PowerShell: locale_sheet 生成物削除スクリプト
#
# 削除するのは、このリポジトリのビルド・テストが生成する既知のパスだけです。
# 名前による全体検索（`Get-ChildItem -Recurse -Filter *.arb` など）は行いません。
# 出力先は利用者が --out で自由に指定できるため、リポジトリ全体を掃くと
# 利用者の作業結果まで消えてしまいます。
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

Write-Host "[locale_sheet] removing generated files..."

$targets = @(
    '.dart_tool',
    'build',
    'coverage',
    'lib/l10n',
    'example/out'
)

foreach ($target in $targets) {
    $path = Join-Path $root $target
    if (Test-Path $path) {
        Remove-Item -Recurse -Force $path
        Write-Host "  removed: $target"
    }
}

Write-Host "[locale_sheet] clean done."
