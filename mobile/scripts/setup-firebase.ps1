# Assistant configuration Firebase — SombaTeka
param(
    [switch]$OpenConsole
)

$ErrorActionPreference = "Stop"
$Mobile = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SombaTeka — Configuration Firebase      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$androidReal = Join-Path $Mobile "android\app\google-services.json"
$androidExample = Join-Path $Mobile "android\app\google-services.json.example"
$iosReal = Join-Path $Mobile "ios\Runner\GoogleService-Info.plist"
$iosExample = Join-Path $Mobile "ios\Runner\GoogleService-Info.plist.example"

Write-Host "Package Android : com.sombateka.st"
Write-Host "Bundle iOS      : com.sombateka.st"
Write-Host ""
Write-Host "Étapes :" -ForegroundColor Yellow
Write-Host "  1. Créer projet Firebase (sombateka-rdc)"
Write-Host "  2. Ajouter app Android → télécharger google-services.json"
Write-Host "  3. Ajouter app iOS → télécharger GoogleService-Info.plist"
Write-Host "  4. Configurer APNs pour iOS"
Write-Host "  5. Ajouter SHA-256 release Android"
Write-Host ""
Write-Host "Guide complet : mobile\docs\FIREBASE_SETUP.md"
Write-Host ""

if (Test-Path $androidReal) {
    $content = Get-Content $androidReal -Raw
    if ($content -match "123456789012|YOUR_PROJECT") {
        Write-Host "⚠️  google-services.json = PLACEHOLDER" -ForegroundColor Yellow
    } else {
        Write-Host "✅ google-services.json présent" -ForegroundColor Green
    }
} else {
    Write-Host "❌ google-services.json manquant" -ForegroundColor Red
    if (Test-Path $androidExample) {
        Write-Host "   Copiez depuis google-services.json.example après téléchargement Firebase"
    }
}

if (Test-Path $iosReal) {
    $content = Get-Content $iosReal -Raw
    if ($content -match "123456789012|YOUR_") {
        Write-Host "⚠️  GoogleService-Info.plist = PLACEHOLDER" -ForegroundColor Yellow
    } else {
        Write-Host "✅ GoogleService-Info.plist présent" -ForegroundColor Green
    }
} else {
    Write-Host "❌ GoogleService-Info.plist manquant" -ForegroundColor Red
}

if ($OpenConsole) {
    Start-Process "https://console.firebase.google.com/"
}

Write-Host ""
Write-Host "SHA-256 release (pour Firebase + assetlinks.json) :" -ForegroundColor Yellow
$ks = Join-Path $Mobile "android\sombateka-upload.jks"
if (Test-Path $ks) {
    keytool -list -v -keystore $ks -alias upload 2>$null | Select-String "SHA256"
} else {
    Write-Host "  Keystore absent — lancez d'abord scripts\setup-android-signing.ps1"
}
