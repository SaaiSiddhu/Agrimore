$ErrorActionPreference = "Continue"
$env:PATH = "C:\agrimore\flutter_windows_3.41.6-stable\flutter\bin;" + $env:PATH

$BASE = "c:\new\Agrimore-main\Agrimore-main\apps"
$OUTPUT = "C:\new\Agrimore_APK_Builds"

# Create output directory
New-Item -ItemType Directory -Path $OUTPUT -Force | Out-Null

$apps = @(
    @{ Name = "Seller";      Dir = "seller";      OutputName = "Agrimore-Seller.apk" },
    @{ Name = "Delivery";    Dir = "delivery";    OutputName = "Agrimore-Delivery.apk" },
    @{ Name = "Admin";       Dir = "admin";       OutputName = "Agrimore-Admin.apk" }
)

$results = @()

foreach ($app in $apps) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Building: $($app.Name)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    
    $appDir = Join-Path $BASE $app.Dir
    Set-Location $appDir
    
    # Clean
    Write-Host "  Cleaning..." -ForegroundColor Yellow
    flutter clean 2>&1 | Out-Null
    
    # Get deps
    Write-Host "  Getting dependencies..." -ForegroundColor Yellow
    flutter pub get 2>&1 | Out-Null
    
    # Build
    Write-Host "  Building APK (release)..." -ForegroundColor Yellow
    $buildOutput = flutter build apk --release 2>&1
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -eq 0) {
        # Find the APK
        $apkPath = Join-Path $appDir "build\app\outputs\flutter-apk\app-release.apk"
        if (Test-Path $apkPath) {
            $destPath = Join-Path $OUTPUT $app.OutputName
            Copy-Item $apkPath $destPath -Force
            $size = [math]::Round((Get-Item $destPath).Length / 1MB, 2)
            Write-Host "  SUCCESS! APK: $($app.OutputName) ($size MB)" -ForegroundColor Green
            $results += @{ Name = $app.Name; Status = "SUCCESS"; Size = "$size MB" }
        } else {
            Write-Host "  ERROR: APK file not found at $apkPath" -ForegroundColor Red
            $results += @{ Name = $app.Name; Status = "FAILED - APK not found"; Size = "-" }
        }
    } else {
        Write-Host "  BUILD FAILED!" -ForegroundColor Red
        # Print last 15 lines of error
        $buildOutput | Select-Object -Last 15 | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
        $results += @{ Name = $app.Name; Status = "FAILED"; Size = "-" }
    }
}

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  BUILD SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Output Folder: $OUTPUT" -ForegroundColor White
Write-Host ""

foreach ($r in $results) {
    $color = if ($r.Status -eq "SUCCESS") { "Green" } else { "Red" }
    Write-Host "  $($r.Name): $($r.Status) $($r.Size)" -ForegroundColor $color
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan

# List output folder
Write-Host ""
Write-Host "  Files in output folder:" -ForegroundColor Yellow
Get-ChildItem $OUTPUT -Filter "*.apk" | ForEach-Object {
    $sizeMB = [math]::Round($_.Length / 1MB, 2)
    Write-Host "    $($_.Name)  ($sizeMB MB)" -ForegroundColor White
}
