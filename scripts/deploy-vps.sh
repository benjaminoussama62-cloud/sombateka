#!/usr/bin/env bash
# SombaTeka — Installation complete sur VPS Ubuntu/Debian
# Usage (sur le VPS) :
#   curl -fsSL https://raw.githubusercontent.com/VOTRE-REPO/main/scripts/deploy-vps.sh | bash
#   OU apres git clone :
#   sudo bash scripts/deploy-vps.sh --domain 123-45-67-89.sslip.io
set -euo pipefail

DOMAIN=""
REPO_DIR="${REPO_DIR:-$HOME/SombaTeka}"
SKIP_CLONE=false

SKIP_TLS=false

while [[ $# -gt 0 ]]; do
  arg="${1//$'\r'/}"
  case "$arg" in
    --domain) DOMAIN="${2//$'\r'/}"; shift 2 ;;
    --dir) REPO_DIR="${2//$'\r'/}"; shift 2 ;;
    --skip-clone) SKIP_CLONE=true; shift ;;
    --skip-tls) SKIP_TLS=true; shift ;;
    *) echo "Option inconnue: $arg"; exit 1 ;;
  esac
done

# Windows upload peut ajouter \r dans --domain
DOMAIN="${DOMAIN//$'\r'/}"
DOMAIN="${DOMAIN%%[[:space:]]}"
REPO_DIR="${REPO_DIR//$'\r'/}"
SKIP_TLS="${SKIP_TLS:-false}"

if [[ -z "$DOMAIN" ]]; then
  echo "Usage: sudo bash deploy-vps.sh --domain VOTRE-DOMAINE"
  echo ""
  echo "Exemples :"
  echo "  --domain 123-45-67-89.sslip.io     (gratuit, sans acheter de domaine)"
  echo "  --domain api.sombateka.cd          (si vous avez le domaine)"
  exit 1
fi

echo "==> SombaTeka deploy — domaine: $DOMAIN"

# --- Docker ---
if ! command -v docker &>/dev/null; then
  echo "==> Installation Docker..."
  apt-get update -qq
  apt-get install -y ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  systemctl enable docker
  systemctl start docker
fi

# --- Certbot ---
if ! command -v certbot &>/dev/null; then
  apt-get install -y certbot
fi

# --- Repo ---
if [[ "$SKIP_CLONE" == false && ! -d "$REPO_DIR/.git" ]]; then
  echo "==> Clone manuel requis — uploadez le projet dans $REPO_DIR"
  echo "    scp -r SombaTeka/ root@VPS_IP:$REPO_DIR"
  mkdir -p "$REPO_DIR"
fi

cd "$REPO_DIR"

# --- Secrets ---
if [[ ! -f backend/.env.production ]]; then
  if [[ -f backend/.env.beta.example ]]; then
    cp backend/.env.beta.example backend/.env.production
    echo "==> Copie .env.beta.example -> .env.production"
    echo "    EDITEZ backend/.env.production avant de continuer !"
    echo "    nano backend/.env.production"
    exit 1
  fi
  echo "ERREUR: backend/.env.production manquant"; exit 1
fi

# Mettre a jour PUBLIC_BASE_URL
sed -i "s|PUBLIC_BASE_URL=.*|PUBLIC_BASE_URL=https://$DOMAIN|" backend/.env.production

# Sync DB password in DATABASE_URL
DB_PASS=$(grep '^DB_PASSWORD=' backend/.env.production | cut -d= -f2-)
if [[ -n "$DB_PASS" && "$DB_PASS" != *CHANGE* && "$DB_PASS" != *GENERE* ]]; then
  sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql+psycopg://sombateka:${DB_PASS}@db:5432/sombateka_prod|" backend/.env.production
fi

export DB_PASSWORD="$DB_PASS"

# --- TLS Let's Encrypt ---
SSL_DIR="$REPO_DIR/nginx/ssl"
mkdir -p "$SSL_DIR" /var/www/certbot

if [[ "$SKIP_TLS" == true ]] && [[ -f "$SSL_DIR/cert.pem" && -f "$SSL_DIR/key.pem" ]]; then
  echo "==> TLS existant conserve (--skip-tls)"
elif [[ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
  echo "==> Certificat Let's Encrypt deja present pour $DOMAIN"
  cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/cert.pem"
  cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/key.pem"
  chmod 644 "$SSL_DIR/cert.pem"
  chmod 600 "$SSL_DIR/key.pem"
else
  echo "==> Arret nginx temporaire pour certbot..."
  docker compose -f backend/docker-compose.prod.yml stop nginx 2>/dev/null || true

  echo "==> Certificat TLS pour $DOMAIN..."
  certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN" || {
    echo "ERREUR certbot. Verifiez que le port 80 est ouvert et le DNS pointe vers ce serveur."
    exit 1
  }

  cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/cert.pem"
  cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/key.pem"
  chmod 644 "$SSL_DIR/cert.pem"
  chmod 600 "$SSL_DIR/key.pem"
fi

# --- Nginx server_name pour beta (sslip ou domaine custom) ---
NGINX_API="$REPO_DIR/nginx/conf.d/10-api.conf"
if [[ -f "$NGINX_API" ]]; then
  sed -i "s/server_name api.sombateka.cd;/server_name $DOMAIN;/" "$NGINX_API"
fi
NGINX_WEB="$REPO_DIR/nginx/conf.d/20-web.conf"
if [[ -f "$NGINX_WEB" && "$DOMAIN" != *"api."* ]]; then
  sed -i "s/server_name sombateka.cd www.sombateka.cd;/server_name $DOMAIN;/" "$NGINX_WEB" 2>/dev/null || true
fi

# --- Demarrage ---
echo "==> Build & demarrage stack (mode beta leger pour VPS 1 Go)..."
cd backend
export DB_PASSWORD
COMPOSE_FILES="-f docker-compose.prod.yml -f docker-compose.beta.yml"
if [[ -f docker-compose.beta.yml ]]; then
  docker compose $COMPOSE_FILES down 2>/dev/null || true
  docker compose $COMPOSE_FILES up -d --build
else
  docker compose -f docker-compose.prod.yml up -d --build
fi

echo "==> Attente sante API..."
for i in $(seq 1 40); do
  if curl -sf "http://localhost:8000/healthz" >/dev/null 2>&1; then
    break
  fi
  sleep 3
done

echo ""
echo "=========================================="
echo "  SombaTeka BETA deploye !"
echo "=========================================="
echo "  API : https://$DOMAIN/healthz"
echo "  Docs: https://$DOMAIN/docs"
echo "  Admin: https://$DOMAIN/admin"
echo ""
echo "  Build APK (sur votre PC Windows) :"
echo "  cd mobile"
echo "  .\\scripts\\build-apk-beta.ps1 -ApiUrl https://$DOMAIN"
echo ""
