# Cree le compte test Play Store directement en base (contourne bug API)
param(
    [string]$VpsHost = "root@164.90.214.206",
    [string]$Email = "test.playstore@sombatekaonline.com",
    [string]$Password = "TestPlay2026!",
    [string]$Phone = "+243989000099",
    [string]$Name = "Compte test beta"
)

$ErrorActionPreference = "Stop"
$BackendDir = Join-Path (Split-Path $PSScriptRoot -Parent) "backend"

Write-Host ""
Write-Host "=== Compte test Play Store ===" -ForegroundColor Cyan
Write-Host "  Email : $Email"
Write-Host "  Phone : $Phone"
Write-Host ""

Write-Host "Upload script..." -ForegroundColor Yellow
ssh $VpsHost "mkdir -p ~/SombaTeka/backend/scripts"
scp (Join-Path $BackendDir "scripts\create_playstore_user.py") "${VpsHost}:~/SombaTeka/backend/scripts/create_playstore_user.py"

Write-Host "Creation du compte dans le conteneur..." -ForegroundColor Yellow
$cmd = "docker cp ~/SombaTeka/backend/scripts/create_playstore_user.py sombateka-backend-prod:/app/scripts/create_playstore_user.py && docker exec -w /app sombateka-backend-prod python scripts/create_playstore_user.py '$Email' '$Password' '$Phone' '$Name'"
ssh $VpsHost $cmd

Write-Host ""
Write-Host "Connectez-vous sur le site ou l'app avec :" -ForegroundColor Green
Write-Host "  $Email"
Write-Host "  $Password"
Write-Host ""
Write-Host "Play Console -> Informations de connexion : utilisez ces identifiants."
Write-Host ""
