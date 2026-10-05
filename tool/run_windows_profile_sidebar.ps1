#Requires -Version 5.1
# profile 专用：不改版本号、不打安装包。编译后自动展开/收起侧栏，写出 JSON 给 agent 读。
# 用法：
#   powershell -File tool/run_windows_profile_sidebar.ps1
#   powershell -File tool/run_windows_profile_sidebar.ps1 -SkipBuild -ForceStop

[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [switch]$ForceStop,
    [int]$RoundTrips = 20,
    [int]$GapMs = 500,
    [int]$TimeoutSeconds = 90
)

$ErrorActionPreference = "Stop"
try { chcp 65001 | Out-Null } catch {}

$projectRoot = Split-Path -Parent $PSScriptRoot
$reportDir = Join-Path $projectRoot "build\performance"
$reportPath = Join-Path $reportDir "sidebar-perf.json"
$exePath = Join-Path $projectRoot "build\windows\x64\runner\Profile\pure_music.exe"
$flutter = (Get-Command flutter -ErrorAction Stop).Source

if ($RoundTrips -lt 1) { throw "RoundTrips must be >= 1." }

function Stop-PureMusic {
    Get-Process -Name "pure_music" -ErrorAction SilentlyContinue |
        ForEach-Object {
            Write-Host ("Stopping pid {0}" -f $_.Id) -ForegroundColor Yellow
            Stop-Process -Id $_.Id -Force
        }
    Start-Sleep -Seconds 2
}

function Get-LibrarySongCount([string]$indexPath) {
    if (-not (Test-Path -LiteralPath $indexPath)) { return 0 }
    $raw = Get-Content -LiteralPath $indexPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) { return 0 }
    $index = $raw | ConvertFrom-Json
    $n = 0
    foreach ($folder in @($index.folders)) {
        $n += @($folder.audios).Count
    }
    return [int]$n
}

function Find-SourceLibrary {
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:LOCALAPPDATA) {
        [void]$candidates.Add((Join-Path $env:LOCALAPPDATA "pure_music"))
    }
    if ($env:APPDATA) {
        [void]$candidates.Add((Join-Path $env:APPDATA "pure_music"))
    }
    $runner = Join-Path $projectRoot "build\windows\x64\runner"
    foreach ($mode in @("Release", "Debug")) {
        [void]$candidates.Add((Join-Path $runner (Join-Path $mode "data")))
    }
    $bestDir = $null
    $bestCount = 0
    foreach ($dir in $candidates) {
        if ([string]::IsNullOrWhiteSpace($dir)) { continue }
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        $count = Get-LibrarySongCount (Join-Path $dir "index.json")
        if ($count -gt $bestCount) {
            $bestDir = $dir
            $bestCount = $count
        }
    }
    return @{ Dir = $bestDir; Count = $bestCount }
}

function Copy-LibraryTree([string]$from, [string]$to) {
    if (-not (Test-Path -LiteralPath $from)) { return }
    New-Item -ItemType Directory -Path $to -Force | Out-Null
    Copy-Item -Path (Join-Path $from "*") -Destination $to -Recurse -Force
}

function Sync-ProfileLibrary([string]$exeDir) {
    $dest = Join-Path $exeDir "data"
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $source = Find-SourceLibrary
    if ([string]::IsNullOrWhiteSpace($source.Dir) -or [int]$source.Count -lt 2) {
        throw "No non-empty library found. Checked LOCALAPPDATA\pure_music, APPDATA\pure_music, Release/Debug data."
    }
    $srcFull = [System.IO.Path]::GetFullPath($source.Dir)
    $destFull = [System.IO.Path]::GetFullPath($dest)
    if ($srcFull.TrimEnd("\").ToLowerInvariant() -eq $destFull.TrimEnd("\").ToLowerInvariant()) {
        Write-Host ("Profile already uses library dir with {0} songs" -f $source.Count) -ForegroundColor Green
        return [int]$source.Count
    }
    Write-Host (">>> sync library {0} ({1} songs) -> {2}" -f $source.Dir, $source.Count, $dest) -ForegroundColor Cyan
    foreach ($name in @("index.json", "library.sqlite", "library.sqlite-shm", "library.sqlite-wal")) {
        $from = Join-Path $source.Dir $name
        if (Test-Path -LiteralPath $from) {
            Copy-Item -LiteralPath $from -Destination (Join-Path $dest $name) -Force
        }
    }
    foreach ($name in @("settings", "cache", "db")) {
        Copy-LibraryTree (Join-Path $source.Dir $name) (Join-Path $dest $name)
    }
    $destCount = Get-LibrarySongCount (Join-Path $dest "index.json")
    $sqlite = Join-Path $dest "library.sqlite"
    if ($destCount -lt 2) {
        throw ("Synced library still empty (songs={0}). Refusing to collect." -f $destCount)
    }
    if (-not (Test-Path -LiteralPath $sqlite)) {
        Write-Host "warn: library.sqlite missing after sync; app may rebuild from index.json" -ForegroundColor Yellow
    }
    Write-Host ("Synced {0} songs into profile data dir." -f $destCount) -ForegroundColor Green
    return [int]$destCount
}


$running = @(Get-Process -Name "pure_music" -ErrorAction SilentlyContinue)
if ($running.Count -gt 0) {
    if (-not $ForceStop) {
        throw "pure_music.exe is already running. Close it, or pass -ForceStop."
    }
    Stop-PureMusic
}

New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
if (Test-Path -LiteralPath $reportPath) {
    Remove-Item -LiteralPath $reportPath -Force
}

if (-not $SkipBuild) {
    Write-Host ">>> flutter build windows --profile" -ForegroundColor Cyan
    & $flutter build windows --profile --no-pub `
        --dart-define="PERF_AUTO_SIDEBAR_ROUND_TRIPS=$RoundTrips" `
        --dart-define="PERF_AUTO_SIDEBAR_GAP_MS=$GapMs"
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed: $LASTEXITCODE" }
}

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "Profile exe not found: $exePath"
}

