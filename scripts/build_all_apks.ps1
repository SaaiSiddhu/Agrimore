# Builds release APK + AAB for all four Agrimore apps and collects them
# into apk-output/ at the repo root (gitignored — regenerate anytime, don't commit).
#
# Usage: powershell -File scripts/build_all_apks.ps1
# Requires: flutter on PATH.

$ErrorActionPreference = "Continue"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$BASE = Join-Path $RepoRoot "apps"
$OUTPUT = Join-Path $RepoRoot "apk-output"

New-Item -ItemType Directory -Path $OUTPUT -Force | Out-Null
Get-ChildItem -Path $OUTPUT -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in ".apk", ".aab", ".zip" } |
    Remove-Item -Force

$apps = @(
    @{ Name = "Customer"; Dir = "marketplace"; OutputBase = "Agrimore-Customer" },
    @{ Name = "Admin";    Dir = "admin";       OutputBase = "Agrimore-Admin" },
    @{ Name = "Seller";   Dir = "seller";      OutputBase = "Agrimore-Seller" },
    @{ Name = "Delivery"; Dir = "delivery";    OutputBase = "Agrimore-Delivery" }
)

$results = @()

foreach ($app in $apps) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Building: $($app.Name)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    $appDir = Join-Path $BASE $app.Dir
    Set-Location $appDir

    Write-Host "  Cleaning..." -ForegroundColor Yellow
    flutter clean 2>&1 | Out-Null

    Write-Host "  Getting dependencies..." -ForegroundColor Yellow
    flutter pub get 2>&1 | Out-Null

    Write-Host "  Building APK (release)..." -ForegroundColor Yellow
    $buildOutput = flutter build apk --release 2>&1
    $exitCode = $LASTEXITCODE
    $apkOk = $false

    if ($exitCode -eq 0) {
        $apkPath = Join-Path $appDir "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apkPath) {
            $destPath = Join-Path $OUTPUT "$($app.OutputBase).apk"
            Copy-Item $apkPath $destPath -Force
            $size = [math]::Round((Get-Item $destPath).Length / 1MB, 2)
            Write-Host "  SUCCESS! APK: $($app.OutputBase).apk ($size MB)" -ForegroundColor Green
            $apkOk = $true
        } else {
            Write-Host "  ERROR: APK file not found at $apkPath" -ForegroundColor Red
        }
    } else {
        Write-Host "  APK BUILD FAILED!" -ForegroundColor Red
        $buildOutput | Select-Object -Last 15 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    }

    Write-Host "  Building AAB (release)..." -ForegroundColor Yellow
    $bundleOutput = flutter build appbundle --release 2>&1
    $bundleExitCode = $LASTEXITCODE
    $aabOk = $false

    if ($bundleExitCode -eq 0) {
        $aabPath = Join-Path $appDir "build\app\outputs\bundle\release\app-release.aab"
        if (Test-Path $aabPath) {
            $destAabPath = Join-Path $OUTPUT "$($app.OutputBase).aab"
            Copy-Item $aabPath $destAabPath -Force
            $aabSize = [math]::Round((Get-Item $destAabPath).Length / 1MB, 2)
            Write-Host "  SUCCESS! AAB: $($app.OutputBase).aab ($aabSize MB)" -ForegroundColor Green
            $aabOk = $true
        } else {
            Write-Host "  ERROR: AAB file not found at $aabPath" -ForegroundColor Red
        }
    } else {
        Write-Host "  AAB BUILD FAILED!" -ForegroundColor Red
        $bundleOutput | Select-Object -Last 15 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
    }

    $results += @{
        Name   = $app.Name
        Status = "APK=$apkOk AAB=$aabOk"
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  BUILD SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Output Folder: $OUTPUT" -ForegroundColor White
Write-Host ""

foreach ($r in $results) {
    $color = if ($r.Status -eq "APK=True AAB=True") { "Green" } else { "Yellow" }
    Write-Host "  $($r.Name): $($r.Status)" -ForegroundColor $color
}

Write-Host ""
$builtFiles = Get-ChildItem -Path $OUTPUT -File | Where-Object { $_.Extension -in ".apk", ".aab" }
$builtFiles | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host "    $($_.Name)  ($sizeMB MB)" -ForegroundColor White
}

if ($builtFiles.Count -gt 0) {
    $zipPath = Join-Path $OUTPUT "Agrimore-APK-AAB-Builds.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path ($builtFiles | Select-Object -ExpandProperty FullName) -DestinationPath $zipPath -Force
    Write-Host ""
    Write-Host "  Zip created: $zipPath" -ForegroundColor Green
}

$allSucceeded = ($results | Where-Object { $_.Status -ne "APK=True AAB=True" }).Count -eq 0
if (-not $allSucceeded) {
    exit 1
}
