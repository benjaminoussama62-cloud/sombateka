# Diagnostic inscription prod (logs + schema + test API)
param(
    [string]$VpsHost = "sombateka-vps",
    [string]$Domain = "sombatekaonline.com"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Diagnostic inscription SombaTeka ===" -ForegroundColor Cyan
Write-Host ""

Write-Host "1/4 Colonnes users (password_hash, email, phone_linked_at) ..." -ForegroundColor Yellow
ssh $VpsHost @'
docker exec sombateka-db-prod psql -U sombateka -d sombateka_prod -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='users' AND column_name IN ('password_hash','email','email_verified','phone_linked_at','phone_e164') ORDER BY column_name;"
'@

Write-Host ""
Write-Host "2/4 Alembic (migration 010 password_hash) ..." -ForegroundColor Yellow
ssh $VpsHost @'
cd ~/SombaTeka/backend && export DB_PASSWORD="$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)" && docker compose -f docker-compose.prod.yml exec -T backend alembic current 2>&1
docker compose -f docker-compose.prod.yml exec -T backend alembic upgrade head 2>&1
'@

Write-Host ""
Write-Host "3/4 Derniers logs register ..." -ForegroundColor Yellow
ssh $VpsHost "docker logs sombateka-backend-prod --tail 120 2>&1" | Select-String -Pattern "register|password_hash|Inscription|ERROR|Exception" -CaseSensitive:$false

Write-Host ""
Write-Host "4/4 Test API inscription ..." -ForegroundColor Yellow
$rnd = Get-Random -Minimum 1000000 -Maximum 9999999
$email = "diag.$rnd@gmail.com"
$phone = "+24389$rnd"
$body = @{
    email        = $email
    password     = "TestPlay2026!"
    phone_e164   = $phone
    display_name = "Diag Test"
} | ConvertTo-Json -Compress
try {
    $r = Invoke-RestMethod -Uri "https://$Domain/api/auth/register" -Method POST -ContentType "application/json" -Body $body
    Write-Host "  OK token recu ($($r.access_token.Substring(0, [Math]::Min(24, $r.access_token.Length)))...)" -ForegroundColor Green
} catch {
    Write-Host "  ECHEC:" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    else { Write-Host $_.Exception.Message }
}

Write-Host ""
Write-Host "Si ECHEC : relancez .\scripts\fix-register-prod.ps1 puis retestez." -ForegroundColor Yellow
Write-Host ""
