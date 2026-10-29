#!/usr/bin/env bash
# À exécuter UNE FOIS sur le VPS (ssh …)
# Planifie sauvegarde PostgreSQL quotidienne + ping uptime optionnel
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/SombaTeka/backups}"
HC_URL_FILE="${HC_URL_FILE:-$HOME/SombaTeka/backend/.healthchecks_backup_url}"
mkdir -p "$BACKUP_DIR"

BACKUP_SCRIPT="$HOME/SombaTeka/scripts/run-db-backup.sh"
mkdir -p "$(dirname "$BACKUP_SCRIPT")"

cat > "$BACKUP_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="${BACKUP_DIR:-$HOME/SombaTeka/backups}"
HC_URL_FILE="${HC_URL_FILE:-$HOME/SombaTeka/backend/.healthchecks_backup_url}"
mkdir -p "$BACKUP_DIR"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/sombateka_prod-$STAMP.sql.gz"

docker exec sombateka-db-prod pg_dump -U sombateka -d sombateka_prod | gzip > "$OUT"
find "$BACKUP_DIR" -name 'sombateka_prod-*.sql.gz' -mtime +14 -delete

# Optional offsite copy if rclone remote "sombateka-offsite" is configured
if command -v rclone >/dev/null 2>&1 && rclone listremotes 2>/dev/null | grep -q '^sombateka-offsite:'; then
  rclone copy "$OUT" sombateka-offsite:sombateka-backups/ --quiet || true
fi

if [[ -f "$HC_URL_FILE" ]]; then
  url="$(tr -d '[:space:]' < "$HC_URL_FILE")"
  if [[ -n "$url" ]]; then
    curl -fsS -m 10 "$url" >/dev/null || true
  fi
fi
echo "OK $OUT"
EOF
chmod +x "$BACKUP_SCRIPT"

CRON_LINE="30 3 * * * $BACKUP_SCRIPT >> $BACKUP_DIR/backup.log 2>&1"

if crontab -l 2>/dev/null | grep -q 'run-db-backup.sh\|sombateka_prod-'; then
  echo "Cron backup déjà présent."
else
  (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab -
  echo "Cron backup ajouté (3h30 UTC daily)."
fi

crontab -l | grep -E 'sombateka|run-db-backup' || true
echo ""
echo "Offsite (optionnel): rclone config → remote 'sombateka-offsite'"
echo "Uptime backup: echo 'https://hc-ping.com/UUID' > $HC_URL_FILE"
echo "Test manuel: $BACKUP_SCRIPT"
