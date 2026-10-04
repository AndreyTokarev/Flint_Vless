# Remove Flint VPN from the router: back up with backup.ps1 first, then run kit\uninstall.sh there.
# Usage: .\uninstall.ps1 [-Router 192.168.8.1] [-KeepXray] [-NoBackup] [-Yes]
#   The firmware, network and Wi-Fi stay; LAN devices go online directly. restore.ps1 brings Flint back.
#   -KeepXray  keep the xray-core package.
#   -NoBackup  skip the backup (by default the settings go to backup\<date> and config\).
param(
    [string]$Router = "192.168.8.1",
    [string]$User = "root",
    [switch]$KeepXray,
    [switch]$NoBackup,
    [switch]$Yes
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$target = "$User@$Router"

if (-not $Yes -and (Read-Host "Remove Flint VPN from $target? [y/N]") -notmatch '^[yY]') { Write-Host "Cancelled"; exit 1 }
if (-not $NoBackup) { & (Join-Path $root "backup.ps1") -Router $Router -User $User }

$script = Join-Path ([IO.Path]::GetTempPath()) "flint-uninstall.sh"
try {
    $text = [IO.File]::ReadAllText((Join-Path $root "kit\uninstall.sh")) -replace "`r", ""
    [IO.File]::WriteAllText($script, $text)
    cmd /c "ssh $target ""cat > /tmp/flint-uninstall.sh"" < ""$script"""
    if ($LASTEXITCODE) { throw "upload failed" }
    $opts = if ($KeepXray) { " --keep-xray" } else { "" }
    ssh $target "sh /tmp/flint-uninstall.sh$opts; rc=`$?; rm -f /tmp/flint-uninstall.sh; exit `$rc"
    if ($LASTEXITCODE) { throw "uninstall.sh failed (exit $LASTEXITCODE)" }
}
finally {
    Remove-Item $script -Force -ErrorAction SilentlyContinue
}
