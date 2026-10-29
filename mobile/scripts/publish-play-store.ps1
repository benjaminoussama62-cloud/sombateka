# Pipeline complet : signature + assets + AAB Play Store
param(
    [string]$ApiUrl = "https://sombatekaonline.com",
    [string]$SentryDsn = "",
    [string]$TermsUrl = "https://sombatekaonline.com/terms",
    [string]$PrivacyUrl = "https://sombatekaonline.com/privacy",
    [string]$DeleteAccountUrl = "https://sombatekaonline.com/account-deletion",
    [switch]$DisableSocialAuth,
    [string]$GoogleWebClientId = "508328631175-2gpdu705sfbqa8anhj71m42tsf9dpk5p.apps.googleusercontent.com",
    [string]$AppleTeamId = "",
    [switch]$SkipSigningSetup
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "SombaTeka - Publication Play Store" -ForegroundColor Cyan
Write-Host ""

if (-not $SkipSigningSetup) {
    & "$PSScriptRoot\setup-android-signing.ps1"
}

& "$PSScriptRoot\update-deep-links.ps1" -AppleTeamId $AppleTeamId

if (-not (Test-Path "assets/icon/app_icon.png")) {
    Write-Host "Generation assets store..." -ForegroundColor Yellow
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
    "--dart-define=ST_DELETE_ACCOUNT_URL=$DeleteAccountUrl"
)
if ($SentryDsn) {
    $defines += "--dart-define=SENTRY_DSN=$SentryDsn"
}
if (-not $DisableSocialAuth) {
    $defines += "--dart-define=ST_SOCIAL_AUTH_ENABLED=true"
    $defines += "--dart-define=ST_APPLE_SIGNIN_ENABLED=true"
    if ($GoogleWebClientId) {
        $defines += "--dart-define=ST_GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId"
    }
}

function Resolve-JavaHome {
    if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME "bin\java.exe"))) {
        return $env:JAVA_HOME
    }
    $candidates = @(
        "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot",
        "C:\Program Files\Android\Android Studio\jbr",
        "C:\Android\AndroidStudio\jbr"
    )
    foreach ($jdk in $candidates) {
        if (Test-Path (Join-Path $jdk "bin\java.exe")) { return $jdk }
    }
    $adoptium = Get-ChildItem "C:\Program Files\Eclipse Adoptium\jdk-*" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($adoptium -and (Test-Path (Join-Path $adoptium.FullName "bin\java.exe"))) {
        return $adoptium.FullName
    }
    throw "JDK introuvable. Installez JDK 17 ou Android Studio, ou definissez JAVA_HOME."
}

$env:JAVA_HOME = Resolve-JavaHome
Write-Host "  JAVA_HOME : $env:JAVA_HOME" -ForegroundColor DarkGray

Write-Host "Build App Bundle (release)..." -ForegroundColor Yellow
flutter build appbundle --release @defines
if ($LASTEXITCODE -ne 0) {
    throw "flutter build appbundle a echoue (code $LASTEXITCODE)"
}

Write-Host ""
Write-Host "OK: PRET POUR PLAY STORE" -ForegroundColor Green
Write-Host ""
Write-Host "  AAB  : build/app/outputs/bundle/release/app-release.aab"
Write-Host "  Guide: store/play/LANCEMENT_PLAY_STORE.md"
Write-Host "  OAuth: docs/SOCIAL_AUTH_SETUP.md"
Write-Host "  Play : https://play.google.com/console"
Write-Host ""
