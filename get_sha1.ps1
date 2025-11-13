# PowerShell script to get SHA-1 fingerprint for Firebase configuration
Write-Host "Getting SHA-1 fingerprint from debug keystore..." -ForegroundColor Green

$keystorePath = "$env:USERPROFILE\.android\debug.keystore"

if (Test-Path $keystorePath) {
    Write-Host "`nSHA-1 Fingerprint:" -ForegroundColor Yellow
    keytool -list -v -keystore $keystorePath -alias androiddebugkey -storepass android -keypass android | Select-String -Pattern "SHA1:"
    
    Write-Host "`nSHA-256 Fingerprint:" -ForegroundColor Yellow
    keytool -list -v -keystore $keystorePath -alias androiddebugkey -storepass android -keypass android | Select-String -Pattern "SHA256:"
    
    Write-Host "`nCopy the SHA-1 value (without 'SHA1:') and add it to Firebase Console:" -ForegroundColor Cyan
    Write-Host "1. Go to Firebase Console > Project Settings > Your Apps > Android App" -ForegroundColor White
    Write-Host "2. Click 'Add fingerprint' and paste the SHA-1 value" -ForegroundColor White
    Write-Host "3. Download the updated google-services.json file" -ForegroundColor White
    Write-Host "4. Replace the current google-services.json file in android/app/" -ForegroundColor White
} else {
    Write-Host "Debug keystore not found at: $keystorePath" -ForegroundColor Red
    Write-Host "The keystore will be created automatically when you first run the app." -ForegroundColor Yellow
}


