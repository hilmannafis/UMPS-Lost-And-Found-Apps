# Script to uninstall the app from connected Android device
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
$adbPath = "$env:ANDROID_HOME\platform-tools\adb.exe"

if (-not (Test-Path $adbPath)) {
    Write-Host "Error: ADB not found at $adbPath" -ForegroundColor Red
    Write-Host "Please ensure Android SDK is installed." -ForegroundColor Yellow
    exit 1
}

Write-Host "Checking connected devices..." -ForegroundColor Cyan
& $adbPath devices

Write-Host ""
Write-Host "Attempting to uninstall com.umpsa.lostandfound..." -ForegroundColor Yellow
$result = & $adbPath uninstall com.umpsa.lostandfound 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ App uninstalled successfully!" -ForegroundColor Green
} else {
    Write-Host "✗ Uninstall failed. Error:" -ForegroundColor Red
    Write-Host $result -ForegroundColor Red
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Yellow
    Write-Host "1. Device is offline - check USB connection and USB debugging" -ForegroundColor Gray
    Write-Host "2. App is not installed - you can proceed to install" -ForegroundColor Gray
    Write-Host "3. Insufficient permissions - try uninstalling manually from device" -ForegroundColor Gray
}

Write-Host ""
Write-Host "After uninstalling, run: flutter run" -ForegroundColor Cyan




