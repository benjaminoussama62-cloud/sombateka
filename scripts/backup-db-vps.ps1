# Sauvegarde PostgreSQL sur le VPS (lancer localement ou via cron sur le VPS)
param(
    [string]$VpsHost = "sombateka-vps",
    [string]$RemoteBackupDir = "~/SombaTeka/backups",
    [int]$KeepDays = 14
)

$ErrorActionPreference = "Stop"
$ts = Get-Date -Format "yyyyMMdd-HHmmss"

Write-Host ""
Write-Host "=== Backup DB SombaTeka ===" -ForegroundColor Cyan
Write-Host ""

$remoteCmd = @"
set -e
mkdir -p $RemoteBackupDir
FILE=$RemoteBackupDir/sombateka_prod-$ts.sql.gz
docker exec sombateka-db-prod pg_dump -U sombateka -d sombateka_prod | gzip > "`$FILE"
ls -lh "`$FILE"
find $RemoteBackupDir -name 'sombateka_prod-*.sql.gz' -mtime +$KeepDays -delete 2>/dev/null || true
echo "Backup OK: `$FILE"
"@

ssh $VpsHost $remoteCmd

Write-Host ""
Write-Host "OK - sauvegarde sur le VPS dans $RemoteBackupDir" -ForegroundColor Green
Write-Host "Conseil : planifier avec scripts/install-vps-backup-cron.sh sur le VPS" -ForegroundColor Yellow
Write-Host ""
