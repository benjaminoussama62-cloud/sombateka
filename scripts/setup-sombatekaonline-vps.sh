#!/usr/bin/env bash
# SombaTeka — TLS + nginx + backend pour sombatekaonline.com (sur le VPS)
# Usage : sudo bash ~/SombaTeka/scripts/setup-sombatekaonline-vps.sh
set -euo pipefail

DOMAIN="sombatekaonline.com"
WWW="www.sombatekaonline.com"
REPO_DIR="${REPO_DIR:-$HOME/SombaTeka}"
EMAIL="${CERTBOT_EMAIL:-benjaminoussama62@gmail.com}"
SSL_DIR="$REPO_DIR/nginx/ssl"

echo "==> Setup domaine $DOMAIN sur VPS $(hostname -I | awk '{print $1}')"

if ! dig +short "$DOMAIN" A | grep -q .; then
  echo "ERREUR: DNS $DOMAIN ne pointe pas encore vers ce serveur."
  echo "Cloudflare → DNS → A @ → IP du VPS (nuage GRIS = DNS only pour Let's Encrypt)"
  exit 1
fi

cd "$REPO_DIR"

if [[ ! -f backend/.env.production ]]; then
  echo "ERREUR: backend/.env.production manquant"; exit 1
fi

# Backend URL + CORS
sed -i "s|PUBLIC_BASE_URL=.*|PUBLIC_BASE_URL=https://$DOMAIN|" backend/.env.production
if grep -q '^CORS_ORIGINS=' backend/.env.production; then
  sed -i "s|CORS_ORIGINS=.*|CORS_ORIGINS=https://$DOMAIN,https://$WWW|" backend/.env.production
else
  echo "CORS_ORIGINS=https://$DOMAIN,https://$WWW" >> backend/.env.production
fi

mkdir -p "$SSL_DIR" /var/www/certbot

if ! command -v certbot &>/dev/null; then
  apt-get update -qq && apt-get install -y certbot
fi

echo "==> Arret nginx pour certbot..."
cd backend
export DB_PASSWORD="$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)"
docker compose -f docker-compose.prod.yml stop nginx 2>/dev/null || true

echo "==> Certificat Let's Encrypt..."
certbot certonly --standalone \
  -d "$DOMAIN" -d "$WWW" \
  --non-interactive --agree-tos -m "$EMAIL" \
  --preferred-challenges http

cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/cert.pem"
cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/key.pem"
chmod 644 "$SSL_DIR/cert.pem"
chmod 600 "$SSL_DIR/key.pem"

# Nginx unifie (app + API)
mv "$REPO_DIR/nginx/conf.d/10-api.conf" "$REPO_DIR/nginx/conf.d/10-api.conf.bak" 2>/dev/null || true
mv "$REPO_DIR/nginx/conf.d/20-web.conf" "$REPO_DIR/nginx/conf.d/20-web.conf.bak" 2>/dev/null || true

echo "==> Redemarrage stack..."
docker compose -f docker-compose.prod.yml up -d --force-recreate nginx
docker compose -f docker-compose.prod.yml up -d --build backend

echo "==> Attente sante..."
for i in $(seq 1 30); do
  if curl -sf "https://$DOMAIN/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo ""
echo "=========================================="
echo "  OK — $DOMAIN configure"
echo "=========================================="
curl -sk "https://$DOMAIN/healthz" || true
echo ""
echo "  App   : https://$DOMAIN/"
echo "  Admin : https://$DOMAIN/admin/login"
echo ""
