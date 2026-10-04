# Deploy this checkout (deploy.ps1 -KeepKit), upload the router test scenarios and run them on the router.
# The router ends up with this code and the settings from config\ (as after a deploy).
# Takes 5-10 minutes; some scenarios empty the router, so servers vanish and LAN goes direct until each restores the state.
# Usage: .\tests\run.ps1 [-Router 192.168.8.1] [empty redeploy subscription own-server failover]
param(
    [string]$Router = "192.168.8.1",
    [string]$User = "root",
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Scenarios
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$target = "$User@$Router"

& (Join-Path $root "deploy.ps1") -Router $Router -User $User -KeepKit

$archive = Join-Path ([IO.Path]::GetTempPath()) "flint-test.tar"
try {
    Remove-Item $archive -Force -ErrorAction SilentlyContinue
    tar --format ustar -cf $archive -C $PSScriptRoot router
    if ($LASTEXITCODE) { throw "tar failed" }

    cmd /c "ssh $target ""cat > /tmp/flint-test.tar"" < ""$archive"""
    if ($LASTEXITCODE) { throw "upload failed" }

    $remote = "rm -rf /tmp/flint-test && mkdir -p /tmp/flint-test && tar -xf /tmp/flint-test.tar -C /tmp/flint-test && rm -f /tmp/flint-test.tar && " +
        "find /tmp/flint-test -type f -exec sed -i 's/\r$//' {} + && " +
        "sh /tmp/flint-test/router/all.sh /tmp/flint-kit $($Scenarios -join ' '); rc=`$?; rm -rf /tmp/flint-test /tmp/flint-kit; exit `$rc"
    ssh $target $remote
    if ($LASTEXITCODE) { throw "tests failed" }
}
finally {
    Remove-Item $archive -Force -ErrorAction SilentlyContinue
}
