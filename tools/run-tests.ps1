# Install the kit from this checkout on the router and run every test scenario there, streaming the output.
# This is the same work as tests\run.ps1, but it does not depend on the temporary directory, the working
# directory or on PowerShell's $PSScriptRoot, so it can be run from anywhere with one command:
#   powershell -NoProfile -ExecutionPolicy Bypass -File D:\github\Flint_Vless\tools\run-tests.ps1
param(
    [string]$Router = "192.168.8.1",
    [string]$User = "root",
    [string[]]$Scenarios = @('empty', 'redeploy', 'subscription', 'own-server', 'failover', 'panel', 'settings')
)
$ErrorActionPreference = "Stop"
$root = if ($PSScriptRoot) { Split-Path $PSScriptRoot -Parent } elseif ($MyInvocation.MyCommand.Path) { Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent } else { (Get-Location).Path }
$target = "$User@$Router"
$sshOpts = @("-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=6")
$tarIn = Join-Path $root "tools\flint-run.tar"

Write-Host "== repository: $root"
Write-Host "== router:     $target"

# The kit and the scenarios in one archive: /kit with the config from config\ (the names in kit\state-files)
# plus /router, exactly as tests\run.ps1 lays it out on the router.
$stage = Join-Path $root "tools\.stage"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory (Join-Path $stage "flint-kit\config") -Force | Out-Null
Copy-Item (Join-Path $root "kit\*") (Join-Path $stage "flint-kit") -Recurse -Force
foreach ($f in (Get-Content (Join-Path $root "kit\state-files") | Where-Object { $_ -and $_ -notmatch '^#' })) {
    $src = Join-Path $root "config\$f"
    if (Test-Path $src) { Copy-Item $src (Join-Path $stage "flint-kit\config") -Recurse -Force }
}
New-Item -ItemType Directory (Join-Path $stage "flint-test") -Force | Out-Null
Copy-Item (Join-Path $root "tests\router") (Join-Path $stage "flint-test\router") -Recurse -Force
if (Test-Path $tarIn) { Remove-Item $tarIn -Force }
tar --format ustar -cf $tarIn -C $stage .
if ($LASTEXITCODE) { throw "tar failed" }
Remove-Item $stage -Recurse -Force

Write-Host "== uploading"
# The archive holds kit/ and router/; they are unpacked into their own places on the router.
cmd /c "ssh $target ""rm -rf /tmp/flint-kit /tmp/flint-test /tmp/flint-stage && mkdir -p /tmp/flint-stage && tar -xf - -C /tmp/flint-stage && mv /tmp/flint-stage/flint-kit /tmp/flint-kit && mv /tmp/flint-stage/flint-test /tmp/flint-test && rmdir /tmp/flint-stage"" < ""$tarIn"""
if ($LASTEXITCODE) { throw "upload failed" }

Write-Host "== installing and running the scenarios (5-10 minutes)"
$remote = "rm -f /tmp/flint-test.log; " +
    "sh /tmp/flint-kit/install.sh > /tmp/flint-install.log 2>&1; " +
    "sh /tmp/flint-test/router/all.sh /tmp/flint-kit $($Scenarios -join ' ') > /tmp/flint-test.log 2>&1; " +
    "tail -n 60 /tmp/flint-test.log"
$out = ssh @sshOpts $target $remote 2>&1
$out | ForEach-Object { Write-Host ($_ -replace 'pass=[^&\s]*', 'pass=***') }

# The summary line of all.sh decides. When it is missing, the state is printed instead: the run itself
# must not be reported as passed or failed without evidence.
$summary = $out | Where-Object { $_ -match '^(ALL PASSED|SOME FAILED)' } | Select-Object -Last 1
if (-not $summary) {
    Write-Host "!! no summary line; router state:" -ForegroundColor Red
    ssh @sshOpts $target 'echo "version: $(cat /usr/share/flint/version)"; echo "vpn: $(flint-node vpn), node: $(flint-node current)"; echo "dns: $(flint-dns mode)"; echo "xray: $(pidof xray >/dev/null && echo running || echo stopped)"' 2>&1 | Write-Host
    throw "the test run gave no result"
}
if ($summary -notmatch '^ALL PASSED') { throw "some scenarios failed: $summary" }
Write-Host $summary -ForegroundColor Green
