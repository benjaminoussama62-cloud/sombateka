# Préparation soumission App Store — SombaTeka (Windows)
param(
    [string]$ApiUrl = "https://api.sombateka.cd",
    [string]$SentryDsn = ""
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SombaTeka — Préparation App Store       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

& "$PSScriptRoot\setup-firebase.ps1"

python scripts/generate_store_assets.py

& "$PSScriptRoot\build-ios-release.ps1" -ApiUrl $ApiUrl -SentryDsn $SentryDsn

Write-Host ""
Write-Host "Prochaines étapes (sur Mac) :" -ForegroundColor Yellow
Write-Host "  1. Copier le projet ou cloner sur Mac"
Write-Host "  2. ios/Runner.xcworkspace → Archive"
Write-Host "  3. Export avec ios/ExportOptions.plist (teamID)"
Write-Host "  4. Upload Transporter → TestFlight"
Write-Host ""
Write-Host "Guide : IOS_RELEASE.md"
Write-Host "Checklist : store/ios/APP_STORE_CHECKLIST.md"
