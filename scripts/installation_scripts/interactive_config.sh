#!/bin/bash

# OpenProject Interactive Deployment Script
# This script provides an interactive way to deploy OpenProject with Docker Compose
# Configuration is saved to interactive_config.cfg for use by utility scripts

set -e  # Exit on any error

# Clear the terminal for interactive runs (only when stdout is a TTY)
if [ -t 1 ]; then
    clear
fi

# Default behavior: run deploy unless --no-deploy is passed
NO_DEPLOY="false"

# Parse simple flags (only --no-deploy for now)
while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-deploy)
            NO_DEPLOY="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--no-deploy]"
            echo
            echo "  --no-deploy   Do not run ./scripts/installation_scripts/deploy.sh at the end"
            exit 0
            ;;
        *)
            # Unknown arg - stop parsing to preserve positional behavior
            break
            ;;
    esac
done



# Source common helpers (colors, warn(), note())
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source common UI helpers from common/ if available
if [ -f "$SCRIPT_DIR/common/common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/common/common_ui.sh"
fi

# Source non-UI common helpers (init_install_defaults) if present
if [ -f "$SCRIPT_DIR/common/common.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/common/common.sh"
fi

# Generate and source a defaults file for interactive configuration. This file
# provides sensible defaults discovered from the host and is sourced before
# loading a user's interactive_config.cfg so values from the file override
# these defaults.
if declare -f generate_interactive_config_defaults >/dev/null 2>&1; then
    generate_interactive_config_defaults "$SCRIPT_DIR"
    DEFAULTS_FILE="$SCRIPT_DIR/interactive_config.cfg.defaults"
    if [ -f "$DEFAULTS_FILE" ]; then
        # shellcheck source=/dev/null
        # Export defaults so later sourced helpers see them in the environment
        set -a
        source "$DEFAULTS_FILE"
        set +a
    fi
fi

# `supersection()` is provided by the shared common helpers (common.sh).
# The shared implementation renders a stronger, more prominent heading.

# Configuration file for storing deployment settings
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_CONFIG="$SCRIPT_DIR/interactive_config.cfg"

# Function to save configuration to interactive_config.cfg file
save_config() {
    local key="$1"
    local value="$2"
    
    # Remove existing key if present, then add new value
    if [ -f "$DEPLOY_CONFIG" ]; then
        grep -v "^$key=" "$DEPLOY_CONFIG" > "${DEPLOY_CONFIG}.tmp" 2>/dev/null || true
        mv "${DEPLOY_CONFIG}.tmp" "$DEPLOY_CONFIG" 2>/dev/null || true
    fi
    # Do not write empty values; they shadow generated defaults.
    if [ -z "${value}" ]; then
        return 0
    fi

    # Normalize common boolean-like values for well-known keys so that
    # shorthand answers ('t'/'f') are persisted as literal 'true'/'false'.
    case "$key" in
        OPENPROJECT_HTTPS|PROXY_HTTP_TO_HTTPS_REDIRECT)
            # normalize to lowercase and map t/T/true/True -> true, f/F/false -> false
            _lc=$(printf "%s" "$value" | tr '[:upper:]' '[:lower:]')
            case "$_lc" in
                t|true) value="true" ;;
                f|false) value="false" ;;
                *) value="$_lc" ;;
            esac
            ;;
    esac
    # Quote the value to handle spaces and special characters
    echo "$key=\"$value\"" >> "$DEPLOY_CONFIG"
}

# Function to load configuration from interactive_config.cfg file
load_config() {
    if [ -f "$DEPLOY_CONFIG" ]; then
        # Source the config file, which now contains properly quoted values
        source "$DEPLOY_CONFIG" 2>/dev/null || {
            echo "⚠ Warning: Could not load configuration file. It may be corrupted."
            echo "  File: $DEPLOY_CONFIG"
            echo "  Starting with fresh configuration..."
            return 1
        }
    fi
}

# Load existing configuration if available
load_config

# Remove empty DOMAIN_NAME entries that may have been saved previously
# (an explicit empty assignment would shadow the generated defaults).
if [ -f "$DEPLOY_CONFIG" ]; then
    # Remove lines like: DOMAIN_NAME=""
    sed -i '/^DOMAIN_NAME=""$/d' "$DEPLOY_CONFIG" 2>/dev/null || true
