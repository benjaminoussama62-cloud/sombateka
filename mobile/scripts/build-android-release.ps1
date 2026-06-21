param(
    [Parameter(Mandatory = $true)]
    [string]$ApiUrl,
    [string]$SentryDsn = "",
    [string]$TermsUrl = "https://sombateka.cd/terms",
    [string]$PrivacyUrl = "https://sombateka.cd/privacy"
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "==> SombaTeka — build Android App Bundle (release)" -ForegroundColor Cyan

if (-not (Test-Path "assets/icon/app_icon.png")) {
    Write-Host "Génération icône..." -ForegroundColor Yellow
    python scripts/generate_app_icon.py
}

flutter pub get
dart run flutter_launcher_icons 2>$null
dart run flutter_native_splash:create 2>$null

$defines = @(
    "--dart-define=ST_API_BASE_URL=$ApiUrl",
    "--dart-define=ST_TERMS_URL=$TermsUrl",
    "--dart-define=ST_PRIVACY_URL=$PrivacyUrl"
)
if ($SentryDsn) {
    $defines += "--dart-define=SENTRY_DSN=$SentryDsn"
}

flutter build appbundle --release @defines

Write-Host ""
Write-Host "OK: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Green
