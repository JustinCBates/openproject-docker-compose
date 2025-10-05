#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env.host ]; then
  echo ".env.host not found. Please create it from .env.example and populate secrets." >&2
  exit 1
fi

cp .env.host .env

# Ensure data dirs exist
mkdir -p "${OPDATA:-/var/openproject/assets}" "${PGDATA:-/var/lib/postgresql/data}"
chown -R 1000:1000 "${OPDATA:-/var/openproject/assets}" || true

docker compose -f docker-compose.yml -f docker-compose.host.example.yml pull --ignore-pull-failures || true
docker compose -f docker-compose.yml -f docker-compose.host.example.yml up -d --build

echo "Waiting for web to become healthy..."
for i in $(seq 1 40); do
  if docker compose exec -T web curl -fsS "http://localhost:8080${OPENPROJECT_RAILS__RELATIVE__URL__ROOT:-/}/health_checks/default" >/dev/null 2>&1; then
    echo "web healthy"
    exit 0
  fi
  sleep 3
done

echo "Timed out waiting for health" >&2
docker compose logs --tail=200 web
exit 2