fi

# Migrate any single-letter or mixed-case boolean values to 'true'/'false'
if [ -f "$DEPLOY_CONFIG" ]; then
    # OPENPROJECT_HTTPS
    if grep -q '^OPENPROJECT_HTTPS=' "$DEPLOY_CONFIG" 2>/dev/null; then
        curv=$(get_cfg "OPENPROJECT_HTTPS" || true)
        if [ -n "$curv" ]; then
            lc=$(printf "%s" "$curv" | tr '[:upper:]' '[:lower:]')
            case "$lc" in
                t|true) sed -i 's/^OPENPROJECT_HTTPS=.*/OPENPROJECT_HTTPS="true"/' "$DEPLOY_CONFIG" 2>/dev/null || true ;;
                f|false) sed -i 's/^OPENPROJECT_HTTPS=.*/OPENPROJECT_HTTPS="false"/' "$DEPLOY_CONFIG" 2>/dev/null || true ;;
            esac
        fi
    fi
    # PROXY_HTTP_TO_HTTPS_REDIRECT
    if grep -q '^PROXY_HTTP_TO_HTTPS_REDIRECT=' "$DEPLOY_CONFIG" 2>/dev/null; then
        curv=$(get_cfg "PROXY_HTTP_TO_HTTPS_REDIRECT" || true)
        if [ -n "$curv" ]; then
            lc=$(printf "%s" "$curv" | tr '[:upper:]' '[:lower:]')
            case "$lc" in
                t|true) sed -i 's/^PROXY_HTTP_TO_HTTPS_REDIRECT=.*/PROXY_HTTP_TO_HTTPS_REDIRECT="true"/' "$DEPLOY_CONFIG" 2>/dev/null || true ;;
                f|false) sed -i 's/^PROXY_HTTP_TO_HTTPS_REDIRECT=.*/PROXY_HTTP_TO_HTTPS_REDIRECT="false"/' "$DEPLOY_CONFIG" 2>/dev/null || true ;;
            esac
        fi
    fi
fi

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory."
    echo "Please run this script from the OpenProject directory."
    exit 1
fi

# Populate shared defaults for modules using the centralized initializer
    init_install_defaults

# Load modular configure scripts
for s in "$SCRIPT_DIR"/configure_scripts/*.sh; do
    # shellcheck source=/dev/null
    source "$s"
done

# Show preview; if stdout is not a tty (output redirected), write the
# preview directly to the controlling tty so the user still sees it.
run_preview

# Ask whether to modify the configuration interactively
if validate_yn "Would you like to modify the configuration interactively?" "y"; then
    # Clear the terminal for interactive runs (only when stdout is a TTY)
    if [ -t 1 ]; then
        clear
    fi
    # Run each modular section in sequence (each module exports run_*())
    # run_intro now includes the preview; prompt to proceed after preview
    run_intro
    # Prompt the user to proceed after the preview; anykey always returns 0
    anykey "Press any key to continue..."
    run_repo
    run_env_os
    run_web_proxy
    run_db
    run_finalize
    echo
    echo "Configuration saved to interactive_config.cfg!"
    echo "Note: .env file will be updated during deployment by configure_docker scripts."
fi

# Ask if user wants to run deployment now (run_finalize will already have printed
# the final configuration summary for the user)
if validate_yn "Would you like to run the deployment now?" "y"; then
    echo
    echo "Starting OpenProject deployment..."
    echo "=================================="
    
    # Check if deploy.sh exists
    if [ "$NO_DEPLOY" = "true" ]; then
        echo "(deploy suppressed by --no-deploy flag)"
    else
        if [ -f "./scripts/installation_scripts/deploy.sh" ]; then
            # Run the real deployment script
            ./scripts/installation_scripts/deploy.sh
        else
            echo "❌ Error: deploy.sh not found at ./scripts/installation_scripts/deploy.sh"
            echo "Please run the deployment manually using the commands shown above."
            # Do not exit here during automated UI tests
        fi
    fi
else
    echo
    echo "Deployment skipped. Run './scripts/installation_scripts/deploy.sh' when ready."
fi