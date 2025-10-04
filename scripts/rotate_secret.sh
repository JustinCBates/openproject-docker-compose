#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")" || exit 1

log() { printf "[rotate] %s\n" "$*"; }

# Safety: require docker-compose present
if ! command -v docker >/dev/null 2>&1; then
  log "docker not found in PATH"
  exit 1
fi

# Backups
BACKUP_PREFIX=".env.rotate"
STAMP=$(date +%s)
BACKUP1="${BACKUP_PREFIX}.bak"
BACKUP2="${BACKUP_PREFIX}.pre"
cp -a .env "${BACKUP1}"
cp -a .env "${BACKUP2}"
log "backed up .env -> ${BACKUP1}, ${BACKUP2}"

# Generate secret
NEW_SECRET=$(openssl rand -hex 64)
log "generated new SECRET_KEY_BASE (redacted)"

# Write secret into .env safely
if grep -q '^SECRET_KEY_BASE=' .env; then
  # replace in-place
  awk -v s="SECRET_KEY_BASE=${NEW_SECRET}" 'BEGIN{OFS=FS=""} { if ($0 ~ /^SECRET_KEY_BASE=/) { print s } else { print $0 } }' .env > .env.tmp && mv .env.tmp .env
else
  printf "\nSECRET_KEY_BASE=%s\n" "${NEW_SECRET}" >> .env
fi
log "wrote SECRET_KEY_BASE to .env (redacted)"

# Helper: recreate a service with timeout and exit-on-failure flag
recreate_service() {
  local svc=$1
  local t=$2
  log "recreating ${svc} (timeout ${t}s)"
  if timeout "${t}s" docker compose up -d --no-deps --force-recreate "${svc}"; then
    log "docker compose up -d returned for ${svc}"
  else
    log "warning: compose up for ${svc} timed out or failed"
  fi
}

# Recreate web and wait for healthy
recreate_service web 90
# Poll for healthy status up to 60s
log "polling for web healthy (up to 60s, 5s interval)"
for i in {1..12}; do
  # Show the compose ps line for web
  docker compose ps web || true
  # Check textual healthy marker
  if docker compose ps | grep -q openproject-web-1 && docker compose ps | grep -q '(healthy)'; then
    log "web is healthy"
    break
  fi
  sleep 5
done

# Recreate worker and cron
recreate_service worker 30
recreate_service cron 15

# Verify secret present inside web without printing it
log "verifying SECRET_KEY_BASE inside web environment"
if docker compose exec -T web bash -lc '[ -n "$SECRET_KEY_BASE" ] && echo secret_present || echo secret_missing' | grep -q secret_present; then
  log "SECRET_KEY_BASE present in web"
else
  log "SECRET_KEY_BASE missing in web"
fi

# Probe public endpoint
log "probing public endpoint"
curl -I --max-time 10 http://srv1035368.hstgr.cloud/StatesmenProjects || true

log "rotation script complete"
