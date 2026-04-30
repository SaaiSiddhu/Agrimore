$flutterPath = 'C:\agrimore\flutter_windows_3.41.6-stable\flutter\bin\flutter.bat'
$basePath = 'C:\new\Agrimore-main\Agrimore-main\apps'
$apps = @('admin', 'marketplace', 'seller', 'delivery')

$outDir = 'C:\new\Agrimore-main\Agrimore-main\apks'
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

foreach ($app in $apps) {
    Write-Host "Building $app..."
    Set-Location "$basePath\$app"
    & $flutterPath clean
    & $flutterPath pub get
    & $flutterPath build apk --release
    
    $apkPath = "$basePath\$app\build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $destPath = "$outDir\${app}_app.apk"
        Copy-Item -Path $apkPath -Destination $destPath -Force
        Write-Host "Successfully built and copied $app to $destPath"
    } else {
        Write-Host "Failed to build $app"
    }
}

Write-Host "Zipping all APKs..."
$zipPath = 'C:\new\Agrimore-main\Agrimore-main\agrimore_all_apps.zip'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$outDir\*.apk" -DestinationPath $zipPath -Force
Write-Host "Done! Zip file created at $zipPath"