function Repair-ProfileIconFonts([string]$exeDir) {
    $manifest = Join-Path $exeDir "data\flutter_assets\FontManifest.json"
    if (-not (Test-Path -LiteralPath $manifest)) {
        throw "FontManifest.json missing: $manifest"
    }
    $raw = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8
    if ($raw -match "MaterialSymbolsOutlined") { return }
    $releaseManifest = Join-Path $projectRoot "build\windows\x64\runner\Release\data\flutter_assets\FontManifest.json"
    if (-not (Test-Path -LiteralPath $releaseManifest)) {
        throw "Profile FontManifest is missing icon fonts, and Release FontManifest was not found to repair it."
    }
    Copy-Item -LiteralPath $releaseManifest -Destination $manifest -Force
    $raw = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8
    if ($raw -notmatch "MaterialSymbolsOutlined") {
        throw "Profile FontManifest is missing icon fonts after repair."
    }
    Write-Host "Repaired Profile FontManifest icon fonts from Release." -ForegroundColor Yellow
}

Repair-ProfileIconFonts (Split-Path $exePath)

$syncedSongs = Sync-ProfileLibrary (Split-Path $exePath)
if ($syncedSongs -lt 2) {
    throw ("Library has {0} songs, need at least 2 so the list page is not empty." -f $syncedSongs)
}

$env:PURE_MUSIC_SIDEBAR_PERF_REPORT = $reportPath
Write-Host (">>> launch {0}" -f $exePath) -ForegroundColor Cyan
$proc = Start-Process -FilePath $exePath -WorkingDirectory (Split-Path $exePath) -PassThru
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$report = $null

try {
    while ((Get-Date) -lt $deadline) {
        if (Test-Path -LiteralPath $reportPath) {
            try {
                $raw = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8
                if (-not [string]::IsNullOrWhiteSpace($raw)) {
                    $report = $raw | ConvertFrom-Json
                    if ($null -ne $report.error) { break }
                    if ([int]$report.toggles -ge (2 * $RoundTrips) -and $null -ne $report.avgFrameMs -and $null -ne $report.jank -and $null -ne $report.maxFrameMs) { break }
                }
            } catch {}
        }
        if ($proc.HasExited -and -not (Test-Path -LiteralPath $reportPath)) {
            throw "Profile process exited before writing $reportPath"
        }
        Start-Sleep -Milliseconds 500
        $proc.Refresh()
    }
}
finally {
    if (-not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
}

if ($null -eq $report) {
    throw "Timed out waiting for $reportPath"
}

$json = Get-Content -LiteralPath $reportPath -Raw -Encoding UTF8
Write-Host "`n===== PERF REPORT =====" -ForegroundColor Green
Write-Host $json.Trim()
Write-Host "=======================" -ForegroundColor Green
Write-Host ("File: {0}" -f $reportPath) -ForegroundColor Gray
Write-Host ("SyncedSongs: {0}" -f $syncedSongs) -ForegroundColor Gray

if ($null -ne $report.error) {
    throw ("Auto perf failed: {0}" -f $report.error)
}
if ([int]$report.toggles -lt (2 * $RoundTrips) -or $null -eq $report.avgFrameMs -or $null -eq $report.jank -or $null -eq $report.maxFrameMs) {
    throw ("Invalid sidebar perf data: toggles={0}, expected {1}." -f $report.toggles, (2 * $RoundTrips))
}
exit 0
