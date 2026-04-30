$targetDir = "C:\new\Agrimore-main\APK & AAB"
if (Test-Path $targetDir) {
    Remove-Item -Recurse -Force $targetDir
}
New-Item -ItemType Directory -Force -Path "$targetDir"

$apps = @(
    @{ Name = "Customer_App"; Path = "apps\marketplace" },
    @{ Name = "Seller_App"; Path = "apps\seller" },
    @{ Name = "Admin_App"; Path = "apps\admin" },
    @{ Name = "Delivery_App"; Path = "apps\delivery" }
)

foreach ($app in $apps) {
    $appName = $app.Name
    $appPath = $app.Path
    
    Write-Host "============================================="
    Write-Host "Building $appName..."
    Write-Host "============================================="
    
    # Create subfolder
    $appOutDir = "$targetDir\$appName"
    New-Item -ItemType Directory -Force -Path "$appOutDir"
    
    Set-Location -Path "C:\new\Agrimore-main\Agrimore-main\$appPath"
    
    # Build APK
    Write-Host "Running flutter build apk for $appName..."
    cmd /c flutter build apk --release
    if (Test-Path "build\app\outputs\flutter-apk\app-release.apk") {
        Copy-Item -Path "build\app\outputs\flutter-apk\app-release.apk" -Destination "$appOutDir\$appName.apk" -Force
        Write-Host "Successfully copied $appName.apk"
    } else {
        Write-Host "Failed to find APK for $appName"
    }
    
    # Build AAB
    Write-Host "Running flutter build appbundle for $appName..."
    cmd /c flutter build appbundle --release
    if (Test-Path "build\app\outputs\bundle\release\app-release.aab") {
        Copy-Item -Path "build\app\outputs\bundle\release\app-release.aab" -Destination "$appOutDir\$appName.aab" -Force
        Write-Host "Successfully copied $appName.aab"
    } else {
        Write-Host "Failed to find AAB for $appName"
    }
}

Write-Host "============================================="
Write-Host "All builds completed and copied to $targetDir"
Write-Host "============================================="
