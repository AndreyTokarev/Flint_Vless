# Upload the kit with the config\ entries listed in kit\state-files (config\flint.env is required) to the router and run install.sh.
# Usage: .\deploy.ps1 [-Router 192.168.8.1] [-KeepKit]
#   -KeepKit leaves the unpacked kit in /tmp/flint-kit on the router (for tests\run.ps1).
param(
    [string]$Router = "192.168.8.1",
    [string]$User = "root",
    [switch]$KeepKit
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$target = "$User@$Router"

if (-not (Test-Path (Join-Path $root "config\flint.env"))) {
    throw "Missing config\flint.env - copy config\flint.env.example and fill it in (or restore from backup)."
}

$staging = Join-Path ([IO.Path]::GetTempPath()) "flint-kit"
$archive = Join-Path ([IO.Path]::GetTempPath()) "flint-kit.tar"
try {
    Remove-Item $staging, $archive -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $root "kit") $staging -Recurse
    New-Item -ItemType Directory (Join-Path $staging "config") | Out-Null
    foreach ($f in Get-Content (Join-Path $root "kit\state-files") | Where-Object { $_ -and $_ -notmatch '^#' }) {
        $src = Join-Path $root "config\$f"
        if (Test-Path $src) { Copy-Item $src (Join-Path $staging "config") -Recurse }
    }
    $xrayBin = Join-Path $root "backup\bin\xray"
    if (Test-Path $xrayBin) {
        New-Item -ItemType Directory (Join-Path $staging "bin") | Out-Null
        Copy-Item $xrayBin (Join-Path $staging "bin")
    }
    tar --format ustar -cf $archive -C $staging .
    if ($LASTEXITCODE) { throw "tar failed" }

    cmd /c "ssh $target ""cat > /tmp/flint-kit.tar"" < ""$archive"""
    if ($LASTEXITCODE) { throw "upload failed" }

    $remote = "rm -rf /tmp/flint-kit && mkdir -p /tmp/flint-kit && tar -xf /tmp/flint-kit.tar -C /tmp/flint-kit && rm -f /tmp/flint-kit.tar && " +
        "find /tmp/flint-kit -type f ! -path '/tmp/flint-kit/bin/*' -exec sed -i 's/\r$//' {} + && " +
        "sh /tmp/flint-kit/install.sh; rc=`$?; " + $(if ($KeepKit) { "" } else { "rm -rf /tmp/flint-kit; " }) + "exit `$rc"
    ssh $target $remote
    if ($LASTEXITCODE) { throw "install.sh failed (exit $LASTEXITCODE)" }
}
finally {
    Remove-Item $staging, $archive -Recurse -Force -ErrorAction SilentlyContinue
}
