#!/usr/bin/env bash
# Déploiement production SombaTeka — une commande
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND="$ROOT/backend"

cd "$BACKEND"

if [[ ! -f .env.production ]]; then
  echo "❌ Copiez backend/.env.production.example vers backend/.env.production et remplissez les secrets."
  exit 1
fi

if [[ -z "${DB_PASSWORD:-}" ]]; then
  if grep -q '^DB_PASSWORD=' .env.production 2>/dev/null; then
    export DB_PASSWORD="$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)"
  fi
fi

if [[ -z "${DB_PASSWORD:-}" || "${DB_PASSWORD}" == *"CHANGE_ME"* ]]; then
  echo "❌ Définissez DB_PASSWORD (export DB_PASSWORD=... ou dans .env.production)"
  exit 1
fi

if [[ ! -f "$ROOT/nginx/ssl/cert.pem" || ! -f "$ROOT/nginx/ssl/key.pem" ]]; then
  echo "⚠️  Certificats TLS manquants — voir nginx/ssl/README.md"
  echo "    Pour un test local : openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout nginx/ssl/key.pem -out nginx/ssl/cert.pem -subj /CN=localhost"
fi

echo "→ Build & démarrage stack production..."
docker compose -f docker-compose.prod.yml up -d --build

echo "→ Attente santé API..."
for i in $(seq 1 30); do
  if docker compose -f docker-compose.prod.yml exec -T backend curl -sf http://localhost:8000/healthz >/dev/null 2>&1; then
    echo "✅ Backend OK"
    break
  fi
  sleep 2
  if [[ $i -eq 30 ]]; then
    echo "❌ Backend n'a pas répondu — vérifiez : docker compose -f docker-compose.prod.yml logs backend"
    exit 1
  fi
done

echo ""
echo "✅ SombaTeka production déployée"
echo "   API  : https://api.sombateka.cd/healthz"
echo "   Site : https://sombateka.cd"
echo "   Admin: https://api.sombateka.cd/admin"
