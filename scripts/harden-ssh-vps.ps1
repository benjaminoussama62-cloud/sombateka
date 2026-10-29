# Desactive le login SSH par mot de passe sur le VPS (cle uniquement)
param(
    [string]$VpsHost = "sombateka-vps"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent
$Script = Join-Path $PSScriptRoot "harden-ssh-vps.sh"

Write-Host ""
Write-Host "=== Securisation SSH VPS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Verifications prealables ..." -ForegroundColor Yellow

ssh -o BatchMode=yes $VpsHost "echo cle_ssh_OK"
if ($LASTEXITCODE -ne 0) {
    throw "La cle SSH ne fonctionne pas. Lancez d'abord .\scripts\setup-ssh-key-vps.ps1"
}

Write-Host "  Cle SSH : OK" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT : gardez l'acces console de votre hebergeur (DigitalOcean)" -ForegroundColor Yellow
Write-Host "en cas de probleme rare de lockout." -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Desactiver le mot de passe SSH sur le VPS ? (oui/non)"
if ($confirm -notmatch '^(oui|o|yes|y)$') {
    Write-Host "Annule." -ForegroundColor Gray
    exit 0
}

Write-Host ""
scp $Script "${VpsHost}:/tmp/harden-ssh-vps.sh"
ssh $VpsHost "chmod +x /tmp/harden-ssh-vps.sh && bash /tmp/harden-ssh-vps.sh && rm -f /tmp/harden-ssh-vps.sh"

Write-Host ""
Write-Host "Test final sans mot de passe ..." -ForegroundColor Yellow
ssh -o BatchMode=yes $VpsHost "echo connexion_cle_seulement_OK"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Echec test — utilisez la console hebergeur pour restaurer sshd_config.bak-*" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Termine ===" -ForegroundColor Green
Write-Host "Le VPS n'accepte plus les mots de passe SSH." -ForegroundColor Green
Write-Host "Deploy : .\scripts\deploy-all.ps1"
Write-Host ""
