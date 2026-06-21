#!/usr/bin/env bash
# Sauvegarde PostgreSQL production
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups/postgres}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
CONTAINER="${PG_CONTAINER:-sombateka-db-prod}"
DB_USER="${PG_USER:-sombateka}"
DB_NAME="${PG_DB:-sombateka_prod}"

mkdir -p "$BACKUP_DIR"
OUT="$BACKUP_DIR/sombateka_${TIMESTAMP}.sql.gz"

echo "→ Dump $DB_NAME depuis $CONTAINER..."
docker exec "$CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" | gzip > "$OUT"

echo "✅ Sauvegarde : $OUT ($(du -h "$OUT" | cut -f1))"

# Garder les 14 dernières sauvegardes
ls -t "$BACKUP_DIR"/sombateka_*.sql.gz 2>/dev/null | tail -n +15 | xargs -r rm --
