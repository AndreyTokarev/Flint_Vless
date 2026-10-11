# What CI runs, on a developer machine: the same checks as .github/workflows/checks.yml, so a mistake is
# caught before the push instead of by the runner. Usage:
#   pwsh -File tools/check.ps1        (or: powershell -ExecutionPolicy Bypass -File tools\check.ps1)
# Exit code 0 when everything passed, 1 when something did not.
$ErrorActionPreference = 'Continue'
# The scripts run on a router with busybox, so they are POSIX shell: they are run here with a POSIX shell if
# Git for Windows provides one, which is also what catches the mistakes CI catches. bash is preferred: it
# is the one that can also run a script by path on Windows (dash cannot start the "sh" inside its own
# environment).
$sh = @(
    'C:\Program Files\Git\bin\bash.exe',
    'C:\Program Files\Git\usr\bin\dash.exe',
    'bash'
) | Where-Object { if ($_ -eq 'bash') { Get-Command bash -ErrorAction SilentlyContinue } else { Test-Path $_ } } | Select-Object -First 1

if (-not $sh) {
    Write-Host "no POSIX shell found (install Git for Windows): the checks cannot run" -ForegroundColor Red
    exit 1
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$failed = @()

function Step {
    param([string]$Name, [string]$Script)
    Write-Host "== $Name" -ForegroundColor Cyan
    $path = Join-Path $root ($Script -replace '/', '\')
    & $sh $path
    if ($LASTEXITCODE -ne 0) {
        Write-Host "   FAILED: $Name" -ForegroundColor Red
        $script:failed += $Name
    }
}

Step 'shell syntax, line endings, the Xray template' 'tools/check-scripts.sh'
Step 'no secrets in the tree' 'tools/check-secrets.sh'

# shellcheck is what CI adds on top; it is not part of Git for Windows, so it is only run when it is there.
$shellcheck = Get-Command shellcheck -ErrorAction SilentlyContinue
if ($shellcheck) {
    Write-Host "== shellcheck" -ForegroundColor Cyan
    $files = Get-ChildItem -Path kit, tests -Recurse -File |
        Where-Object { $_.Name -notlike '*.json' -and ($_.Name -like '*.sh' -or $_.Name -like 'flint-*' -or $_.Name -eq 'panel.cgi') }
    foreach ($f in $files) {
        & $shellcheck.Source -s sh -S error -e SC2154,SC1090,SC1091,SC3043,SC2034,SC1094,SC2109 $f.FullName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "   FAILED: shellcheck on $($f.Name)" -ForegroundColor Red
            $script:failed += "shellcheck: $($f.Name)"
        }
    }
} else {
    Write-Host "   shellcheck is not installed: skipped (CI runs it)" -ForegroundColor Yellow
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "ALL CHECKS PASSED" -ForegroundColor Green
    exit 0
}
Write-Host "FAILED: $($failed -join ', ')" -ForegroundColor Red
exit 1
