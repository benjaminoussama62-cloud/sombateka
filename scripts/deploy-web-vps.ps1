# Deploy web-dist/ + nginx + admin + backend FULL to VPS
param(
    [string]$VpsHost = "sombateka-vps",
    [string]$RemoteDir = "~/SombaTeka/web-dist",
    [string]$Domain = "sombatekaonline.com",
    [string]$ApiUrl = "https://sombatekaonline.com",
    [switch]$SkipBuild,
    [switch]$SkipVpsRestart
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$WebDist = Join-Path $RepoRoot "web-dist"
$BackendDir = Join-Path $RepoRoot "backend"
$NginxDir = Join-Path $RepoRoot "nginx"

if (-not $SkipBuild) {
    & (Join-Path $RepoRoot "mobile\scripts\build-web-prod.ps1") -ApiUrl $ApiUrl -Domain $Domain
} else {
    $legal = Join-Path $RepoRoot "website"
    foreach ($f in @("terms.html", "privacy.html", "account-deletion.html", "robots.txt", "sitemap.xml", "sitemap-index.xml", "marketplace-rdc.html", "kinshasa.html")) {
        $src = Join-Path $legal $f
        if (Test-Path $src) { Copy-Item $src $WebDist -Force }
    }
    $aboutSrc = Join-Path $legal "index.html"
    if (Test-Path $aboutSrc) {
        Copy-Item $aboutSrc (Join-Path $WebDist "about.html") -Force
    }
    $css = Join-Path $legal "assets\style.css"
    if (Test-Path $css) {
        New-Item -ItemType Directory -Path (Join-Path $WebDist "assets") -Force | Out-Null
        Copy-Item $css (Join-Path $WebDist "assets\style.css") -Force
    }
    $og = Join-Path $legal "assets\og-image.png"
    if (Test-Path $og) {
        New-Item -ItemType Directory -Path (Join-Path $WebDist "assets") -Force | Out-Null
        Copy-Item $og (Join-Path $WebDist "assets\og-image.png") -Force
    }
    $storeBadges = Join-Path $legal "assets\stores"
    if (Test-Path $storeBadges) {
        $destStores = Join-Path $WebDist "assets\stores"
        New-Item -ItemType Directory -Path $destStores -Force | Out-Null
        Copy-Item (Join-Path $storeBadges "*") $destStores -Force
    }
}

if (-not (Test-Path $WebDist)) {
    throw "web-dist/ missing - run build-web-prod.ps1 first"
}

Write-Host ""
Write-Host "=== SombaTeka deploy VPS ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1/5 Upload web-dist ..." -ForegroundColor Yellow
ssh $VpsHost "mkdir -p $RemoteDir ~/SombaTeka/nginx/conf.d ~/SombaTeka/nginx/snippets"
Get-ChildItem -Path $WebDist | ForEach-Object { scp -r $_.FullName "${VpsHost}:${RemoteDir}/" }
Write-Host "  -> Permissions lecture (nginx) ..." -ForegroundColor DarkGray
ssh $VpsHost "chmod -R a+rX $RemoteDir 2>/dev/null || chmod -R 755 $RemoteDir"

Write-Host "2/5 Upload nginx (conf + snippets) + admin + backend/app ..." -ForegroundColor Yellow
scp (Join-Path $NginxDir "nginx.conf") "${VpsHost}:~/SombaTeka/nginx/nginx.conf"
scp (Join-Path $NginxDir "conf.d\30-unified-webapp.conf") "${VpsHost}:~/SombaTeka/nginx/conf.d/30-unified-webapp.conf"
scp (Join-Path $NginxDir "snippets\security-headers.conf") "${VpsHost}:~/SombaTeka/nginx/snippets/security-headers.conf"
scp (Join-Path $NginxDir "snippets\proxy-backend.conf") "${VpsHost}:~/SombaTeka/nginx/snippets/proxy-backend.conf"

$AdminPanel = Join-Path $BackendDir "admin-panel"
if (Test-Path $AdminPanel) {
    ssh $VpsHost "mkdir -p ~/SombaTeka/backend/admin-panel"
    Get-ChildItem -Path $AdminPanel | ForEach-Object { scp -r $_.FullName "${VpsHost}:~/SombaTeka/backend/admin-panel/" }
}

# Full app tree via scp (tar Windows corrompt parfois les .py sur le VPS)
Write-Host "  -> Sync backend/app + alembic + requirements + compose ..." -ForegroundColor DarkGray
ssh $VpsHost "mkdir -p ~/SombaTeka/backend/app ~/SombaTeka/backend/alembic/versions"
scp -r (Join-Path $BackendDir "app") "${VpsHost}:~/SombaTeka/backend/"
if (Test-Path (Join-Path $BackendDir "alembic")) {
    scp -r (Join-Path $BackendDir "alembic") "${VpsHost}:~/SombaTeka/backend/"
}
foreach ($f in @("requirements.txt", "Dockerfile", "entrypoint.sh", "docker-compose.prod.yml")) {
    $local = Join-Path $BackendDir $f
    if (Test-Path $local) {
        scp $local "${VpsHost}:~/SombaTeka/backend/$f"
    }
}

if (-not $SkipVpsRestart) {
    Write-Host "3/5 Ensure REDIS_PASSWORD + JWT TTL in .env.production ..." -ForegroundColor Yellow
    $ensureEnv = @'
set -euo pipefail
cd ~/SombaTeka/backend
ENVF=.env.production
touch "$ENVF"
ensure_kv() {
  local key="$1" val="$2"
  if grep -q "^${key}=" "$ENVF" 2>/dev/null; then
    cur="$(grep "^${key}=" "$ENVF" | head -1 | cut -d= -f2-)"
    if [ -z "$cur" ] || [ "$cur" = "CHANGE_ME" ] || [ "$cur" = "CHANGE_ME_STRONG_REDIS_PASSWORD" ]; then
      sed -i "s|^${key}=.*|${key}=${val}|" "$ENVF"
    fi
  else
    echo "${key}=${val}" >> "$ENVF"
  fi
}
# Generate Redis password once if missing
if ! grep -q '^REDIS_PASSWORD=.\+' "$ENVF" 2>/dev/null; then
  RP="$(openssl rand -hex 24)"
  ensure_kv REDIS_PASSWORD "$RP"
  echo "  Generated REDIS_PASSWORD"
fi
# Cap JWT if missing / too long
if ! grep -q '^ACCESS_TOKEN_MINUTES=' "$ENVF" 2>/dev/null; then
  echo "ACCESS_TOKEN_MINUTES=60" >> "$ENVF"
else
  mins="$(grep '^ACCESS_TOKEN_MINUTES=' "$ENVF" | head -1 | cut -d= -f2-)"
  if [ -n "$mins" ] && [ "$mins" -gt 120 ] 2>/dev/null; then
    sed -i 's|^ACCESS_TOKEN_MINUTES=.*|ACCESS_TOKEN_MINUTES=60|' "$ENVF"
  fi
fi
# Sentry / uptime hooks remain optional (document in .env.production.example)
grep -q '^SENTRY_DSN=' "$ENVF" || echo "SENTRY_DSN=" >> "$ENVF"
grep -q '^ADMIN_IP_ALLOWLIST=' "$ENVF" || echo "ADMIN_IP_ALLOWLIST=" >> "$ENVF"
'@
    ssh $VpsHost $ensureEnv

    Write-Host "4/5 Rebuild backend + celery + nginx ..." -ForegroundColor Yellow
    $remoteCmd = @'
set -euo pipefail
cd ~/SombaTeka/backend
chmod -R a+rX ../web-dist 2>/dev/null || chmod -R 755 ../web-dist
mv ~/SombaTeka/nginx/conf.d/10-api.conf ~/SombaTeka/nginx/conf.d/10-api.conf.bak 2>/dev/null || true
mv ~/SombaTeka/nginx/conf.d/20-web.conf ~/SombaTeka/nginx/conf.d/20-web.conf.bak 2>/dev/null || true
export DB_PASSWORD="$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)"
export REDIS_PASSWORD="$(grep '^REDIS_PASSWORD=' .env.production | cut -d= -f2-)"
if [ -z "${REDIS_PASSWORD:-}" ]; then
  echo "REDIS_PASSWORD missing in .env.production" >&2
  exit 1
fi
# Full recreate so redis auth + celery-beat env take effect
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build --force-recreate \
  redis backend celery-worker celery-beat nginx
docker compose -f docker-compose.prod.yml --env-file .env.production exec -T backend alembic upgrade head || true
'@
    ssh $VpsHost $remoteCmd
}

Write-Host "5/5 Health checks ..." -ForegroundColor Yellow
Start-Sleep -Seconds 18
& (Join-Path $PSScriptRoot "smoke-test-prod.ps1") -Domain $Domain
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ATTENTION: smoke test en echec - voir scripts/GO_LIVE_CHECKLIST.md" -ForegroundColor Red
}

Write-Host ""
Write-Host "OK - Deploy termine." -ForegroundColor Green
Write-Host "  App    : https://$Domain/"
Write-Host "  Admin  : https://$Domain/admin/login"
Write-Host ""
Write-Host "Securite: headers HSTS sur PWA, /.env -> 404, Redis auth, WS auth, celery-beat env."
Write-Host "Optionnel: ADMIN_IP_ALLOWLIST=ton.ip dans .env.production ; SENTRY_DSN=..."
Write-Host ""
