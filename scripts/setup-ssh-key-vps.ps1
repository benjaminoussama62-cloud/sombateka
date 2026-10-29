# Configure la cle SSH pour le VPS SombaTeka (mot de passe demande UNE derniere fois)
param(
    [string]$VpsHost = "root@164.90.214.206",
    [string]$SshAlias = "sombateka-vps",
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_ed25519"
)

$ErrorActionPreference = "Stop"
$PubKeyPath = "$KeyPath.pub"
$SshDir = "$env:USERPROFILE\.ssh"
$ConfigPath = Join-Path $SshDir "config"

Write-Host ""
Write-Host "=== Configuration cle SSH SombaTeka ===" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $PubKeyPath)) {
    Write-Host "Aucune cle trouvee. Generation ed25519 ..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $SshDir -Force | Out-Null
    ssh-keygen -t ed25519 -C "sombateka-deploy" -f $KeyPath -N '""'
}

Write-Host "Cle : $PubKeyPath" -ForegroundColor Gray
Write-Host ""
Write-Host "Copie sur le VPS (mot de passe root demande UNE fois) ..." -ForegroundColor Yellow
Write-Host ""

scp $PubKeyPath "${VpsHost}:/tmp/sombateka_deploy.pub"
if ($LASTEXITCODE -ne 0) { throw "Echec scp" }

ssh $VpsHost @'
set -e
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
if ! grep -qxF "$(cat /tmp/sombateka_deploy.pub)" ~/.ssh/authorized_keys; then
  cat /tmp/sombateka_deploy.pub >> ~/.ssh/authorized_keys
fi
rm -f /tmp/sombateka_deploy.pub
echo Cle SSH installee.
'@
if ($LASTEXITCODE -ne 0) { throw "Echec ssh" }

Write-Host ""
Write-Host "Fichier SSH config ($SshAlias) ..." -ForegroundColor Yellow

$hostName = ($VpsHost -split '@')[-1]
$user = if ($VpsHost -match '^(.+)@') { $Matches[1] } else { 'root' }
$keyFile = ($KeyPath -replace '\\', '/')

$block = @"

Host $SshAlias
    HostName $hostName
    User $user
    IdentityFile $keyFile
    IdentitiesOnly yes

"@

if (-not (Test-Path $ConfigPath)) {
    Set-Content -Path $ConfigPath -Value $block.TrimStart() -Encoding utf8NoBOM
} elseif (-not (Select-String -Path $ConfigPath -Pattern "Host $SshAlias" -Quiet)) {
    Add-Content -Path $ConfigPath -Value $block -Encoding utf8NoBOM
}

Write-Host ""
Write-Host "Test sans mot de passe ..." -ForegroundColor Yellow
ssh -o BatchMode=yes $SshAlias "echo OK_sans_mot_de_passe"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Echec — reessayez le script." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Termine ===" -ForegroundColor Green
Write-Host "  Deploy : .\scripts\deploy-all.ps1"
Write-Host "  (utilise l'alias $SshAlias automatiquement)"
Write-Host ""
