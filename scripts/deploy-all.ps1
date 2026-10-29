# Deploiement complet SombaTeka : PWA/web + backend + admin (+ option Android AAB)
param(
    [string]$VpsHost = "sombateka-vps",
    [string]$Domain = "sombatekaonline.com",
    [string]$ApiUrl = "https://sombatekaonline.com",
    [switch]$SkipBuild,
    [switch]$SkipVpsRestart,
    [switch]$BuildAndroid,
    [switch]$SkipAndroidSigningSetup
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "=== SombaTeka - deploiement general ===" -ForegroundColor Cyan
Write-Host "  Domaine : $Domain"
Write-Host "  API     : $ApiUrl"
Write-Host ""

& (Join-Path $PSScriptRoot "deploy-web-vps.ps1") `
    -VpsHost $VpsHost `
    -Domain $Domain `
    -ApiUrl $ApiUrl `
    -SkipBuild:$SkipBuild `
    -SkipVpsRestart:$SkipVpsRestart

if ($BuildAndroid) {
    Write-Host ""
    Write-Host "=== Build Android (Play Store AAB) ===" -ForegroundColor Cyan
    $androidArgs = @{
        ApiUrl           = $ApiUrl
        TermsUrl         = "https://$Domain/terms"
        PrivacyUrl       = "https://$Domain/privacy"
        DeleteAccountUrl = "https://$Domain/account-deletion"
    }
    if ($SkipAndroidSigningSetup) {
        $androidArgs.SkipSigningSetup = $true
    }
    & (Join-Path $RepoRoot "mobile\scripts\publish-play-store.ps1") @androidArgs
}

Write-Host ""
Write-Host "=== Recapitulatif ===" -ForegroundColor Green
Write-Host "  PWA / Web PC : https://$Domain/"
Write-Host "  Admin        : https://$Domain/admin/login"
Write-Host "  API health   : https://$Domain/healthz"
if ($BuildAndroid) {
    Write-Host "  Android AAB  : mobile\build\app\outputs\bundle\release\app-release.aab"
}
Write-Host ""
Write-Host "Checklist post-deploiement :" -ForegroundColor Yellow
Write-Host "  - Inscription : https://$Domain/ (sans code e-mail a la creation)"
Write-Host "  - Verification compte : Parametres -> Verifier mon compte"
Write-Host "  - Resend (e-mail) : EMAIL_PROVIDER=resend dans .env.production sur le VPS"
Write-Host "  - Google OAuth : https://$Domain dans Google Cloud Console"
Write-Host "  - PWA iPhone   : supprimer icone puis re-ajouter ecran accueil"
Write-Host "  - Play Store   : uploader le AAB si BuildAndroid (-BuildAndroid)"
Write-Host "  - Checklist    : scripts/GO_LIVE_CHECKLIST.md"
Write-Host "  - Smoke test   : .\scripts\smoke-test-prod.ps1"
Write-Host ""
