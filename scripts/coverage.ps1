# PowerShell スクリプト: coverage の一発実行
$ErrorActionPreference = 'Stop'
Write-Host "locale_sheet: coverage (PowerShell)"

function Invoke-LocalCommand($cmd, $argsList) {
    Write-Host "Running: $cmd $($argsList -join ' ')"
    $proc = Start-Process -FilePath $cmd -ArgumentList $argsList -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "Command failed: $cmd $($argsList -join ' ') (exit $($proc.ExitCode))" }
}

# fvm が使えるなら fvm dart を使い、なければ dart を直接使う
if (Get-Command fvm -ErrorAction SilentlyContinue) {
    $cmd = 'fvm'
    $argsPrefix = @('dart')
} else {
    $cmd = 'dart'
    $argsPrefix = @()
}

Write-Host "Resolving packages..."
Invoke-LocalCommand $cmd ($argsPrefix + @('pub','get'))

if (-Not (Test-Path 'coverage')) { New-Item -ItemType Directory -Path 'coverage' | Out-Null }

Write-Host "Running tests (with coverage)..."
Invoke-LocalCommand $cmd ($argsPrefix + @('test','--coverage=coverage'))

Write-Host "Formatting coverage to lcov..."

 $formatArgs = @('pub','global','run','coverage:format_coverage','--packages=.dart_tool/package_config.json','--in=coverage','--out=coverage/lcov.info','--lcov')
Invoke-LocalCommand $cmd $formatArgs


Write-Host "[locale_sheet] generating HTML report..."
if (Get-Command genhtml -ErrorAction SilentlyContinue) {
    genhtml coverage/lcov.info --output-directory coverage/html
    Write-Host "[locale_sheet] HTML report -> coverage/html/index.html"
} else {
    Write-Host "[locale_sheet] genhtml コマンドが見つかりません (HTMLレポートは未生成)"
}

Write-Host "[locale_sheet] done. lcov -> coverage/lcov.info"
exit 0
