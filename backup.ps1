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

$paths = "/etc/xray /etc/dnscrypt-proxy2 /etc/dnsmasq.d /etc/firewall.user* /etc/init.d/xray /etc/init.d/gru-* " +
    "/usr/bin/gru-node /www/gru /etc/config/dhcp /etc/config/firewall /etc/config/network /etc/config/wireless " +
    "/etc/rc.local /etc/hosts /etc/opkg.conf /etc/dropbear/authorized_keys"
cmd /c "ssh $target ""tar -czf - $paths 2>/dev/null"" > ""$dir\router-config.tar.gz"""
Write-Host "Saved $dir\router-config.tar.gz"

New-Item -ItemType Directory (Join-Path $root "config") -Force | Out-Null
foreach ($f in "gru.env", "nodes.conf") {
    ssh $target "test -f /etc/xray/$f"
    if ($LASTEXITCODE -eq 0) {
        cmd /c "ssh $target ""cat /etc/xray/$f"" > ""$root\config\$f"""
        Copy-Item (Join-Path $root "config\$f") $dir
        Write-Host "Refreshed config\$f"
    }
}

if ($WithBinary) {
    $bin = Join-Path $root "backup\bin"
    New-Item -ItemType Directory $bin -Force | Out-Null
    cmd /c "ssh $target ""cat /usr/bin/xray"" > ""$bin\xray"""
    Write-Host "Saved backup\bin\xray"
}
