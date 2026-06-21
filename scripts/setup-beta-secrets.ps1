# Genere les secrets pour la phase beta et prepare .env.production
param(
    [switch]$ApplyBetaTemplate
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Backend = Join-Path $Root "backend"
$EnvProd = Join-Path $Backend ".env.production"
$EnvBeta = Join-Path $Backend ".env.beta.example"

function New-Secret([int]$Bytes = 32) {
    $b = New-Object byte[] $Bytes
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    return [BitConverter]::ToString($b).Replace("-", "").ToLower()
}

$jwt = New-Secret 32
$dbPass = New-Secret 16
$adminPass = New-Secret 12

Write-Host ""
Write-Host "SombaTeka - Generation secrets beta" -ForegroundColor Cyan
Write-Host ""

if ($ApplyBetaTemplate -or -not (Test-Path $EnvProd)) {
    Copy-Item $EnvBeta $EnvProd -Force
    Write-Host "Template beta copie -> .env.production" -ForegroundColor Yellow
}

$content = Get-Content $EnvProd -Raw
$content = $content -replace '(?m)^JWT_SECRET=.*', "JWT_SECRET=$jwt"
$content = $content -replace '(?m)^DB_PASSWORD=.*', "DB_PASSWORD=$dbPass"
$content = $content -replace '(?m)^ADMIN_PANEL_PASSWORD=.*', "ADMIN_PANEL_PASSWORD=$adminPass"
$content = $content -replace '(?m)^DATABASE_URL=.*', "DATABASE_URL=postgresql+psycopg://sombateka:${dbPass}@db:5432/sombateka_prod"
Set-Content -Path $EnvProd -Value $content -NoNewline

$secretsFile = Join-Path $Backend "secrets-beta.local.txt"
$lines = @(
    "SombaTeka - Secrets beta (GARDEZ CE FICHIER EN SECRET)"
    "Genere le: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    ""
    "JWT_SECRET=$jwt"
    "DB_PASSWORD=$dbPass"
    "ADMIN_PANEL_PASSWORD=$adminPass"
    ""
    "Admin panel: https://VOTRE-DOMAINE/admin"
    "Mot de passe admin: $adminPass"
)
Set-Content -Path $secretsFile -Value $lines

Write-Host "Secrets generes:" -ForegroundColor Green
Write-Host "  backend\.env.production"
Write-Host "  backend\secrets-beta.local.txt  (NE PAS PARTAGER)"
Write-Host ""
Write-Host "Prochaines etapes:" -ForegroundColor Yellow
Write-Host "  1. Louer un VPS (Hetzner, DigitalOcean, Contabo...)"
Write-Host "  2. Configurer Africas Talking SMS - BETA_PHASE1.md etape 2"
Write-Host "  3. Uploader le projet sur le VPS et lancer deploy-vps.sh"
Write-Host ""
Write-Host "Guide complet: BETA_PHASE1.md"
