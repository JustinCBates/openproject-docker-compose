#!/usr/bin/env bash
set -euo pipefail

# Simple smoke test for Caddyfile template rendering.
# This script sets test env variables, renders the template using gomplate,
# and validates it with `caddy adapt` inside the running proxy container.

export OPENPROJECT_HOST_NAME=${OPENPROJECT_HOST_NAME:-example.test}
export RAILS_RELATIVE_URL_ROOT=${RAILS_RELATIVE_URL_ROOT:-/StatesmenProjects}
export PROXY_HTTP_PORT=${PROXY_HTTP_PORT:-80}
export PROXY_HTTPS_PORT=${PROXY_HTTPS_PORT:-443}
export PROXY_TLS_MODE=${PROXY_TLS_MODE:-internal}
export APP_HOST=${APP_HOST:-web}

# Ensure gomplate present; if not, download a single-use binary into /tmp
if ! command -v gomplate >/dev/null 2>&1; then
  echo "gomplate not found; downloading temporary binary..."
  GOMPLATE_URL="https://github.com/hairyhenderson/gomplate/releases/latest/download/gomplate_linux_amd64"
  curl -fsSL "$GOMPLATE_URL" -o /tmp/gomplate && chmod +x /tmp/gomplate
  export PATH="/tmp:$PATH"
fi

if [ ! -x ./scripts/deploy/render_caddy.sh ]; then
  echo "render_caddy.sh not found or not executable" >&2
  exit 2
fi

# Run renderer in dry-run mode to validate template only
./scripts/deploy/render_caddy.sh --dry-run --verbose

echo "Smoke render passed."