<#
  PowerShell: verify.ps1
  実行内容: format -> analyze -> test -> coverage
#>

$ErrorActionPreference = 'Stop'

Write-Host "locale_sheet: verify (PowerShell)"

function Invoke-LocalCommand($cmd, $args) {
    Write-Host "Running: $cmd $($args -join ' ')"
    $proc = Start-Process -FilePath $cmd -ArgumentList $args -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "Command failed: $cmd $($args -join ' ') (exit $($proc.ExitCode))" }
}

# choose fvm if available
if (Get-Command fvm -ErrorAction SilentlyContinue) {
    $cmd = 'fvm'
    $argsPrefix = @('dart')
} else {
    $cmd = 'dart'
    $argsPrefix = @()
}

Write-Host "Running clean..."
$cleanScript = Join-Path $PSScriptRoot 'clean.ps1'
if (Test-Path $cleanScript) {
    & $cleanScript
} else {
    Write-Host "clean.ps1 が見つかりません, skipping clean"
}

Write-Host "Resolving packages..."
Invoke-LocalCommand $cmd ($argsPrefix + @('pub','get'))

Write-Host "Running format..."
Invoke-LocalCommand $cmd ($argsPrefix + @('format','.'))

Write-Host "Running static analysis..."
Invoke-LocalCommand $cmd ($argsPrefix + @('analyze'))

Write-Host "Running tests..."
Invoke-LocalCommand $cmd ($argsPrefix + @('test'))

Write-Host "Running coverage (coverage.ps1)..."
$coverageScript = Join-Path $PSScriptRoot 'coverage.ps1'
if (-not (Test-Path $coverageScript)) {
    Write-Error "coverage.ps1 が見つかりません: $coverageScript"
    exit 2
}
& $coverageScript

Write-Host "verify complete."
exit 0
