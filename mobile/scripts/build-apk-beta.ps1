# Build APK pour tests beta (distribution WhatsApp, lien direct, etc.)
# Pas besoin du Play Store pour cette etape.
param(
    [string]$ApiUrl = "https://api.sombateka.cd",
    [string]$SentryDsn = ""
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "SombaTeka — Build APK beta (sideload)" -ForegroundColor Cyan
Write-Host "API : $ApiUrl"
Write-Host ""

if (-not (Test-Path "assets/icon/app_icon.png")) {
    python scripts/generate_store_assets.py
}

flutter pub get

$defines = @("--dart-define=ST_API_BASE_URL=$ApiUrl")
if ($SentryDsn) { $defines += "--dart-define=SENTRY_DSN=$SentryDsn" }

flutter build apk --release @defines
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERREUR: build APK echoue (code $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "Cause frequente: disque C: plein. Liberez de l espace puis relancez." -ForegroundColor Yellow
    exit $LASTEXITCODE
}

$apk = "build/app/outputs/flutter-apk/app-release.apk"
if (-not (Test-Path $apk)) {
    Write-Host "ERREUR: APK introuvable apres le build." -ForegroundColor Red
    exit 1
}
Write-Host ""
Write-Host "OK APK pret :" -ForegroundColor Green
Write-Host "  $apk"
Write-Host ""
Write-Host "Envoyez ce fichier a vos testeurs (WhatsApp, Drive, etc.)"
Write-Host "Sur le telephone : Autoriser installation sources inconnues"
Write-Host ""
Write-Host "IMPORTANT : le serveur $ApiUrl doit etre en ligne avec SMS configure."
