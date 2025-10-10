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
        OPENPROJECT_HTTPS|PROXY_HTTPS_REDIRECT)
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
    # Print a consistent confirmation for the user
    # Use a check to avoid printing when we intentionally skip writing empty values
    if [ -n "${value}" ]; then
        printf "✓ %s set to: %s\n" "$key" "$value"
    fi
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
    # Migrate old PROXY_HTTP_TO_HTTPS_REDIRECT -> PROXY_HTTPS_REDIRECT if present
    if grep -q '^PROXY_HTTP_TO_HTTPS_REDIRECT=' "$DEPLOY_CONFIG" 2>/dev/null; then
        oldv=$(get_cfg "PROXY_HTTP_TO_HTTPS_REDIRECT" || true)
        if [ -n "$oldv" ]; then
            # Normalize and write to new key name
            lc=$(printf "%s" "$oldv" | tr '[:upper:]' '[:lower:]')
            case "$lc" in
                t|true) newv="true" ;;
                f|false) newv="false" ;;
                *) newv="$lc" ;;
            esac
            # Remove any existing new key and append normalized value
            grep -v '^PROXY_HTTPS_REDIRECT=' "$DEPLOY_CONFIG" > "${DEPLOY_CONFIG}.tmp" 2>/dev/null || true
            mv "${DEPLOY_CONFIG}.tmp" "$DEPLOY_CONFIG" 2>/dev/null || true
            echo "PROXY_HTTPS_REDIRECT=\"$newv\"" >> "$DEPLOY_CONFIG"
            # Remove old key
            sed -i '/^PROXY_HTTP_TO_HTTPS_REDIRECT=/d' "$DEPLOY_CONFIG" 2>/dev/null || true
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

# The `print_config_summary` and `apply_defaults_to_cfg` helpers are implemented
# in `scripts/installation_scripts/configure_scripts/01_intro.sh` so they can be
# reused by other configure scripts. They are sourced at startup via the
# configure_scripts/*.sh loader above.

# Before asking whether to modify, show a summary and offer to apply defaults
print_config_summary
summary_ok=$?
echo
if [ -f "${SCRIPT_DIR}/interactive_config.cfg.defaults" ]; then
    if validate_yn "Would you like to replace current .cfg values with the defaults from .cfg.defaults?" "n"; then
        apply_defaults_to_cfg
        echo "Applied defaults. Current config now:";
        print_config_summary
        # Re-evaluate validity after applying defaults
        print_config_summary >/dev/null 2>&1
        summary_ok=$?
    fi
fi

# Now ask whether to modify interactively, but present more options if config is invalid
if [ $summary_ok -eq 0 ]; then
    # Config appears valid
    # Decide default for the interactive modify prompt: if the user's .cfg
    # already contains any non-empty values, default to 'n' (don't modify);
    # otherwise default to 'y'.
    interactive_default="y"
    if [ -f "${DEPLOY_CONFIG:-$SCRIPT_DIR/interactive_config.cfg}" ]; then
        for _k in OPENPROJECT_TAG GIT_USERNAME GIT_EMAIL ENVIRONMENT_TYPE OS_FAMILY OPENPROJECT_HOST_NAME OPENPROJECT_HTTPS PROXY_HTTPS_REDIRECT DOMAIN_NAME DEFAULT_DBADMIN_PASSWORD DATABASE_STORAGE_TYPE NAMESPACE; do
            _v=$(get_cfg "$_k" || true)
            if [ -n "$_v" ]; then
                interactive_default="n"
                break
            fi
        done
    fi
    # Ensure we always finalize the configuration even if the user declines
    # to modify it interactively. Use a guard so we don't finalize twice when
    # the interactive flow itself calls run_finalize.
    did_finalize="false"
    if validate_yn "Would you like to modify the configuration interactively?" "$interactive_default"; then
        # run full interactive flow as before
        if [ -t 1 ]; then
            clear
        fi
        run_intro
        anykey "Press any key to continue..."
        run_repo
        run_env_os
        run_web_proxy
        run_db
        run_finalize
        did_finalize="true"
    fi
    # If the user chose not to run the interactive flow, still print the
    # finalized configuration so the subsequent deploy prompt shows accurate
    # instructions and the final config file is saved/displayed.
    if [ "$did_finalize" != "true" ]; then
        run_finalize
    fi
else
    # Config missing keys — ask user whether to fix missing keys interactively or run full flow
    echo
    echo "Options:"
    echo "  1) Fix missing/invalid values interactively (recommended)"
    echo "  2) Run full interactive configuration (all prompts)"
    echo "  3) Proceed with current config as-is (not recommended)"
    while true; do
        printf "Select an option [1]: "
        read opt
        if [ -z "$opt" ]; then opt=1; fi
        case "$opt" in
            1)
                # Determine which modules to run based on missing keys
                # Simple mapping
                missing_keys=()
                for k in OPENPROJECT_HOST_NAME DOMAIN_NAME OPENPROJECT_HTTPS OPENPROJECT_TAG DEFAULT_DBADMIN_PASSWORD DATABASE_STORAGE_TYPE; do
                    v=$(get_effective "$k" || true)
                    if [ -z "$v" ]; then missing_keys+=("$k"); fi
                done
                # If DB keys missing, run DB; if web keys missing, run web; repo keys missing, run repo
                need_db=0; need_web=0; need_repo=0
                for k in "${missing_keys[@]}"; do
                    case "$k" in
                        DEFAULT_DBADMIN_PASSWORD|DATABASE_STORAGE_TYPE) need_db=1 ;;
                        OPENPROJECT_HOST_NAME|DOMAIN_NAME|OPENPROJECT_HTTPS|NAMESPACE|PROXY_HTTPS_REDIRECT) need_web=1 ;;
                        OPENPROJECT_TAG|GIT_USERNAME|GIT_EMAIL) need_repo=1 ;;
                    esac
                done
                if [ "$need_repo" -eq 1 ]; then run_repo; fi
                if [ "$need_web" -eq 1 ]; then run_web_proxy; fi
                if [ "$need_db" -eq 1 ]; then run_db; fi
                run_finalize
                break
                ;;
            2)
                # Full flow
                if [ -t 1 ]; then clear; fi
                run_intro; anykey "Press any key to continue..."; run_repo; run_env_os; run_web_proxy; run_db; run_finalize
                break
                ;;
            3)
                # Proceed as-is
                run_finalize
                break
                ;;
            *) echo "Please enter 1, 2, or 3" ;;
        esac
    done
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
    # The final config has already been printed by run_finalize(). Show a
    # concise instruction on how to deploy when the user declines to run the
    # automated deploy step.
    echo "To deploy OpenProject, run:"
    echo "  ./scripts/installation_scripts/deploy.sh"
fi