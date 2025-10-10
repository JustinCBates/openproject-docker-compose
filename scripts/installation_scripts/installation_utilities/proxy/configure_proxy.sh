#!/bin/bash

# configure_proxy.sh - Render proxy Caddyfile.template for the proxy build
# This script writes a clean Caddyfile.template to the proxy directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
# Source UI helpers if available
if [ -f "$SCRIPT_DIR/../../common/common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../../common/common_ui.sh"
fi
# The central interactive_config.cfg lives two levels up from installation_utilities/proxy
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"

echo "=========================================="
echo "Proxy Configuration Utility"
echo "=========================================="

# Load defaults first to provide fallbacks
DEFAULTS_FILE="$SCRIPT_DIR/../../interactive_config.cfg.defaults"
if [ -f "$DEFAULTS_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$DEFAULTS_FILE"
    set +a
fi

# Load config if present (not fatal)
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

# Compute values
# Compute values (use safe expansions)
APP_HOST=${APP_HOST:-web}
DOMAIN_NAME=${DOMAIN_NAME:-${OPENPROJECT_HOST_NAME:-}}
RELATIVE_ROOT=${RAILS_URL_ROOT:-}
PROXY_BIND_ADDRESS=${PROXY_BIND_ADDRESS:-0.0.0.0}
PROXY_HTTP_PORT=${PROXY_HTTP_PORT:-80}
PROXY_HTTPS_PORT=${PROXY_HTTPS_PORT:-443}
PROXY_TLS_MODE=${PROXY_TLS_MODE:-internal}
# Read proxy redirect preference (default: empty -> leave Caddy default behavior)
# Support new key PROXY_HTTPS_REDIRECT; fall back to older PROXY_HTTP_TO_HTTPS_REDIRECT if present
PROXY_HTTPS_REDIRECT=${PROXY_HTTPS_REDIRECT:-${PROXY_HTTP_TO_HTTPS_REDIRECT:-}}

# If RELATIVE_ROOT contains unresolved ${...} references, expand them
if [[ "$RELATIVE_ROOT" == *'${'* ]]; then
    eval "RELATIVE_ROOT=\"$RELATIVE_ROOT\""
fi

# Fallback to reading project .env if still empty
if [ -z "$RELATIVE_ROOT" ] && [ -f "$PROJECT_ROOT/.env" ]; then
    val=$(grep -E '^RAILS_URL_ROOT=' "$PROJECT_ROOT/.env" || true)
    if [ -n "$val" ]; then

# Truncate the template file so multiple runs don't append duplicate site blocks
if [ -f "$TEMPLATE_FILE" ]; then
    : > "$TEMPLATE_FILE"
fi
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
    # Compose address lists: explicit bind:port plus domain host match on the same site header line
    # Use generic bind addresses (:80/:443) plus hostname to avoid duplicate/ambiguous
    # site definitions when Caddy performs automatic TLS resolution.
    # Place the hostname only on the HTTPS site block to avoid ambiguous
    # site definitions when Caddy performs automatic TLS resolution.
    SITE_HEADER_HTTP=":$PROXY_HTTP_PORT"
    SITE_HEADER_HTTPS=":$PROXY_HTTPS_PORT $DOMAIN_NAME"
else
    SITE_HEADER_HTTP=":$PROXY_HTTP_PORT"
    SITE_HEADER_HTTPS=":$PROXY_HTTPS_PORT"
fi

if [ -n "$RELATIVE_ROOT" ] && [ "$RELATIVE_ROOT" != "/" ]; then
    # If the config explicitly disables HTTP->HTTPS redirects, prepend the global Caddy option
    if [ -n "$PROXY_HTTPS_REDIRECT" ] && [ "$PROXY_HTTPS_REDIRECT" = "false" ]; then
        cat > "$TEMPLATE_FILE" <<'CADDY_GLOBAL'
{
    auto_https disable_redirects
}
CADDY_GLOBAL
    fi
    # Choose TLS behavior based on PROXY_TLS_MODE
    case "$PROXY_TLS_MODE" in
        internal)
            TLS_BLOCK="tls internal"
            ;;
        letsencrypt_staging)
            # multiline TLS block so the Caddyfile places the '{' on its own line
            TLS_BLOCK=$'tls {\n    ca https://acme-staging-v02.api.letsencrypt.org/directory\n}'
            ;;
        letsencrypt_prod)
            TLS_BLOCK="" # default Caddy behavior
            ;;
        acme_duckdns)
            # Instruct users to run acme.sh to install certs; template will expect certs at /etc/caddy/certs
            TLS_BLOCK="tls /etc/caddy/certs/${DOMAIN_NAME}.fullchain.pem /etc/caddy/certs/${DOMAIN_NAME}.key"
            ;;
        *) TLS_BLOCK="tls internal" ;;
    esac

    # Use resolved upstream dial address (no scheme) to avoid placeholders-in-scheme errors
    UPSTREAM="${APP_HOST}:8080"

    cat > "$TEMPLATE_FILE" <<EOF
${SITE_HEADER_HTTP} {
    # Redirect all HTTP to HTTPS (Caddy will handle redirect target)
    redir https://{host}{uri} 308
}

${SITE_HEADER_HTTPS} {
    ${TLS_BLOCK}

    handle_path ${RELATIVE_ROOT} {
        reverse_proxy ${UPSTREAM} {
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
    if [ -n "$PROXY_HTTPS_REDIRECT" ] && [ "$PROXY_HTTPS_REDIRECT" = "false" ]; then
        cat > "$TEMPLATE_FILE" <<'CADDY_GLOBAL'
{
    auto_https disable_redirects
}
CADDY_GLOBAL
    fi

    # Non-relative-root (root site) rendering: choose TLS block similarly
    case "$PROXY_TLS_MODE" in
        internal)
            TLS_BLOCK="tls internal"
            ;;
        letsencrypt_staging)
            # multiline TLS block so the Caddyfile places the '{' on its own line
            TLS_BLOCK=$'tls {\n    ca https://acme-staging-v02.api.letsencrypt.org/directory\n}'
            ;;
        letsencrypt_prod)
            TLS_BLOCK=""
            ;;
        acme_duckdns)
            TLS_BLOCK="tls /etc/caddy/certs/${DOMAIN_NAME}.fullchain.pem /etc/caddy/certs/${DOMAIN_NAME}.key"
            ;;
        *) TLS_BLOCK="tls internal" ;;
    esac

    UPSTREAM="${APP_HOST}:8080"

    cat > "$TEMPLATE_FILE" <<EOF
${SITE_HEADER_HTTP} {
    # Redirect all HTTP to HTTPS
    redir https://{host}{uri} 308
}

${SITE_HEADER_HTTPS} {
    ${TLS_BLOCK}

    reverse_proxy * ${UPSTREAM} {
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
