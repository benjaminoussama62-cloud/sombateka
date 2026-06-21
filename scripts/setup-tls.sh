#!/usr/bin/env bash
# Obtention certificat Let's Encrypt pour sombateka.cd + api.sombateka.cd
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMAIL="${CERTBOT_EMAIL:-support@sombateka.cd}"
WEBROOT="${WEBROOT:-/var/www/certbot}"

sudo mkdir -p "$WEBROOT" "$ROOT/nginx/ssl"

echo "→ Certificat pour sombateka.cd, www.sombateka.cd, api.sombateka.cd"
sudo certbot certonly --webroot \
  -w "$WEBROOT" \
  -d sombateka.cd \
  -d www.sombateka.cd \
  -d api.sombateka.cd \
  --email "$EMAIL" \
  --agree-tos \
  --non-interactive

sudo cp "/etc/letsencrypt/live/sombateka.cd/fullchain.pem" "$ROOT/nginx/ssl/cert.pem"
sudo cp "/etc/letsencrypt/live/sombateka.cd/privkey.pem" "$ROOT/nginx/ssl/key.pem"
sudo chmod 644 "$ROOT/nginx/ssl/cert.pem"
sudo chmod 600 "$ROOT/nginx/ssl/key.pem"

echo "✅ Certificats copiés dans nginx/ssl/"
echo "   Relancez nginx : docker compose -f backend/docker-compose.prod.yml restart nginx"
