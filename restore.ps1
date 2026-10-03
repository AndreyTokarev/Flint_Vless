# Restore the router from a backup made by backup.ps1.
# Usage: .\restore.ps1 [-Backup backup\2026-10-03_1557] [-Router 192.168.8.1] [-Full] [-Yes]
#   default: settings from the backup (gru.env, servers, own servers, custom sites) go to config\,
#            then deploy.ps1 installs packages and the kit - works on a reset router too.
#   -Full    also brings back network, Wi-Fi, firewall, DHCP, hosts, cron and SSH keys from the
#            backup and reboots. Only for the same router: these replace the current settings.
#   -Backup  defaults to the newest backup\<date> folder.
param(
    [string]$Backup,
    [string]$Router = "192.168.8.1",
    [string]$User = "root",
    [switch]$Full,
    [switch]$Yes
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$target = "$User@$Router"

if (-not $Backup) {
    $Backup = Get-ChildItem (Join-Path $root "backup") -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName "router-config.tar.gz") } |
        Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
    if (-not $Backup) { throw "No backup\<date>\router-config.tar.gz found - run backup.ps1 first." }
}
$archive = Join-Path (Resolve-Path $Backup) "router-config.tar.gz"
if (-not (Test-Path $archive)) { throw "Missing $archive" }

$files = "gru.env", "nodes.conf", "nodes-custom.conf", "custom-sites"
$tmp = Join-Path ([IO.Path]::GetTempPath()) "gru-restore"
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $tmp | Out-Null
try {
    tar -xzf $archive -C $tmp etc/xray 2>$null
    $found = $files | Where-Object { Test-Path (Join-Path $tmp "etc\xray\$_") }

    Write-Host "Backup: $Backup"
    Write-Host ("Settings from the backup: " + $(if ($found) { $found -join ", " } else { "none (current config\ is kept)" }))
    if ($Full) { Write-Host "Full: network, Wi-Fi, firewall, DHCP, hosts, cron, SSH keys from the backup, then reboot" }
    if (-not $Yes -and (Read-Host "Restore to $target? [y/N]") -notmatch '^[yY]') { Write-Host "Cancelled"; exit 1 }

    if ($found) {
        $keep = Join-Path $root ("backup\config-before-restore-" + (Get-Date -Format "yyyy-MM-dd_HHmmss"))
        New-Item -ItemType Directory $keep | Out-Null
        foreach ($f in $files) {
            $cur = Join-Path $root "config\$f"
            if (Test-Path $cur) { Copy-Item $cur $keep }
        }
        Write-Host "Current config\ saved to $keep"
        foreach ($f in $found) { Copy-Item (Join-Path $tmp "etc\xray\$f") (Join-Path $root "config\$f") -Force }
    }

    if ($Full) {
        cmd /c "ssh $target ""cat > /tmp/gru-restore.tgz"" < ""$archive"""
        if ($LASTEXITCODE) { throw "upload failed" }
        $remote = "R=/tmp/gru-restore; rm -rf `$R; mkdir -p `$R && tar -xzf /tmp/gru-restore.tgz -C `$R && rm -f /tmp/gru-restore.tgz && " +
            "for f in etc/config/network etc/config/wireless etc/config/firewall etc/config/dhcp etc/hosts etc/rc.local " +
            "etc/crontabs/root etc/dropbear/authorized_keys; do if [ -f `$R/`$f ]; then mkdir -p /`$(dirname `$f) && cp `$R/`$f /`$f && echo restored /`$f; fi; done; rm -rf `$R"
        ssh $target $remote
        if ($LASTEXITCODE) { throw "restoring system files failed" }
    }

    & (Join-Path $root "deploy.ps1") -Router $Router -User $User

    if ($Full) {
        Write-Host "Rebooting the router to apply network and Wi-Fi settings..."
        ssh $target "reboot"
    }
}
finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
