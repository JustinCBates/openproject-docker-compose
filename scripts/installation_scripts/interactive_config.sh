#!/bin/bash

# OpenProject Interactive Deployment Script
# This script provides an interactive way to deploy OpenProject with Docker Compose
# Configuration is saved to interactive_config.cfg for use by utility scripts

set -e  # Exit on any error

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

echo "=========================================="
echo "OpenProject Interactive Deployment Script"
echo "=========================================="
echo

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

# prompt_with_default moved to scripts/installation_scripts/common/common_ui.sh

# validate_yn and validate_tf have been moved to
# scripts/installation_scripts/common/common_ui.sh

echo "This script will help you deploy OpenProject using Docker Compose."
echo "You can press Enter to accept default values shown in brackets."
echo

# Load existing configuration if available
load_config

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory."
    echo "Please run this script from the OpenProject directory."
    exit 1
fi

echo
cfg_preview_body=$(cat <<'EOF'
Preview of the existing `interactive_config.cfg` (truncated). 
Confirm or update values in the following prompts.
EOF
)
section "Current configuration preview:" "$cfg_preview_body"
if [ -f "$DEPLOY_CONFIG" ]; then
    echo "Key settings from configuration:"
    # Print all non-empty lines from the deployment config so users can see the full saved state.
    # Limit to the first 200 lines to avoid overwhelming the terminal in pathological cases.
    if [ -s "$DEPLOY_CONFIG" ]; then
        # Print lines that look like KEY="value" or KEY=value
        sed -n '1,200p' "$DEPLOY_CONFIG" | sed -e '/^[[:space:]]*$/d' || echo "No previous configuration found"
    else
        echo "No previous configuration found"
    fi
else
    echo "No previous configuration found"
fi
echo

if validate_yn "Would you like to modify the configuration interactively?" "y"; then
    echo
    # Load modular configure scripts
    for s in "$SCRIPT_DIR"/configure_scripts/*.sh; do
        # shellcheck source=/dev/null
        source "$s"
    done

    # Initialize shared defaults for modules
    if declare -f init_install_defaults >/dev/null 2>&1; then
        init_install_defaults
    else
        # Fallback to the previous inline logic if common helper is missing
        get_cfg() {
            local key="$1"
            grep -E "^${key}=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' || true
        }

        current_host=$(get_cfg "OPENPROJECT_HOST_NAME")
        current_https=$(get_cfg "OPENPROJECT_HTTPS")
        current_tag=$(get_cfg "OPENPROJECT_TAG")
        current_db_password=$(get_cfg "DEFAULT_DBADMIN_PASSWORD")
        current_db_storage=$(get_cfg "DATABASE_STORAGE_TYPE")
        current_git_user_cfg=$(get_cfg "GIT_USERNAME")
        current_git_email_cfg=$(get_cfg "GIT_EMAIL")
        current_domain=$(get_cfg "DOMAIN_NAME")
        current_subdomain=$(get_cfg "SUBDOMAIN")
        current_env_type=$(get_cfg "ENVIRONMENT_TYPE")
        current_os_family_raw=$(get_cfg "OS_FAMILY")
        current_relative_root=$(get_cfg "OPENPROJECT_RAILS__RELATIVE__URL__ROOT")

        if [ -z "$current_https" ]; then current_https="false"; fi
        if [ -z "$current_tag" ]; then current_tag="16"; fi
        if [ -z "$current_db_storage" ]; then current_db_storage="docker-volumes"; fi
        if [ -z "$current_env_type" ]; then current_env_type="localdev"; fi

        if [ -z "$current_host" ]; then
            detected_hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
            current_host="$detected_hostname"
        fi

        current_git_user=$(git config --global user.name 2>/dev/null || echo "")
        current_git_email=$(git config --global user.email 2>/dev/null || echo "")
    fi

    # Run each modular section in sequence (each module exports run_*())
    # run_intro now includes the preview; prompt to proceed after preview
    run_intro
    if ! validate_yn "Proceed with interactive configuration?" "y"; then
        echo "Aborting interactive configuration."
    else
        run_repo
        run_env_os
        run_web_proxy
        run_db
        run_finalize
        echo
        echo "Configuration saved to interactive_config.cfg!"
        echo "Note: .env file will be updated during deployment by configure_docker scripts."
    fi
fi

# =============================================================================
# CONFIGURATION COMPLETION
# =============================================================================

cfg_saved_body=$(cat <<EOF
Configuration saved to: $DEPLOY_CONFIG
EOF
)
section "Configuration saved to: $DEPLOY_CONFIG" "$cfg_saved_body"
echo
echo "To deploy OpenProject, run:"
echo "  ./scripts/installation_scripts/deploy.sh"
echo
echo "Or use the utility scripts manually:"
echo "  1. ./scripts/installation_scripts/installation_utilities/configure_docker.sh"
echo "  2. ./scripts/installation_scripts/installation_utilities/build_stack.sh"
echo
echo "Configuration complete!"
echo

# Ask if user wants to run deployment now
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