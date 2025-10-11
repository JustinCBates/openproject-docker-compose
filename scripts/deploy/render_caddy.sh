#!/usr/bin/env bash
set -euo pipefail

# Render proxy/Caddyfile.template using gomplate and deploy into the running proxy container.
# Requirements: gomplate binary available on host, docker compose running with service name 'proxy'.

TEMPLATE="proxy/Caddyfile.template"
OUT_TMP="/tmp/Caddyfile.$$.tmp"
CONTAINER_PATH="/etc/caddy/Caddyfile"

# Load .env if present (export vars)
if [ -f .env ]; then
  # shellcheck disable=SC1090
  set -a; . .env; set +a
fi

# Bridge common naming variants: prefer OPENPROJECT_HOST_NAME but fall back to OPENPROJECT_HOST__NAME
if [ -z "${OPENPROJECT_HOST_NAME:-}" ] && [ -n "${OPENPROJECT_HOST__NAME:-}" ]; then
  export OPENPROJECT_HOST_NAME="$OPENPROJECT_HOST__NAME"
  echo "WARN: setting OPENPROJECT_HOST_NAME from OPENPROJECT_HOST__NAME"
fi

echo "Using OPENPROJECT_HOST_NAME=${OPENPROJECT_HOST_NAME:-<unset>} RAILS_RELATIVE_URL_ROOT=${RAILS_RELATIVE_URL_ROOT:-<unset>}"

# Render using gomplate. If gomplate is not found, instruct how to install.
if ! command -v gomplate >/dev/null 2>&1; then
  echo "gomplate not found. Install it (https://github.com/hairyhenderson/gomplate) or use the deploy toolchain that bundles it." >&2
  exit 2
fi

echo "Rendering $TEMPLATE -> $OUT_TMP"
gomplate -f "$TEMPLATE" -o "$OUT_TMP"

# Validate using caddy adapt inside the proxy container by piping the rendered config to stdin
if ! docker compose exec -T proxy caddy adapt --config - < "$OUT_TMP" >/dev/null 2>&1; then
  echo "Caddy configuration validation failed." >&2
  # show detailed error output for debugging
  docker compose exec -T proxy caddy adapt --config - < "$OUT_TMP" || true
  rm -f "$OUT_TMP"
  exit 1
fi

# Atomically copy into the container and reload
docker compose exec -T proxy sh -c 'cat > /etc/caddy/Caddyfile' < "$OUT_TMP"
docker compose exec -T proxy caddy reload --config /etc/caddy/Caddyfile

rm -f "$OUT_TMP"

echo "Caddyfile rendered, validated, deployed and reloaded."
