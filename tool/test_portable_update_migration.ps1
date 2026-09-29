#Requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
    "pure_music_portable_update_test_{0}" -f [Guid]::NewGuid().ToString("N")
)
$previousPath = Join-Path $testRoot "previous"
$currentPath = Join-Path $testRoot "current"

try {
    foreach ($directory in @(
        $previousPath,
        (Join-Path $previousPath "data"),
        (Join-Path $previousPath "data\flutter_assets"),
        (Join-Path $previousPath "data\settings"),
        $currentPath,
        (Join-Path $currentPath "data"),
        (Join-Path $currentPath "data\flutter_assets"),
        (Join-Path $currentPath ".update")
    )) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }

    foreach ($executable in @(
        (Join-Path $previousPath "pure_music.exe"),
        (Join-Path $currentPath "pure_music.exe"),
        (Join-Path $previousPath "data\app.so"),
        (Join-Path $currentPath "data\app.so"),
        (Join-Path $previousPath "data\flutter_assets\asset"),
        (Join-Path $currentPath "data\flutter_assets\asset")
    )) {
        Set-Content -LiteralPath $executable -Value "runtime" -Encoding UTF8
    }

    Set-Content -LiteralPath (
        Join-Path $previousPath "data\settings\legacy.json"
    ) -Value "legacy-user-data" -Encoding UTF8
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "upgrade_from_previous.ps1") `
        -Destination (Join-Path $currentPath ".update\upgrade_from_previous.ps1")

    & (Join-Path $currentPath ".update\upgrade_from_previous.ps1") `
        -PreviousPath $previousPath `
        -NonInteractive

    $migrated = Join-Path $currentPath "data\settings\legacy.json"
    if (-not (Test-Path -LiteralPath $migrated -PathType Leaf)) {
        throw "Legacy user data was not migrated."
    }
    if ((Get-Content -Raw -LiteralPath $migrated).Trim() -ne "legacy-user-data") {
        throw "Migrated user data was changed."
    }

    Write-Host "Portable update migration test passed." -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
