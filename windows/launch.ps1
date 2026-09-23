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

# Work areas of every screen, primary first, in the scaled units Chrome uses for
# --window-position/--window-size (physical pixels / display scale).
Add-Type @'
using System; using System.Collections.Generic; using System.Runtime.InteropServices;
public static class Screens {
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] struct INFO { public int Size; public RECT Mon, Work; public int Flags; }
    delegate bool Proc(IntPtr m, IntPtr dc, IntPtr r, IntPtr d);
    [DllImport("user32.dll")] static extern bool SetProcessDpiAwarenessContext(IntPtr v);
    [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr dc, IntPtr clip, Proc p, IntPtr d);
    [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr m, ref INFO i);
    [DllImport("shcore.dll")] static extern int GetDpiForMonitor(IntPtr m, int type, out uint x, out uint y);
    public static List<int[]> WorkAreas() {
        SetProcessDpiAwarenessContext(new IntPtr(-4));
        var list = new List<int[]>();
        EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (m, dc, r, d) => {
            var i = new INFO { Size = Marshal.SizeOf(typeof(INFO)) };
            GetMonitorInfo(m, ref i);
            uint dx, dy; GetDpiForMonitor(m, 0, out dx, out dy);
            double s = dx / 96.0; var w = i.Work;
            var a = new[] { (int)(w.L / s), (int)(w.T / s), (int)((w.R - w.L) / s), (int)((w.B - w.T) / s) };
            if ((i.Flags & 1) != 0) list.Insert(0, a); else list.Add(a);
            return true;
        }, IntPtr.Zero);
        return list;
    }
}
'@

# Tile windows over every screen: as many ~500px-wide columns as fit (Chrome's minimum width)
# and the fewest rows (up to 4, ~250px tall) that fit every window side by side.
# Windows beyond that fill the same slots again, cascaded 40px.
$areas = [Screens]::WorkAreas()
$colsTotal = ($areas | ForEach-Object { [math]::Max(1, [math]::Floor($_[2] / 500)) } | Measure-Object -Sum).Sum
$rows = [math]::Min(4, [math]::Ceiling($Count / $colsTotal))
$slots = foreach ($a in $areas) {
    $cols = [math]::Max(1, [math]::Floor($a[2] / 500))
    $w = [math]::Floor($a[2] / $cols); $h = [math]::Floor($a[3] / $rows)
    for ($r = 0; $r -lt $rows; $r++) {
        for ($c = 0; $c -lt $cols; $c++) { @{ X = $a[0] + $c * $w; Y = $a[1] + $r * $h; W = $w; H = $h } }
    }
}
Write-Host "$($slots.Count) windows fit side by side across all screens."

for ($i = 0; $i -lt $Count; $i++) {
    $s = $slots[$i % $slots.Count]; $offset = [math]::Floor($i / $slots.Count) * 40
    Start-Process $chrome -ArgumentList @(
        "--user-data-dir=`"$(Join-Path $profiles "profile-$i")`"",
        "--no-first-run", "--no-default-browser-check", "--disable-sync",
        "--window-size=$($s.W),$($s.H)", "--window-position=$($s.X + $offset),$($s.Y + $offset)",
        $Url
    )
    Write-Host "[$($i + 1)/$Count] window opened - profile-$i"
    Start-Sleep -Milliseconds 400
}
