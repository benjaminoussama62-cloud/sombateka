#!/usr/bin/env bash
# Redemarrage rapide beta sur VPS 1 Go (sans celery)
set -euo pipefail
cd "$(dirname "$0")/../backend"
export DB_PASSWORD="$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)"
docker compose -f docker-compose.prod.yml -f docker-compose.beta.yml down 2>/dev/null || true
docker compose -f docker-compose.prod.yml -f docker-compose.beta.yml up -d --build
echo "Attente API..."
for i in $(seq 1 30); do
  if docker compose -f docker-compose.prod.yml exec -T backend curl -sf http://localhost:8000/healthz >/dev/null 2>&1; then
    echo "OK backend"
    docker compose -f docker-compose.prod.yml -f docker-compose.beta.yml up -d nginx
    exit 0
  fi
  sleep 5
done
echo "Voir logs: docker compose -f docker-compose.prod.yml logs backend --tail 80"
exit 1
