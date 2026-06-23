#!/usr/bin/env bash
# Mise a jour rapide sur VPS (sans certbot) — apres upload-and-deploy ou tar manuel
set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/SombaTeka}"
DOMAIN="${DOMAIN:-164-90-214-206.sslip.io}"

while [[ $# -gt 0 ]]; do
  arg="${1//$'\r'/}"
  case "$arg" in
    --domain) DOMAIN="${2//$'\r'/}"; shift 2 ;;
    --dir) REPO_DIR="${2//$'\r'/}"; shift 2 ;;
    *) echo "Option inconnue: $arg"; exit 1 ;;
  esac
done

REPO_DIR="${REPO_DIR//$'\r'/}"
DOMAIN="${DOMAIN//$'\r'/}"
DOMAIN="${DOMAIN%%[[:space:]]}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -x "$SCRIPT_DIR/backup-vps-data.sh" ]]; then
  echo "==> Sauvegarde uploads + .env avant deploy..."
  REPO_DIR="$REPO_DIR" bash "$SCRIPT_DIR/backup-vps-data.sh"
fi

cd "$REPO_DIR/backend"

if [[ ! -f .env.production ]]; then
  echo "ERREUR: $REPO_DIR/backend/.env.production manquant"
  exit 1
fi

DB_PASS=$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2- | tr -d '\r')
export DB_PASSWORD="$DB_PASS"

if grep -q '^PUBLIC_BASE_URL=' .env.production; then
  sed -i "s|PUBLIC_BASE_URL=.*|PUBLIC_BASE_URL=https://$DOMAIN|" .env.production
fi

COMPOSE_FILES="-f docker-compose.prod.yml"
if [[ -f docker-compose.beta.yml ]]; then
  COMPOSE_FILES="$COMPOSE_FILES -f docker-compose.beta.yml"
fi

echo "==> Build & redemarrage backend..."
docker compose $COMPOSE_FILES up -d --build backend nginx

echo "==> Migrations..."
docker compose $COMPOSE_FILES exec -T backend alembic upgrade head || true

echo "==> Compte super admin..."
docker compose $COMPOSE_FILES exec -T backend python scripts/ensure-admin.py || true

echo "==> Sante..."
for i in $(seq 1 20); do
  if curl -sf "http://localhost:8000/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

curl -sf "http://localhost:8000/healthz" && echo ""
curl -sf "http://localhost:8000/admin/ping" && echo "" || curl -sf "http://127.0.0.1:8000/admin/ping" && echo "" || true

echo ""
echo "OK — Admin: https://$DOMAIN/admin"
