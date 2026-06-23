# Upload SombaTeka vers le VPS DigitalOcean + deploiement
# Usage (PowerShell) — vous saisirez le mot de passe SSH 2 fois (upload + deploy)
param(
    [string]$VpsIp = "164.90.214.206",
    [string]$User = "root",
    [string]$Domain = "164-90-214-206.sslip.io",
    [switch]$UploadOnly,
    [switch]$DeployOnly
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$Archive = Join-Path $env:TEMP "sombateka-deploy.tar.gz"
$SshOpts = @("-4", "-o", "ConnectTimeout=30", "-o", "ServerAliveInterval=15", "-o", "StrictHostKeyChecking=accept-new")

function Test-SshPort {
    param([string]$HostIp, [int]$Port = 22)
    try {
        $t = Test-NetConnection -ComputerName $HostIp -Port $Port -WarningAction SilentlyContinue
        return [bool]$t.TcpTestSucceeded
    } catch {
        return $false
    }
}

function Send-ArchiveToVps {
    param(
        [string]$LocalPath,
        [string]$HostIp,
        [string]$RemotePath
    )
    Write-Host "      Essai SCP (protocole legacy -O)..." -ForegroundColor DarkGray
    & scp @SshOpts -O $LocalPath "${User}@${HostIp}:$RemotePath"
    if ($LASTEXITCODE -eq 0) { return $true }

    Write-Host "      SCP echoue, essai SFTP..." -ForegroundColor DarkGray
    $sftpBatch = Join-Path $env:TEMP "sombateka-sftp.txt"
    @(
        "put `"$LocalPath`" $RemotePath"
        "quit"
    ) | Set-Content -Path $sftpBatch -Encoding ascii
    & sftp @SshOpts -b $sftpBatch "${User}@${HostIp}"
    Remove-Item $sftpBatch -Force -ErrorAction SilentlyContinue
    return ($LASTEXITCODE -eq 0)
}

function Write-SshTroubleshoot {
    param([string]$HostIp)
    Write-Host ""
    Write-Host "Depannage SSH (erreur Windows 'Unknown error' frequente) :" -ForegroundColor Yellow
    Write-Host "  1. Test manuel : ssh -4 -v ${User}@${HostIp}"
    Write-Host "  2. Evitez partage 4G instable — preferez Wi-Fi stable"
    Write-Host "  3. Desactivez VPN / antivirus qui bloque OpenSSH"
    Write-Host "  4. Console DigitalOcean : Droplet -> Access -> Launch Droplet Console"
    Write-Host "  5. Firewall DO : Networking -> Firewalls -> autoriser SSH (22) depuis votre IP"
    Write-Host "  6. Upload manuel WinSCP : fichier -> /root/sombateka-deploy.tar.gz puis -DeployOnly"
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  SombaTeka -> VPS $VpsIp" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Verifier .env.production
$EnvProd = Join-Path $Root "backend\.env.production"
if (-not (Test-Path $EnvProd)) {
    Write-Host "ERREUR: backend\.env.production manquant" -ForegroundColor Red
    Write-Host "Lancez: .\scripts\setup-beta-secrets.ps1 -ApplyBetaTemplate"
    exit 1
}

# Verifier secrets non-placeholder
$envContent = Get-Content $EnvProd -Raw
if ($envContent -match "VOTRE-IP|CHANGE_ME|GENERE_PAR") {
    Write-Host "ATTENTION: .env.production contient encore des placeholders" -ForegroundColor Yellow
}

Write-Host "[1/4] Creation archive (sans build/venv)..." -ForegroundColor Yellow
if ($DeployOnly) {
    Write-Host "      IGNORE (-DeployOnly, deja sur le VPS)" -ForegroundColor DarkGray
} else {
if (Test-Path $Archive) { Remove-Item $Archive -Force }

Push-Location $Root
try {
    # tar natif Windows 10+
    $excludes = @(
        "--exclude=mobile/build",
        "--exclude=mobile/.dart_tool",
        "--exclude=backend/.venv",
        "--exclude=backend/__pycache__",
        "--exclude=backend/.pytest_cache",
        "--exclude=backend/*.sqlite",
        "--exclude=.git",
        "--exclude=mobile/android/.gradle",
        "--exclude=backend/secrets-beta.local.txt"
    )
    & tar -czf $Archive @excludes .
    $sizeMb = [math]::Round((Get-Item $Archive).Length / 1MB, 1)
    Write-Host "      Archive: $Archive ($sizeMb Mo)" -ForegroundColor Green
}
finally {
    Pop-Location
}
}

Write-Host ""
if (-not $DeployOnly) {
Write-Host "[2/4] Test connexion SSH (port 22)..." -ForegroundColor Yellow
if (-not (Test-SshPort -HostIp $VpsIp)) {
    Write-Host "      Port 22 inaccessible depuis ce reseau." -ForegroundColor Red
    Write-SshTroubleshoot -HostIp $VpsIp
    exit 1
}
Write-Host "      Port 22 OK" -ForegroundColor Green

Write-Host "[2/4] Upload vers le serveur..." -ForegroundColor Yellow
Write-Host "      -> Saisissez le mot de passe root DigitalOcean quand demande" -ForegroundColor DarkGray
if (-not (Send-ArchiveToVps -LocalPath $Archive -HostIp $VpsIp -RemotePath "/root/sombateka-deploy.tar.gz")) {
    Write-Host "ERREUR upload (SCP + SFTP)." -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative console DO (code deja sur GitHub) :" -ForegroundColor Cyan
    Write-Host "  git clone https://USER:TOKEN@github.com/benjaminoussama62-cloud/sombateka.git /root/SombaTeka"
    Write-Host "  cp /root/env-backup.production /root/SombaTeka/backend/.env.production"
    Write-Host "  bash /root/SombaTeka/scripts/update-vps.sh --domain $Domain"
    Write-SshTroubleshoot -HostIp $VpsIp
    exit 1
}
Write-Host "      Upload OK" -ForegroundColor Green
}

if ($UploadOnly) {
    Write-Host "Upload seul termine (-UploadOnly)."
    exit 0
}

Write-Host ""
Write-Host "[3/4] Decompression + deploiement sur le VPS..." -ForegroundColor Yellow
Write-Host "      -> Mot de passe SSH a nouveau" -ForegroundColor DarkGray

$RemoteScript = @'
set -e
REPO=/root/SombaTeka
BACKUP=/root/sombateka-backups/pre-deploy-$(date -u +%Y%m%d-%H%M%S)
mkdir -p "$BACKUP"
if [ -f "$REPO/backend/.env.production" ]; then
  cp "$REPO/backend/.env.production" "$BACKUP/.env.production"
  cp "$REPO/backend/.env.production" /root/env-backup.production
fi
if [ -d "$REPO/backend/uploads" ] && [ "$(ls -A "$REPO/backend/uploads" 2>/dev/null)" ]; then
  cp -a "$REPO/backend/uploads" "$BACKUP/uploads"
fi
mkdir -p "$REPO"
cd "$REPO"
if [ -f /root/sombateka-deploy.tar.gz ]; then
  tar -xzf /root/sombateka-deploy.tar.gz
fi
if [ -d "$BACKUP/uploads" ]; then
  mkdir -p backend
  cp -a "$BACKUP/uploads" backend/uploads
fi
if [ -f /root/env-backup.production ]; then
  mkdir -p backend
  cp /root/env-backup.production backend/.env.production
fi
find scripts -name "*.sh" -exec sed -i 's/\r$//' {} \;
chmod +x scripts/update-vps.sh scripts/deploy-vps.sh scripts/backup-vps-data.sh 2>/dev/null || true
bash scripts/update-vps.sh --domain DOMAIN_PLACEHOLDER
'@
$RemoteScript = $RemoteScript -replace "DOMAIN_PLACEHOLDER", $Domain

$RemoteScript | & ssh @SshOpts "${User}@${VpsIp}" "bash -s"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERREUR deploiement. Connectez-vous manuellement:" -ForegroundColor Red
    Write-Host "  ssh -4 ${User}@$VpsIp"
    Write-Host "  cd /root/SombaTeka && bash scripts/update-vps.sh --domain $Domain"
    Write-SshTroubleshoot -HostIp $VpsIp
    exit 1
}

Write-Host ""
Write-Host "[4/4] Test API..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
try {
    $r = Invoke-WebRequest -Uri "https://$Domain/healthz" -UseBasicParsing -TimeoutSec 30
    Write-Host "      healthz: $($r.Content)" -ForegroundColor Green
}
catch {
    Write-Host "      healthz pas encore accessible (normal si certificat en cours)" -ForegroundColor Yellow
    Write-Host "      Test manuel: curl https://$Domain/healthz" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  DEPLOIEMENT TERMINE" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  API : https://$Domain/healthz"
Write-Host "  Admin: https://$Domain/admin"
Write-Host ""
Write-Host "  Build APK (sur ce PC):" -ForegroundColor Yellow
Write-Host "  cd mobile"
Write-Host "  .\scripts\build-apk-beta.ps1 -ApiUrl `"https://$Domain`""
