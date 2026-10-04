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

# User state (kit\state-files) as one archive, then unpacked over config\.
$config = Join-Path $root "config"
New-Item -ItemType Directory $config -Force | Out-Null
$names = (Get-Content (Join-Path $root "kit\state-files") | Where-Object { $_ -and $_ -notmatch '^#' }) -join " "
$state = Join-Path $dir "state.tar.gz"
cmd /c "ssh $target ""cd /etc/xray && tar -czf - `$(ls -d $names 2>/dev/null)"" > ""$state"""
if ($LASTEXITCODE -eq 0) {
    foreach ($name in (tar -tzf $state | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique)) {
        Remove-Item (Join-Path $config $name) -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Refreshed config\$name"
    }
    tar -xzf $state -C $config
} else {
    Write-Host "No user state on the router: config\ is kept"
}

if ($WithBinary) {
    $bin = Join-Path $root "backup\bin"
    New-Item -ItemType Directory $bin -Force | Out-Null
    cmd /c "ssh $target ""cat /usr/bin/xray"" > ""$bin\xray"""
    Write-Host "Saved backup\bin\xray"
}
