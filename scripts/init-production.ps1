# Assistant mise en production — SombaTeka
# Lance toutes les etapes automatiques avant publication
param(
    [switch]$SkipDeploy,
    [switch]$SkipMobileBuild,
    [string]$ApiUrl = "https://api.sombateka.cd"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  SombaTeka — Preparation publication complete  " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Assets store + site web
Write-Host "[1/5] Generation assets (icone, banniere, favicons)..." -ForegroundColor Yellow
Push-Location (Join-Path $Root "mobile")
try {
    pip install -q -r scripts/requirements.txt 2>$null
    python scripts/generate_store_assets.py
}
finally {
    Pop-Location
}

# 2. Verification Firebase
Write-Host ""
Write-Host "[2/5] Verification Firebase..." -ForegroundColor Yellow
& (Join-Path $Root "mobile\scripts\setup-firebase.ps1")

# 3. Env production
Write-Host ""
Write-Host "[3/5] Configuration backend..." -ForegroundColor Yellow
$EnvExample = Join-Path $Root "backend\.env.production.example"
$EnvProd = Join-Path $Root "backend\.env.production"
if (-not (Test-Path $EnvProd)) {
    Copy-Item $EnvExample $EnvProd
    Write-Host "  -> Copie .env.production.example -> .env.production" -ForegroundColor Yellow
    Write-Host "  -> Remplissez JWT_SECRET, DB_PASSWORD, SMS, email avant deploy" -ForegroundColor Yellow
} else {
    Write-Host "  -> .env.production existe deja" -ForegroundColor Green
}

# 4. Deploy backend (optionnel)
if (-not $SkipDeploy) {
    Write-Host ""
    Write-Host "[4/5] Deploiement backend (Docker)..." -ForegroundColor Yellow
    $certPem = Join-Path $Root "nginx\ssl\cert.pem"
    if (-not (Test-Path $certPem)) {
        Write-Host "  -> TLS absent : generez certificats (nginx/ssl/README.md)" -ForegroundColor Yellow
        Write-Host "  -> Deploy ignore — relancez scripts\deploy-prod.ps1 apres TLS + secrets" -ForegroundColor Yellow
    } else {
        & (Join-Path $Root "scripts\deploy-prod.ps1") -SkipTlsCheck
    }
} else {
    Write-Host ""
    Write-Host "[4/5] Deploiement backend — IGNORE (-SkipDeploy)" -ForegroundColor DarkGray
}

# 5. Build Android AAB
if (-not $SkipMobileBuild) {
    Write-Host ""
    Write-Host "[5/5] Build Android AAB Play Store..." -ForegroundColor Yellow
    Push-Location (Join-Path $Root "mobile")
    try {
        & ".\scripts\publish-play-store.ps1" -ApiUrl $ApiUrl -SkipSigningSetup
    } catch {
        Write-Host "  -> Build echoue (Flutter/Java?) — voir mobile/STORE_RELEASE.md" -ForegroundColor Yellow
        Write-Host "  $_" -ForegroundColor DarkGray
    } finally {
        Pop-Location
    }
} else {
    Write-Host ""
    Write-Host "[5/5] Build mobile — IGNORE (-SkipMobileBuild)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  Etapes automatiques terminees                 " -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Actions manuelles restantes :" -ForegroundColor Yellow
Write-Host "  1. Remplir backend/.env.production (JWT, SMS, Mobile Money)"
Write-Host "  2. Certificats TLS + deploy : scripts\deploy-prod.ps1"
Write-Host "  3. Firebase reel : mobile\docs\FIREBASE_SETUP.md"
Write-Host "  4. Captures ecran : mobile\store\play\SCREENSHOTS.md"
Write-Host "  5. Compte Google Play (25 USD) + upload AAB"
Write-Host "  6. iOS : mobile\IOS_RELEASE.md"
Write-Host ""
Write-Host "Checklist complete : PRODUCTION_CHECKLIST.md"
