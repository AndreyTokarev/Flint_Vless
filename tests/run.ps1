# Upload the kit and the router test scenarios and run them on the router.
# The empty scenario installs this checkout's kit, so the router ends up with this code (its settings are kept).
# Usage: .\tests\run.ps1 [-Router 192.168.8.1] [empty redeploy subscription own-server failover]
param(
    [string]$Router = "192.168.8.1",
    [string]$User = "root",
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Scenarios
)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$target = "$User@$Router"

$staging = Join-Path ([IO.Path]::GetTempPath()) "flint-test"
$archive = Join-Path ([IO.Path]::GetTempPath()) "flint-test.tar"
try {
    Remove-Item $staging, $archive -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $staging | Out-Null
    Copy-Item (Join-Path $root "kit") (Join-Path $staging "kit") -Recurse
    Copy-Item (Join-Path $PSScriptRoot "router") (Join-Path $staging "router") -Recurse
    tar --format ustar -cf $archive -C $staging .
    if ($LASTEXITCODE) { throw "tar failed" }

    cmd /c "ssh $target ""cat > /tmp/flint-test.tar"" < ""$archive"""
    if ($LASTEXITCODE) { throw "upload failed" }

    $remote = "rm -rf /tmp/flint-test && mkdir -p /tmp/flint-test && tar -xf /tmp/flint-test.tar -C /tmp/flint-test && rm -f /tmp/flint-test.tar && " +
        "find /tmp/flint-test -type f -exec sed -i 's/\r$//' {} + && " +
        "sh /tmp/flint-test/router/all.sh /tmp/flint-test/kit $($Scenarios -join ' '); rc=`$?; rm -rf /tmp/flint-test; exit `$rc"
    ssh $target $remote
    if ($LASTEXITCODE) { throw "tests failed" }
}
finally {
    Remove-Item $staging, $archive -Recurse -Force -ErrorAction SilentlyContinue
}
