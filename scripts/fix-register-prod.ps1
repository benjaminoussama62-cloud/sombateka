# Repare colonnes inscription + redémarre le backend (1 commande)
param(
    [string]$VpsHost = "sombateka-vps"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$BackendDir = Join-Path $RepoRoot "backend"

Write-Host ""
Write-Host "=== Fix inscription SombaTeka (schema users) ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1/4 Upload auth + users + messages + schemas ..." -ForegroundColor Yellow
$backendUploads = @(
    "app\models.py",
    "app\routers\auth.py",
    "app\routers\users.py",
    "app\routers\listings.py",
    "app\routers\messages.py",
    "app\schemas.py",
    "app\services\identity_validation.py",
    "app\services\email.py",
    "app\services\user_public.py",
    "app\startup.py"
)
foreach ($rel in $backendUploads) {
    $local = Join-Path $BackendDir $rel
    if (Test-Path $local) {
        $remotePath = $rel -replace '\\', '/'
        scp $local "${VpsHost}:~/SombaTeka/backend/$remotePath"
    }
}
$migration = Join-Path $BackendDir "alembic\versions\010_user_password_hash.py"
if (Test-Path $migration) {
    ssh $VpsHost "mkdir -p ~/SombaTeka/backend/alembic/versions"
    scp $migration "${VpsHost}:~/SombaTeka/backend/alembic/versions/010_user_password_hash.py"
}

Write-Host "2/4 SQL direct (colonnes users manquantes) ..." -ForegroundColor Yellow
$sql = @'
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_linked_at TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS official_name VARCHAR(120);
ALTER TABLE users ADD COLUMN IF NOT EXISTS official_logo_key VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_key VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS admin_password_hash VARCHAR(255);
ALTER TABLE users ADD COLUMN IF NOT EXISTS privacy_profile_public BOOLEAN DEFAULT true;
ALTER TABLE users ADD COLUMN IF NOT EXISTS privacy_show_phone BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS privacy_allow_messages BOOLEAN DEFAULT true;
'@
ssh $VpsHost "docker exec sombateka-db-prod psql -U sombateka -d sombateka_prod -c `"$sql`""

Write-Host "3/4 Rebuild backend + alembic ..." -ForegroundColor Yellow
$remoteCmd = @'
cd ~/SombaTeka/backend
export DB_PASSWORD="$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)"
docker compose -f docker-compose.prod.yml up -d --build --force-recreate backend
sleep 8
docker compose -f docker-compose.prod.yml exec -T backend alembic upgrade head
'@
ssh $VpsHost $remoteCmd

Write-Host "4/4 Test API inscription ..." -ForegroundColor Yellow
Start-Sleep -Seconds 8
$rnd = Get-Random -Minimum 1000000 -Maximum 9999999
$email = "fixcheck.$rnd@gmail.com"
$phone = "+24389$rnd"
try {
    $regPayload = @{
        email        = $email
        password     = "TestPlay2026!"
        phone_e164   = $phone
        display_name = "Fix Check"
    } | ConvertTo-Json -Compress
    $null = Invoke-RestMethod -Uri "https://sombatekaonline.com/api/auth/register" -Method POST -ContentType "application/json" -Body $regPayload
    Write-Host "  OK inscription test -> token recu" -ForegroundColor Green
} catch {
    Write-Host "  ECHEC test API:" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    else { Write-Host $_.Exception.Message }
}

Write-Host ""
Write-Host "Testez l'inscription sur https://sombatekaonline.com" -ForegroundColor Green
Write-Host ""
