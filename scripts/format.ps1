<#
  PowerShell: format.ps1
  Run `dart format` across the repo on Windows (or PowerShell).
#>

$ErrorActionPreference = 'Stop'

Write-Host "locale_sheet: format (PowerShell)"

# 引数名に $args を使うと PowerShell の自動変数を隠してしまうため避ける。
function Invoke-LocalCommand($cmd, $commandArgs) {
    Write-Host "Running: $cmd $($commandArgs -join ' ')"
    $proc = Start-Process -FilePath $cmd -ArgumentList $commandArgs -NoNewWindow -Wait -PassThru
    if ($proc.ExitCode -ne 0) { throw "Command failed: $cmd $($commandArgs -join ' ') (exit $($proc.ExitCode))" }
}

# choose fvm if available
if (Get-Command fvm -ErrorAction SilentlyContinue) {
    $cmd = 'fvm'
    $argsPrefix = @('dart')
} else {
    $cmd = 'dart'
    $argsPrefix = @()
}

Write-Host "Resolving packages..."
Invoke-LocalCommand $cmd ($argsPrefix + @('pub','get'))

Write-Host "Running dart format..."
Invoke-LocalCommand $cmd ($argsPrefix + @('format','--output','none','--set-exit-if-changed','.'))

Write-Host "format complete."
exit 0
