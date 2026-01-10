<#
  Windows 用の簡易 Make風 ラッパー。
  Repository-root make.ps1
  使い方: powershell -ExecutionPolicy Bypass -File .\make.ps1 <target>
  内部で ./scripts/make.ps1 を呼び出します。
#>

param(
    [string]$Target
)

function Show-Usage {
    Write-Host "Usage: make.ps1 <target>"
    Write-Host "Targets: coverage, clean, format, verify"
}

if (-not $Target) {
    Show-Usage
    exit 1
}

$t = $Target.ToLower()

if ($t -eq 'coverage') {
    $p = Join-Path $PSScriptRoot 'coverage.ps1'
    if (-not (Test-Path $p)) {
        Write-Error "coverage.ps1 が見つかりません: $p"
        exit 2
    }
    & $p
    $scriptDir = Join-Path $PSScriptRoot 'scripts'

    switch ($t) {
        'coverage' {
            $p = Join-Path $scriptDir 'coverage.ps1'
            if (-not (Test-Path $p)) { Write-Error "coverage.ps1 が見つかりません: $p"; exit 2 }
            & $p; exit $LASTEXITCODE
        }
        'clean' {
            $p = Join-Path $scriptDir 'clean.ps1'
            if (-not (Test-Path $p)) { Write-Error "clean.ps1 が見つかりません: $p"; exit 2 }
            & $p; exit $LASTEXITCODE
        }
        'format' {
            $p = Join-Path $scriptDir 'format.ps1'
            if (-not (Test-Path $p)) { Write-Error "format.ps1 が見つかりません: $p"; exit 2 }
            & $p; exit $LASTEXITCODE
        }
        'verify' {
            $p = Join-Path $scriptDir 'verify.ps1'
            if (-not (Test-Path $p)) { Write-Error "verify.ps1 が見つかりません: $p"; exit 2 }
            & $p; exit $LASTEXITCODE
        }
        default {
            Write-Error "不明なターゲット: $Target"
            Show-Usage
            exit 1
        }
    }
