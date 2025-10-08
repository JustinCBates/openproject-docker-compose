#!/bin/bash

# configure_proxy.sh - Render proxy configuration (Caddyfile) from templates
# This script is intentionally minimal: it only renders templates in the ./proxy
# build context so the image build can include the final Caddyfile.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../interactive_config.cfg"

echo "=========================================="
echo "Proxy Configuration Utility"
echo "=========================================="

# Load config if present (not fatal)
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

# Determine APP_HOST to substitute into Caddyfile template
# Default app host is 'web' (compose service name)
APP_HOST=${APP_HOST:-web}
if [ -n "${OPENPROJECT_HOST_NAME}" ]; then
    # Prefer configured host for proxy where appropriate
    APP_HOST=${APP_HOST}
fi

PROXY_DIR="$PROJECT_ROOT/proxy"

if [ ! -d "$PROXY_DIR" ]; then
    echo "⚠ Proxy directory not found at $PROXY_DIR - skipping proxy configure"
    exit 0
fi

TEMPLATE_FILE="$PROXY_DIR/Caddyfile.template"
OUT_FILE="$PROXY_DIR/Caddyfile"

if [ -f "$TEMPLATE_FILE" ]; then
    echo "Rendering Caddyfile from template"
    # Replace ${APP_HOST} placeholder with actual app host value
    sed "s|\\${APP_HOST}|$APP_HOST|g" "$TEMPLATE_FILE" > "$OUT_FILE"
    echo "✓ Generated $OUT_FILE"
else
    echo "⚠ No Caddyfile.template found in proxy dir; skipping render"
fi

echo "Proxy configuration complete"

exit 0
