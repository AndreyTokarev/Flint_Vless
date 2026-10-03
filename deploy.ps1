# Upload the kit with config/gru.env + config/nodes.conf to the router and run install.sh.
# Usage: .\deploy.ps1 [-Router 192.168.8.1]
param(
    [string]$Router = "192.168.8.1",
    [string]$User = "root"
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$target = "$User@$Router"

foreach ($f in "gru.env", "nodes.conf") {
    if (-not (Test-Path (Join-Path $root "config\$f"))) {
        throw "Missing config\$f - copy config\$f.example and fill it in (or restore from backup)."
    }
}

$staging = Join-Path ([IO.Path]::GetTempPath()) "gru-kit"
$archive = Join-Path ([IO.Path]::GetTempPath()) "gru-kit.tar"
try {
    Remove-Item $staging, $archive -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $root "kit") $staging -Recurse
    New-Item -ItemType Directory (Join-Path $staging "config") | Out-Null
    foreach ($f in "gru.env", "nodes.conf", "nodes-custom.conf", "custom-sites", "adblock-lists", "adblock-rules", "adblock-exclude") {
        $src = Join-Path $root "config\$f"
        if (Test-Path $src) { Copy-Item $src (Join-Path $staging "config") }
    }
    $xrayBin = Join-Path $root "backup\bin\xray"
    if (Test-Path $xrayBin) {
        New-Item -ItemType Directory (Join-Path $staging "bin") | Out-Null
        Copy-Item $xrayBin (Join-Path $staging "bin")
    }
    tar --format ustar -cf $archive -C $staging .
    if ($LASTEXITCODE) { throw "tar failed" }

    cmd /c "ssh $target ""cat > /tmp/gru-kit.tar"" < ""$archive"""
    if ($LASTEXITCODE) { throw "upload failed" }

    $remote = "rm -rf /tmp/gru-kit && mkdir -p /tmp/gru-kit && tar -xf /tmp/gru-kit.tar -C /tmp/gru-kit && rm -f /tmp/gru-kit.tar && " +
        "find /tmp/gru-kit -type f ! -path '/tmp/gru-kit/bin/*' -exec sed -i 's/\r$//' {} + && " +
        "sh /tmp/gru-kit/install.sh; rc=`$?; rm -rf /tmp/gru-kit; exit `$rc"
    ssh $target $remote
    if ($LASTEXITCODE) { throw "install.sh failed (exit $LASTEXITCODE)" }
}
finally {
    Remove-Item $staging, $archive -Recurse -Force -ErrorAction SilentlyContinue
}
