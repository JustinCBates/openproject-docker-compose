#!/bin/bash

# configure_proxy.sh - Render proxy Caddyfile.template for the proxy build
# This script writes a clean Caddyfile.template to the proxy directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
# The central interactive_config.cfg lives two levels up from installation_utilities/proxy
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"

echo "=========================================="
echo "Proxy Configuration Utility"
echo "=========================================="

# Load config if present (not fatal)
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

# Compute values
APP_HOST=${APP_HOST:-web}
DOMAIN_NAME=${DOMAIN_NAME:-${OPENPROJECT_HOST_NAME:-}}
RELATIVE_ROOT=${OPENPROJECT_RAILS__RELATIVE__URL__ROOT:-}
# Read proxy redirect preference (default: empty -> leave Caddy default behavior)
PROXY_HTTP_TO_HTTPS_REDIRECT=${PROXY_HTTP_TO_HTTPS_REDIRECT:-}

# If RELATIVE_ROOT contains unresolved ${...} references, expand them
if [[ "$RELATIVE_ROOT" == *'${'* ]]; then
    eval "RELATIVE_ROOT=\"$RELATIVE_ROOT\""
fi

# Fallback to reading project .env if still empty
if [ -z "$RELATIVE_ROOT" ] && [ -f "$PROJECT_ROOT/.env" ]; then
    val=$(grep -E '^OPENPROJECT_RAILS__RELATIVE__URL__ROOT=' "$PROJECT_ROOT/.env" || true)
    if [ -n "$val" ]; then
    RELATIVE_ROOT=${val#*=}
    RELATIVE_ROOT=${RELATIVE_ROOT%\"}
    RELATIVE_ROOT=${RELATIVE_ROOT#\"}
    fi
fi

PROXY_DIR="$PROJECT_ROOT/proxy"
TEMPLATE_FILE="$PROXY_DIR/Caddyfile.template"

if [ ! -d "$PROXY_DIR" ]; then
    echo "⚠ Proxy directory not found at $PROXY_DIR - skipping proxy configure"
    exit 0
fi

echo "Rendering Caddyfile.template (domain=${DOMAIN_NAME:-<none>}, relative_root=${RELATIVE_ROOT:-<none>})"

# Determine site header
if [ -n "$DOMAIN_NAME" ]; then
    SITE_HEADER="$DOMAIN_NAME"
else
    SITE_HEADER=":80"
fi

if [ -n "$RELATIVE_ROOT" ] && [ "$RELATIVE_ROOT" != "/" ]; then
    # If the config explicitly disables HTTP->HTTPS redirects, prepend the global Caddy option
    if [ -n "$PROXY_HTTP_TO_HTTPS_REDIRECT" ] && [ "$PROXY_HTTP_TO_HTTPS_REDIRECT" = "false" ]; then
        cat > "$TEMPLATE_FILE" <<'CADDY_GLOBAL'
{
    auto_https disable_redirects
}
CADDY_GLOBAL
    fi

    cat >> "$TEMPLATE_FILE" <<EOF
${SITE_HEADER} {
    handle_path ${RELATIVE_ROOT} {
        reverse_proxy http://\${APP_HOST}:8080 {
            header_up X-Forwarded-Proto {http.request.scheme}
            header_up X-Forwarded-For {remote}
            header_up Host {http.request.host}
        }
    }

    file_server
    log
}
EOF
else
    # If the config explicitly disables HTTP->HTTPS redirects, prepend the global Caddy option
    if [ -n "$PROXY_HTTP_TO_HTTPS_REDIRECT" ] && [ "$PROXY_HTTP_TO_HTTPS_REDIRECT" = "false" ]; then
        cat > "$TEMPLATE_FILE" <<'CADDY_GLOBAL'
{
    auto_https disable_redirects
}
CADDY_GLOBAL
    fi

    cat >> "$TEMPLATE_FILE" <<EOF
${SITE_HEADER} {
    reverse_proxy * http://\${APP_HOST}:8080 {
        header_up X-Forwarded-Proto {header.X-Forwarded-Proto}
        header_up X-Forwarded-For {header.X-Forwarded-For}
        header_up Host {host}
    }

    file_server
    log
}
EOF
fi

echo "✓ Generated $TEMPLATE_FILE"

exit 0
