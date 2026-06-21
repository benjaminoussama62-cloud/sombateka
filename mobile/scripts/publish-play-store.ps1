# Pipeline complet : signature + assets + AAB Play Store
param(
    [string]$ApiUrl = "https://api.sombateka.cd",
    [string]$SentryDsn = "",
    [string]$TermsUrl = "https://sombateka.cd/terms",
    [string]$PrivacyUrl = "https://sombateka.cd/privacy",
    [switch]$SkipSigningSetup
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SombaTeka — Publication Play Store      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if (-not $SkipSigningSetup) {
    & "$PSScriptRoot\setup-android-signing.ps1"
}

if (-not (Test-Path "assets/icon/app_icon.png")) {
    Write-Host "→ Génération assets store (icône, feature graphic, favicons)..." -ForegroundColor Yellow
    pip install -q -r scripts/requirements.txt 2>$null
    python scripts/generate_store_assets.py
} else {
    python scripts/generate_store_assets.py 2>$null
}

flutter pub get
dart run flutter_launcher_icons 2>$null
dart run flutter_native_splash:create 2>$null

$defines = @(
    "--dart-define=ST_API_BASE_URL=$ApiUrl",
    "--dart-define=ST_TERMS_URL=$TermsUrl",
    "--dart-define=ST_PRIVACY_URL=$PrivacyUrl",
    "--dart-define=ST_DELETE_ACCOUNT_URL=https://sombateka.cd/account-deletion"
)
if ($SentryDsn) {
    $defines += "--dart-define=SENTRY_DSN=$SentryDsn"
}

$env:JAVA_HOME = if ($env:JAVA_HOME) { $env:JAVA_HOME } else { "C:\Android\AndroidStudio\jbr" }

Write-Host "→ Build App Bundle (release)..." -ForegroundColor Yellow
flutter build appbundle --release @defines

Write-Host ""
Write-Host "OK: PRÊT POUR PLAY STORE" -ForegroundColor Green
Write-Host ""
Write-Host "  AAB  : build/app/outputs/bundle/release/app-release.aab"
Write-Host "  Guide: store/play/PLAY_STORE_CHECKLIST.md"
Write-Host "  Fiche: store/play/listing-fr.md"
Write-Host ""
Write-Host "  Uploadez l'AAB sur https://play.google.com/console"
Write-Host ""
