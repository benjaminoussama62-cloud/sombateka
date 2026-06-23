#!/usr/bin/env bash
# Sauvegarde uploads + .env — NE JAMAIS deployer sans ça.
set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/SombaTeka}"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/sombateka-backups}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
DEST="$BACKUP_ROOT/$STAMP"

mkdir -p "$DEST"

if [[ -f "$REPO_DIR/backend/.env.production" ]]; then
  cp "$REPO_DIR/backend/.env.production" "$DEST/.env.production"
  cp "$REPO_DIR/backend/.env.production" "$HOME/env-backup.production"
fi

if [[ -d "$REPO_DIR/backend/uploads" ]]; then
  cp -a "$REPO_DIR/backend/uploads" "$DEST/uploads"
fi

# Anciennes images Docker (si bind mount vide mais image ancienne)
if command -v docker &>/dev/null; then
  img="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'backend-backend|backend_backend' | head -1 || true)"
  if [[ -n "$img" ]]; then
    docker run --rm -v "$DEST/docker-uploads":/out "$img" \
      sh -c 'if [ -d /app/uploads ] && [ "$(ls -A /app/uploads 2>/dev/null)" ]; then cp -a /app/uploads/. /out/; fi' 2>/dev/null || true
  fi
fi

echo "OK — Sauvegarde: $DEST"
du -sh "$DEST" 2>/dev/null || true
