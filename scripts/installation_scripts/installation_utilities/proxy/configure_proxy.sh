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
# Source shared config renderer for validation helpers
if [ -f "$SCRIPT_DIR/../../common/config_render.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../../common/config_render.sh"
fi
# The central interactive_config.cfg lives two levels up from installation_utilities/proxy
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"

echo "=========================================="
echo "Proxy Configuration Utility"
echo "=========================================="

# Helper: read from a real terminal if available so prompts work when stdin/stdout are redirected
tty_read() {
    local prompt_text=${1:-}
    if [ -c /dev/tty ]; then
        read -r -p "$prompt_text" < /dev/tty || true
    else
        read -r -p "$prompt_text" || true
    fi
}

# Support an integration test mode to run an isolated proxy+hello backend and validate
# the active Caddy template end-to-end without leaving artifacts.
if [ "${1:-}" = "--integration-test" ]; then
    HELPER_SCRIPT="$PROJECT_ROOT/proxy/test/run_integration_test.sh"
    if [ ! -x "$HELPER_SCRIPT" ]; then
        echo "❌ Integration helper not found or not executable: $HELPER_SCRIPT"
        exit 2
    fi

    echo "Running integration test (isolated project)..."
    # Start isolated project in NO_TLS mode so we can test HTTP quickly
    INTEGRATION_NO_TLS=1 "$HELPER_SCRIPT" up

    # read state to find host port
    STATE_FILE="$PROJECT_ROOT/proxy/test/integration_state"
    if [ -f "$STATE_FILE" ]; then
        # shellcheck disable=SC1090
        source "$STATE_FILE"
    fi

    TEST_URL="http://localhost:${PROXY_HOST_PORT:-8082}/"
    echo "Waiting briefly for integration proxy to accept connections..."
    sleep 1

    if curl -sSf "$TEST_URL" -m 5 >/dev/null 2>&1; then
        echo "✓ Integration proxy responded at $TEST_URL"
        # Prompt the user before cleaning up so they can inspect the integration project
        if [ -t 0 ] || [ -c /dev/tty ]; then
            echo "Press ENTER to tear down the integration project and continue the deploy (or Ctrl-C to leave it running)"
            # use tty_read to ensure the prompt appears when stdin/stdout are redirected
            tty_read ""
        else
            # Non-interactive: wait a short moment to allow checks, then proceed
            sleep 3
        fi
        # Clean up the integration project
        "$HELPER_SCRIPT" down
        "$HELPER_SCRIPT" clean
        exit 0
    else
        echo "✗ Integration proxy did not respond at $TEST_URL" >&2
        echo "Leaving integration project running for investigation: state file at $STATE_FILE" >&2
        # Do not auto-clean so user can inspect; return non-zero
        exit 3
    fi
fi

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

# If the shared renderer is available, compute deployment values (RAILS_RELATIVE_URL_ROOT, etc.)
if type detect_deployment_values >/dev/null 2>&1; then
    detect_deployment_values "$PROJECT_ROOT" "$DEFAULTS_FILE" "$CONFIG_FILE"
fi

# Compute values
# Compute values (use safe expansions)
APP_HOST=${APP_HOST:-web}
DOMAIN_NAME=${DOMAIN_NAME:-${OPENPROJECT_HOST_NAME:-}}
# Use the renderer-provided path value
RELATIVE_ROOT=${RAILS_RELATIVE_URL_ROOT:-}
PROXY_BIND_ADDRESS=${PROXY_BIND_ADDRESS:-0.0.0.0}
PROXY_HTTP_PORT=${PROXY_HTTP_PORT:-80}
PROXY_HTTPS_PORT=${PROXY_HTTPS_PORT:-443}
PROXY_TLS_MODE=${PROXY_TLS_MODE:-internal}
# Read proxy redirect preference (default: empty -> leave Caddy default behavior)
# Use only canonical PROXY_HTTPS_REDIRECT
PROXY_HTTPS_REDIRECT=${PROXY_HTTPS_REDIRECT:-}

# Ensure proxy paths are defined early to avoid unbound variable when script is parsed
PROXY_DIR=${PROXY_DIR:-"$PROJECT_ROOT/proxy"}
TEMPLATE_FILE=${TEMPLATE_FILE:-"$PROXY_DIR/Caddyfile.template"}

# If RELATIVE_ROOT contains unresolved ${...} references, expand them
if [[ "$RELATIVE_ROOT" == *'${'* ]]; then
    eval "RELATIVE_ROOT=\"$RELATIVE_ROOT\""
fi

# Fallback to reading project .env if still empty
    if [ -z "$RELATIVE_ROOT" ] && [ -f "$PROJECT_ROOT/.env" ]; then
    # Prefer explicit RAILS_RELATIVE_URL_ROOT in .env
    val=$(grep -E '^(RAILS_RELATIVE_URL_ROOT)=' "$PROJECT_ROOT/.env" || true)
        if [ -n "$val" ]; then
            RELATIVE_ROOT=${val#*=}
            # strip surrounding quotes if present
            RELATIVE_ROOT=${RELATIVE_ROOT%\"}
            RELATIVE_ROOT=${RELATIVE_ROOT#\"}
        fi
    fi

# Truncate the template file so multiple runs don't append duplicate site blocks
if [ -f "$TEMPLATE_FILE" ]; then
    : > "$TEMPLATE_FILE"
fi

PROXY_DIR="$PROJECT_ROOT/proxy"
TEMPLATE_FILE="$PROXY_DIR/Caddyfile.template"

if [ ! -d "$PROXY_DIR" ]; then
    echo "⚠ Proxy directory not found at $PROXY_DIR - skipping proxy configure"
    exit 0
fi

# Export variables expected by the gomplate renderer and call it
export OPENPROJECT_HOST_NAME="$DOMAIN_NAME"
export RAILS_RELATIVE_URL_ROOT="$RELATIVE_ROOT"
export PROXY_HTTP_PORT="$PROXY_HTTP_PORT"
export PROXY_HTTPS_PORT="$PROXY_HTTPS_PORT"
export PROXY_TLS_MODE="$PROXY_TLS_MODE"
export PROXY_HTTPS_REDIRECT="$PROXY_HTTPS_REDIRECT"
export APP_HOST="$APP_HOST"

# Render using shared renderer script (it validates via caddy adapt and reloads if valid)
if [ -x "$PROJECT_ROOT/scripts/deploy/render_caddy.sh" ]; then
    "$PROJECT_ROOT/scripts/deploy/render_caddy.sh" || {
        echo "✗ Caddyfile rendering or validation failed" >&2
        exit 2
    }
    echo "✓ Rendered and deployed Caddyfile via renderer"
else
    echo "⚠ Renderer script not found at $PROJECT_ROOT/scripts/deploy/render_caddy.sh; skipping" >&2
fi

exit 0
