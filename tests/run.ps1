# Test this checkout on the router: upload the kit (deploy.ps1 -UploadOnly) and the scenarios; install.sh and the
# scenarios then run in the background on the router (tests/router/job.sh), so a dropped connection does not stop them.
# The script follows the log until the run ends. Run it again after a drop: if the router already has this run (same
# commit, working-tree changes and scenarios), it follows that run instead of starting over. -Force starts a new run.
# The router ends up with this code and the settings from config\ (as after a deploy).
# Takes 5-10 minutes; some scenarios empty the router, so servers vanish and LAN goes direct until each restores the state.
# Usage: .\tests\run.ps1 [-Router 192.168.8.1] [-Force] [empty redeploy subscription own-server failover panel]
[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Router = "192.168.8.1",
    [string]$User = "root",
    [switch]$Force,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Scenarios
)
$ErrorActionPreference = "Stop"
# $PSScriptRoot is empty when the script is started through "powershell -File" on some hosts, so the path
# is taken from the invocation and, as a last resort, from the current directory.
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path $MyInvocation.MyCommand.Path -Parent } else { (Get-Location).Path }
$root = Split-Path $scriptDir -Parent
$target = "$User@$Router"
$ssh = "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=3", $target
# The run id: the tree hash of the tracked files as they are now (with uncommitted changes) and the scenarios.
$stash = git -C $root stash create 2>$null
$tree = git -C $root rev-parse "$(if ($stash) { $stash } else { 'HEAD' })^{tree}"
$id = ((@($tree) + $Scenarios) -join " ").Trim()
# "<running|done|none> <run id>": running = the pid file is alive; done = the log ends with the summary
# line of all.sh. job.sh keeps the log after it ends, so a finished run is always recognised.
$statusCmd = 'id=$(cat /tmp/flint-test.run 2>/dev/null); if [ -f /tmp/flint-test.pid ] && kill -0 $(cat /tmp/flint-test.pid) 2>/dev/null; then s=running; ' +
    'elif tail -n1 /tmp/flint-test.log 2>/dev/null | grep -qE ''^(ALL PASSED|SOME FAILED)''; then s=done; else s=none; fi; echo $s $id'

function Get-Run {
    $out = ssh @ssh $statusCmd 2>$null
    if ($LASTEXITCODE -or -not $out) { return $null }
    $s, $rest = "$out".Split(" ", 2)
    [pscustomobject]@{ Status = $s; Id = "$rest".Trim() }
}

# Two runs at once remove each other's log and leave the router without a usable result, so a run holds a
# lock on the machine that started it. A lock older than 40 minutes (a run that was killed) is ignored.
$lock = Join-Path ([IO.Path]::GetTempPath()) "flint-tests.lock"
if (Test-Path $lock) {
    $age = (Get-Date) - (Get-Item $lock).LastWriteTime
    if ($age.TotalMinutes -lt 40) {
        throw "Another test run started from this machine $([int]$age.TotalMinutes) minutes ago: wait for it or remove $lock"
    }
    Remove-Item $lock -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType File $lock | Out-Null
trap { Remove-Item $lock -Force -ErrorAction SilentlyContinue }

$run = Get-Run
if (-not $Force -and $run -and $run.Id -eq $id -and $run.Status -ne "none") {
    Write-Host "The router already has this run ($($run.Status)): following it instead of starting over"
} else {
    if ($run -and $run.Status -eq "running") { throw "Another test run is in progress on the router: wait for it to end" }
    & (Join-Path $root "deploy.ps1") -Router $Router -User $User -UploadOnly
    $archive = Join-Path ([IO.Path]::GetTempPath()) "flint-test.tar"
    try {
        Remove-Item $archive -Force -ErrorAction SilentlyContinue
        tar --format ustar -cf $archive -C $PSScriptRoot router
        if ($LASTEXITCODE) { throw "tar failed" }
        cmd /c "ssh $target ""cat > /tmp/flint-test.tar"" < ""$archive"""
        if ($LASTEXITCODE) { throw "upload failed" }
    }
    finally {
        Remove-Item $archive -Force -ErrorAction SilentlyContinue
    }
    $start = "rm -rf /tmp/flint-test && mkdir -p /tmp/flint-test && tar -xf /tmp/flint-test.tar -C /tmp/flint-test && rm -f /tmp/flint-test.tar && " +
        "find /tmp/flint-test -type f -exec sed -i 's/\r$//' {} + && echo $id > /tmp/flint-test.run && rm -f /tmp/flint-test.log /tmp/flint-test.pid && " +
        "sh -c 'sh /tmp/flint-test/router/job.sh /tmp/flint-kit $($Scenarios -join ' ') </dev/null >/tmp/flint-test.log 2>&1 &'"
    ssh @ssh $start
    if ($LASTEXITCODE) { throw "starting the tests failed" }
    Start-Sleep 5
}

$shown = 0; $last = ""; $offline = $false
# The deadline is checked in the loop, before any ssh call, so an unreachable router cannot park the wrapper
# inside a connection attempt until it is killed by hand. On Windows PowerShell ssh has no timeout of its own.
$deadline = (Get-Date).AddMinutes(30)
while ($true) {
    if ((Get-Date) -gt $deadline) { throw "No result after 30 minutes" }
    $run = Get-Run
    $lines = if ($run) { ssh @ssh "tail -n +$($shown + 1) /tmp/flint-test.log 2>/dev/null" 2>$null }
    if ($run -and -not $LASTEXITCODE) {
        $offline = $false
        foreach ($l in @($lines)) {
            if ($null -eq $l) { continue }
            Write-Host ($l -replace 'pass=[^&\s]*', 'pass=***')
            $shown++; $last = $l
        }
        if ($run.Id -ne $id) { throw "The router log belongs to another run: $($run.Id)" }
        if ($run.Status -eq "done") { break }
        # job.sh removes its log, its pid file and the run id when it finishes, so "no trace of the run" is
        # also how a finished run looks. Trust the summary line when it was read, otherwise report it.
        if ($run.Status -eq "none") {
            if ($last -match '^(ALL PASSED|SOME FAILED)') { break }
            throw "The run stopped without a result (router rebooted?): see /tmp/flint-test.log"
        }
    } elseif (-not $offline) {
        Write-Host "  (router unreachable; the run goes on there, retrying)"
        $offline = $true
    }
    Start-Sleep 10
}
if ($last -notmatch '^ALL PASSED') { throw "tests failed" }
