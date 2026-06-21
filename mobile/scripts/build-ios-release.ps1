param(
    [Parameter(Mandatory = $true)]
    [string]$ApiUrl,
    [string]$SentryDsn = "",
    [string]$TermsUrl = "https://sombateka.cd/terms",
    [string]$PrivacyUrl = "https://sombateka.cd/privacy"
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host "==> SombaTeka — build iOS (release, sans signature IPA)" -ForegroundColor Cyan

if (-not (Test-Path "assets/icon/app_icon.png")) {
    python scripts/generate_store_assets.py
}

flutter pub get
dart run flutter_launcher_icons 2>$null
dart run flutter_native_splash:create 2>$null

Push-Location ios
if (-not (Test-Path "Podfile.lock")) {
    pod install
}
Pop-Location

$defines = @(
    "--dart-define=ST_API_BASE_URL=$ApiUrl",
    "--dart-define=ST_TERMS_URL=$TermsUrl",
    "--dart-define=ST_PRIVACY_URL=$PrivacyUrl"
)
if ($SentryDsn) {
    $defines += "--dart-define=SENTRY_DSN=$SentryDsn"
}

flutter build ios --release @defines --no-codesign

Write-Host ""
Write-Host "OK: ouvrez ios/Runner.xcworkspace dans Xcode → Archive → Distribute" -ForegroundColor Green
