#!/usr/bin/env bash
set -euo pipefail

# generate_deployment_config.sh
# Detect deployment values (from interactive_config.cfg and defaults) and
# generate or preview deployment artifacts:
#  - .env (backed up if exists)
#  - docker-compose.override.yml (backed up if exists)
#  - proxy/Caddyfile.template (backed up if exists)
#
# Usage:
#   ./generate_deployment_config.sh        # dry-run, prints files to stdout
#   ./generate_deployment_config.sh --apply # write files (back up existing)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find project root by walking up until we find docker-compose.yml
PROJECT_ROOT=""
CUR="${SCRIPT_DIR}"
while [ "$CUR" != "/" ]; do
    if [ -f "$CUR/docker-compose.yml" ]; then
        PROJECT_ROOT="$CUR"
        break
    fi
    CUR="$(dirname "$CUR")"
done
if [ -z "$PROJECT_ROOT" ]; then
    # fallback to workspace root
    PROJECT_ROOT="/opt/openproject"
fi

DEFAULTS_FILE="$SCRIPT_DIR/../../interactive_config.cfg.defaults"
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"

SCRIPT_DIR_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../common"
# shellcheck disable=SC1090
source "$SCRIPT_DIR_HELPER/config_render.sh"

DRY_RUN=true
VALIDATE_CADDY=false
VALIDATE_COMPOSE=false
if [ "${1:-}" = "--apply" ]; then
    DRY_RUN=false
fi
if [ "${1:-}" = "--validate-caddy" ]; then
    VALIDATE_CADDY=true
fi
if [ "${1:-}" = "--validate-compose" ]; then
    VALIDATE_COMPOSE=true
fi

# Detect values (fills PROJECT_ROOT, ENV_PATH, etc.)
detect_deployment_values "$PROJECT_ROOT" "$DEFAULTS_FILE" "$CONFIG_FILE"

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN: previewing files\n"
    echo "---- ${ENV_PATH} ----"
    render_env
    echo "\n---- ${OVERRIDE_PATH} ----"
    render_override
    echo "\n---- ${CADDY_TEMPLATE_PATH} ----"
    render_caddy_template
    echo
    print_summary

    # If validation flags requested in dry-run, run them and report
    overall_rc=0
    if [ "$VALIDATE_CADDY" = "true" ]; then
        echo "\nRunning Caddy validation (dry-run)..."
        validate_caddy || overall_rc=$?
    fi
    if [ "$VALIDATE_COMPOSE" = "true" ]; then
        echo "\nRunning docker-compose validation (dry-run)..."
        validate_compose || overall_rc=$?
    fi

    exit $overall_rc
fi

# If validation-only flags are provided alongside apply, run validations first
if [ "$VALIDATE_CADDY" = "true" ]; then
    echo "Running Caddy validation..."
    validate_caddy || true
fi
if [ "$VALIDATE_COMPOSE" = "true" ]; then
    echo "Running docker-compose validation..."
    validate_compose || true
fi

# APPLY MODE: write files with backups
echo "Applying generated configuration..."
write_files true
print_summary

exit 0
