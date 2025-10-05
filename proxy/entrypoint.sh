#!/usr/bin/env bash
set -euo pipefail

# Runtime templating for Caddyfile
APP_HOST="${APP_HOST:-web}"

if [ -f /etc/caddy/Caddyfile.template ]; then
  sed "s|${APP_HOST}|${APP_HOST}|g" /etc/caddy/Caddyfile.template > /etc/caddy/Caddyfile
fi

# Append optional local overrides
if [ -f /etc/caddy/Caddyfile.local ]; then
  cat /etc/caddy/Caddyfile.local >> /etc/caddy/Caddyfile
fi

exec "${@:-caddy run --config /etc/caddy/Caddyfile}"
