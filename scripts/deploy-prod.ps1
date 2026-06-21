# SombaTeka — Déploiement production (Windows)
param(
    [switch]$SkipTlsCheck
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Backend = Join-Path $Root "backend"
$EnvProd = Join-Path $Backend ".env.production"
$EnvExample = Join-Path $Backend ".env.production.example"

Write-Host ""
Write-Host "╔══════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  SombaTeka — Déploiement production      ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $EnvProd)) {
    if (Test-Path $EnvExample) {
        Copy-Item $EnvExample $EnvProd
        Write-Host "→ Copié .env.production.example → .env.production" -ForegroundColor Yellow
        Write-Host "  Remplissez les secrets puis relancez ce script." -ForegroundColor Yellow
        exit 1
    }
    throw "Fichier .env.production manquant dans backend/"
}

$certPem = Join-Path $Root "nginx\ssl\cert.pem"
$keyPem = Join-Path $Root "nginx\ssl\key.pem"
if (-not $SkipTlsCheck -and (-not (Test-Path $certPem) -or -not (Test-Path $keyPem))) {
    Write-Host "⚠️  Certificats TLS absents (nginx/ssl/). Voir nginx/ssl/README.md" -ForegroundColor Yellow
}

if (-not $env:DB_PASSWORD) {
    $line = Get-Content $EnvProd | Where-Object { $_ -match '^DB_PASSWORD=' } | Select-Object -First 1
    if ($line) {
        $env:DB_PASSWORD = ($line -split '=', 2)[1]
    }
}

if (-not $env:DB_PASSWORD -or $env:DB_PASSWORD -match 'CHANGE_ME') {
    throw "Définissez DB_PASSWORD dans .env.production ou en variable d'environnement."
}

Push-Location $Backend
try {
    docker compose -f docker-compose.prod.yml up -d --build
    Write-Host ""
    Write-Host "OK Stack demarree" -ForegroundColor Green
    Write-Host "   API  : https://api.sombateka.cd/healthz"
    Write-Host "   Site : https://sombateka.cd"
}
finally {
    Pop-Location
}
