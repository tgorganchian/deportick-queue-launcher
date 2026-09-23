# Opens N Chrome windows, each with its own isolated profile, so each one gets its own place
# in the Deportick (Queue-it) waiting room. Checkout is done by hand in whichever window gets through.
#
# Usage:
#   .\launch.ps1 -Setup                                                # log in once
#   .\launch.ps1 -Url "https://www.deportick.com/event/<event>" -Count 5
#   .\launch.ps1 -Reset                                                # wipe saved profiles

param(
    [string]$Url = "https://www.deportick.com",
    [int]$Count = 5,
    [switch]$Setup,
    [switch]$Reset
)

$chrome = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
$profiles = Join-Path $PSScriptRoot "..\profiles"
$main = Join-Path $profiles "profile-0"

if ($Reset) {
    if (Test-Path $profiles) { Remove-Item -Recurse -Force $profiles }
    Write-Host "Profiles removed."
    exit 0
}
New-Item -ItemType Directory -Force $profiles | Out-Null
if ($Setup) { $Count = 1 }

# Queue-it keeps the queue position in its own cookies. Without them, each window is assigned
# a fresh QueueId when it enters the waiting room.
function Clear-QueueCookies($dir) {
    $db = Join-Path $dir "Default\Network\Cookies"
    if (-not (Test-Path $db)) { return }
    $py = @'
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
n = c.execute("DELETE FROM cookies WHERE host_key LIKE '%queue-it%' OR name LIKE 'QueueIT%' OR name LIKE 'Queue-it%'").rowcount
c.commit()
print(f"  {n} queue cookies removed")
'@
    $py | python - $db
    if ($LASTEXITCODE -ne 0) { Write-Host "  WARNING: could not clear queue cookies (Python missing?)" }
}

# Log in once in profile-0. Every other window is a fresh profile that only receives profile-0's
# cookies and localStorage (Deportick keeps the login in localStorage, keys "crowder" and
# "crowder-user"). Chrome must be closed while copying.
if (-not $Setup -and (Test-Path $main)) {
    for ($i = 1; $i -lt $Count; $i++) {
        $dest = Join-Path $profiles "profile-$i"
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        New-Item -ItemType Directory -Force (Join-Path $dest "Default\Network") | Out-Null
        Copy-Item (Join-Path $main "Local State") $dest
        Copy-Item (Join-Path $main "Default\Network\Cookies") (Join-Path $dest "Default\Network")
        Copy-Item -Recurse (Join-Path $main "Default\Local Storage") (Join-Path $dest "Default")
    }
    Write-Host "Session cloned from profile-0 into $($Count - 1) more profiles."
    for ($i = 0; $i -lt $Count; $i++) { Clear-QueueCookies (Join-Path $profiles "profile-$i") }
}

$cols = 4; $w = 480; $h = 600
for ($i = 0; $i -lt $Count; $i++) {
    $x = ($i % $cols) * $w
    $y = [math]::Floor($i / $cols) * [math]::Floor($h / 2)
    Start-Process $chrome -ArgumentList @(
        "--user-data-dir=`"$(Join-Path $profiles "profile-$i")`"",
        "--no-first-run", "--no-default-browser-check", "--disable-sync",
        "--window-size=$w,$h", "--window-position=$x,$y",
        $Url
    )
    Write-Host "[$($i + 1)/$Count] window opened - profile-$i"
    Start-Sleep -Milliseconds 400
}
