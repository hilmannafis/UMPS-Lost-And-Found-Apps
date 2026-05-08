# PowerShell script to fix device installation issues
# This script will help uninstall the app and reconnect the device

Write-Host "=== Flutter Device Installation Fix ===" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check Flutter doctor
Write-Host "Step 1: Checking Flutter setup..." -ForegroundColor Yellow
flutter doctor -v

Write-Host ""
Write-Host "Step 2: Checking connected devices..." -ForegroundColor Yellow
flutter devices

Write-Host ""
Write-Host "=== Manual Steps Required ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. On your Samsung device (SM N770F):" -ForegroundColor White
Write-Host "   - Go to Settings > Apps" -ForegroundColor Gray
Write-Host "   - Find 'lost_and_found_app' or 'Lost and Found'" -ForegroundColor Gray
Write-Host "   - Tap it and select 'Uninstall'" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Reconnect your device:" -ForegroundColor White
Write-Host "   - Unplug USB cable" -ForegroundColor Gray
Write-Host "   - Wait 5 seconds" -ForegroundColor Gray
Write-Host "   - Plug back in" -ForegroundColor Gray
Write-Host "   - On phone: Allow USB debugging when prompted" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Enable USB Debugging (if not already):" -ForegroundColor White
Write-Host "   - Settings > Developer Options > USB Debugging (ON)" -ForegroundColor Gray
Write-Host ""
Write-Host "4. After completing above steps, run:" -ForegroundColor White
Write-Host "   flutter run -d <device-id>" -ForegroundColor Green
Write-Host ""

# Try to find ADB through Flutter SDK
$flutterPath = (Get-Command flutter -ErrorAction SilentlyContinue).Source
if ($flutterPath) {
    $flutterBin = Split-Path $flutterPath
    $adbPath = Join-Path $flutterBin "cache\artifacts\engine\android-arm\adb.exe"
    if (Test-Path $adbPath) {
        Write-Host "Found ADB at: $adbPath" -ForegroundColor Green
        Write-Host ""
        Write-Host "To uninstall app manually via ADB, run:" -ForegroundColor Yellow
        Write-Host "& '$adbPath' uninstall com.umpsa.lostandfound" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Press any key to check devices again..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "Rechecking devices..." -ForegroundColor Yellow
flutter devices




