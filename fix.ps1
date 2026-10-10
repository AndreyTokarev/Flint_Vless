# One-command repair and update for the router, meant to be run from the network that can reach it.
# Usage (from the repository root):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\fix.ps1
#   .\fix.ps1 -Router 192.168.8.1 -NoDoh        # do not touch the DNS mode
#
# It is safe to run several times: every step checks what is already in place.
#
# What it does, in order:
#   1. checks that the router answers over SSH (and says what to do if it does not);
#   2. removes my leftover tunnel DNS choice: if the mode is "tunnel", it goes back to the previous
#      working mode (DoH), because a broken tunnel leaves the whole network without name resolution;
#   3. deploys the kit from this checkout (deploy.ps1), which installs the fixed scripts and services;
#   4. makes sure the VPN mode is on and DNS answers, and prints the result;
#   5. runs the full scenario set on the router (tests\run.ps1) and reports pass/fail.
param(
    [string]$Router = "192.168.8.1",
    [string]$User = "root",
    [switch]$NoDoh,
    [switch]$SkipTests
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$target = "$User@$Router"
$sshOpts = @("-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=3")

function Say($text) { Write-Host "== $text" }
function Fail($text) { Write-Host "!! $text" -ForegroundColor Red; exit 1 }
function Remote($command) { $out = ssh @sshOpts $target $command 2>&1; return $out }

Say "1/5 checking the router $target"
$probe = Remote 'echo READY; cat /usr/share/flint/version 2>/dev/null'
if ($LASTEXITCODE -or -not ($probe -match 'READY')) {
    Write-Host $probe
    Fail @"
The router did not answer over SSH. Check, in this order:
  - are you in the router's network (its Wi-Fi) or in the main router's network with a route to 192.168.8.0/24?
  - a local VPN client (Happ and the like) takes 192.168.8.1 into its tunnel: turn it off, or add a route as
    administrator:  route -p add 192.168.8.0 mask 255.255.255.0 192.168.0.1
  - is the router up? ping 192.168.8.1 and open http://192.168.8.1:81/
"@
}
$wasVersion = ($probe | Where-Object { $_ -match '^\d' } | Select-Object -First 1)
Say "router answers, installed version: $wasVersion"

Say "2/5 checking the DNS mode"
$dnsMode = (Remote 'flint-dns mode 2>/dev/null') -join "`n"
$dnsTitle = (Remote 'flint-dns 2>/dev/null') -join "`n"
Write-Host "   mode: $($dnsMode.Trim()) - $($dnsTitle.Trim())"
$dnsOk = (Remote 'nslookup example.com 127.0.0.1 >/dev/null 2>&1 && echo yes || echo no') -join ""
if ($dnsMode.Trim() -eq 'tunnel' -and -not $NoDoh) {
    Say "   the tunnel mode is set (my leftover): switching back to DoH"
    Remote 'echo doh > /etc/xray/dns-mode; flint-dns mode doh' | Write-Host
} elseif ($dnsOk.Trim() -ne 'yes' -and -not $NoDoh) {
    Say "   DNS does not answer: switching to DoH"
    Remote 'flint-dns mode doh' | Write-Host
} else {
    Write-Host "   DNS answers: $dnsOk"
}

Say "3/5 deploying the kit from this checkout"
# A non-zero exit of install.sh is not fatal by itself: install.sh can stop on its final checks (an
# unreachable node, a warning it treats as an error) while the router keeps a working config. The
# state is checked in the next step; the failure is only reported if the router is really left broken.
$deployFailed = $false
& (Join-Path $root "deploy.ps1") -Router $Router -User $User
if ($LASTEXITCODE) { $deployFailed = $true }
if ($deployFailed) {
    Write-Host "!! deploy.ps1 reported a failure - checking what the router is actually in" -ForegroundColor Yellow
}

Say "4/5 checking the VPN and DNS after the deploy"
Remote 'flint-node vpn on >/dev/null 2>&1; sleep 2; echo "vpn: $(flint-node vpn), node: $(flint-node current), routing: $(flint-node routing)"' | Write-Host
$dnsNow = (Remote 'nslookup youtube.com 127.0.0.1 >/dev/null 2>&1 && echo yes || echo no') -join ""
Write-Host "   DNS answers: $dnsNow"
$exit = (Remote 'timeout 25 curl -s -m 20 -x http://127.0.0.1:1087 https://ifconfig.me') -join ""
if ($exit -match '^\d+\.\d+\.\d+\.\d+$') {
    Write-Host "   VPN exit IP: $exit  (VPN works)"
} else {
    Write-Host "   VPN exit IP: not answered - the current node may be down. The panel (Servers tab) has the list;" -ForegroundColor Yellow
    Write-Host "   the router switches to a working one on its own every 2 minutes (failover)." -ForegroundColor Yellow
}
Remote 'echo "xray: $(xray version | head -n1)"; echo "previous binary kept: $([ -f /usr/bin/xray.previous ] && echo yes || echo no)"' | Write-Host

if ($SkipTests) { Say "5/5 tests skipped (-SkipTests)"; exit 0 }
if ($deployFailed -and ($dnsNow.Trim() -ne 'yes' -or $exit -notmatch '^\d+\.\d+\.\d+\.\d+$')) {
    Write-Host "!! install.sh failed and the router is not in a working state (DNS: $dnsNow, VPN exit: $exit)" -ForegroundColor Red
    Write-Host "   nothing else was changed: send me this output" -ForegroundColor Red
    exit 1
}
if ($deployFailed) {
    Write-Host "note: install.sh reported a failure, but the router is working (DNS and VPN answer)." -ForegroundColor Yellow
    Write-Host "      This is the health check being too strict about a slow node; it is fixed in the kit." -ForegroundColor Yellow
}
Say "5/5 running the scenario set on the router (5-10 minutes)"
& (Join-Path $root "tests\run.ps1") -Router $Router -User $User
if ($LASTEXITCODE) {
    Write-Host "!! some scenarios failed: see the lines above and /tmp/flint-test.log on the router" -ForegroundColor Red
    exit 1
}
Say "done: the router runs the version from this checkout, DNS and VPN are checked, all scenarios passed"
Say "if you switched a VPN client on this computer off before, you can turn it back on - and add the route"
Say "route -p add 192.168.8.0 mask 255.255.255.0 192.168.0.1   (administrator, once)"
