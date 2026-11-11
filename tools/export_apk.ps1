param([int]$BuildNumber = 2)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    # Explicitly build the app entry point; never export a leftover test/debug APK.
    # Let Flutter regenerate native plugin registration for release mode.
    & flutter build apk --release --target lib/main.dart --build-number $BuildNumber
    if ($LASTEXITCODE -ne 0) { throw 'APK release build failed.' }
    $source = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'Release APK was not created.' }
    $exportDirectory = Join-Path $projectRoot 'exports'
    New-Item -ItemType Directory -Path $exportDirectory -Force | Out-Null
    $destination = Join-Path $exportDirectory "PawPals-Google-v$BuildNumber.apk"
    Copy-Item -LiteralPath $source -Destination $destination -Force
    $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if ($sourceHash -ne $destinationHash) { throw 'Exported APK does not match the release build.' }
    Write-Output "Exported: $destination"
    Write-Output "SHA256: $destinationHash"
} finally {
    Pop-Location
}
