# Pull the live router setup into backup\<timestamp>\ and refresh config\ from the router.
# Usage: .\backup.ps1 [-Router 192.168.8.1] [-WithBinary]
#   -WithBinary also saves /usr/bin/xray to backup\bin\xray (used by deploy.ps1 if opkg fails).
param(
    [string]$Router = "192.168.8.1",
    [string]$User = "root",
    [switch]$WithBinary
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$target = "$User@$Router"
$dir = Join-Path $root ("backup\" + (Get-Date -Format "yyyy-MM-dd_HHmm"))
New-Item -ItemType Directory $dir -Force | Out-Null

$paths = "/etc/xray /etc/dnscrypt-proxy2 /etc/dnsmasq.d /etc/firewall.user* /etc/init.d/xray /etc/init.d/flint-* " +
    "/usr/bin/flint-* /usr/share/flint /www/flint /etc/config/dhcp /etc/config/firewall /etc/config/network " +
    "/etc/config/wireless /etc/rc.local /etc/hosts /etc/opkg.conf /etc/crontabs/root /etc/dropbear/authorized_keys"
cmd /c "ssh $target ""tar -czf - $paths 2>/dev/null"" > ""$dir\router-config.tar.gz"""
Write-Host "Saved $dir\router-config.tar.gz"

New-Item -ItemType Directory (Join-Path $root "config") -Force | Out-Null
foreach ($f in "flint.env", "nodes.conf", "nodes-custom.conf", "custom-sites", "subscriptions", "adblock-lists", "adblock-rules", "adblock-exclude") {
    ssh $target "test -f /etc/xray/$f"
    if ($LASTEXITCODE -eq 0) {
        cmd /c "ssh $target ""cat /etc/xray/$f"" > ""$root\config\$f"""
        Copy-Item (Join-Path $root "config\$f") $dir
        Write-Host "Refreshed config\$f"
    }
}
ssh $target "test -d /etc/xray/nodes.d && ls /etc/xray/nodes.d/*.conf >/dev/null 2>&1"
if ($LASTEXITCODE -eq 0) {
    $localD = Join-Path $root "config\nodes.d"
    Remove-Item $localD -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $localD | Out-Null
    cmd /c "ssh $target ""tar -czf - -C /etc/xray nodes.d"" > ""$dir\nodes.d.tar.gz"""
    tar -xzf (Join-Path $dir "nodes.d.tar.gz") -C (Join-Path $root "config")
    Copy-Item $localD (Join-Path $dir "nodes.d") -Recurse
    Write-Host "Refreshed config\nodes.d"
}

if ($WithBinary) {
    $bin = Join-Path $root "backup\bin"
    New-Item -ItemType Directory $bin -Force | Out-Null
    cmd /c "ssh $target ""cat /usr/bin/xray"" > ""$bin\xray"""
    Write-Host "Saved backup\bin\xray"
}
