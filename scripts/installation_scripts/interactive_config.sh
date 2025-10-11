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
# Prompt timeouts disabled by default; use --timeouts-enabled to enable
TIMEOUTS_ENABLED="false"

# Parse simple flags (only --no-deploy for now)
while [ "$#" -gt 0 ]; do
    case "$1" in
        --no-deploy)
            NO_DEPLOY="true"
            shift
            ;;
        --timeouts-enabled)
            TIMEOUTS_ENABLED="true"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--no-deploy] [--timeouts-enabled]"
            echo
            echo "  --no-deploy         Do not run ./scripts/installation_scripts/deploy.sh at the end"
            echo "  --timeouts-enabled  Enable prompt timeouts (default timeout: 30s). When not set, prompts will block until the user responds."
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

# Track whether a persistent .cfg existed when the script started. If the
# user declines to apply defaults and declines interactive modification, we
# should avoid creating/populating a new .cfg file. This flag is used by the
# finalize step to decide whether to persist defaults into the file.
DEPLOY_CONFIG_EXISTS_AT_START=$([ -f "$DEPLOY_CONFIG" ] && echo 1 || echo 0)

# When the user explicitly applies defaults (via apply_defaults_to_cfg) we
# set this to 1 so finalize knows it may persist values.
SHOULD_PERSIST_DEFAULTS=0

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
        URI_NAMESPACE_ENABLED)
            _lc=$(printf "%s" "$value" | tr '[:upper:]' '[:lower:]')
            case "$_lc" in
                t|true|1|yes|y) value="true" ;;
                f|false|0|no|n) value="false" ;;
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

# Configure prompt timeouts: by default timeouts are disabled. When the
# user supplies --timeouts-enabled, set PROMPT_TIMEOUT to a sensible value
# so prompt helpers use timeouts.
if [ "${TIMEOUTS_ENABLED:-false}" = "true" ]; then
    # default timeout in seconds; callers can override PROMPT_TIMEOUT if needed
    PROMPT_TIMEOUT=${PROMPT_TIMEOUT:-30}
else
    # unset PROMPT_TIMEOUT so prompt helpers will block by default
    unset PROMPT_TIMEOUT
fi

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
    # Installer expects canonical keys (URI_NAMESPACE, URI_NAMESPACE_ENABLED)
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
        # record that defaults were applied so finalize may persist remaining keys
        SHOULD_PERSIST_DEFAULTS=1
        echo "Applied defaults. Current config now";
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




# Offer to run an integration proxy test so users can validate their settings
# before committing to a full build/deploy. This uses the existing proxy
# integration helper which spins up a temporary proxy+hello backend and waits
# for the user to inspect/confirm before tearing down.


    integration_test_body=$(cat <<EOF
Choose the OpenProject repository tag (release or branch) to deploy. 
If unsure, use the default stable tag. Not currently used for any 
functionality in the build process. So don't sweat it too much.
EOF
)
    section "Quick Test" "$integration_test_body"

if validate_yn "Would you like to run an integration proxy test to validate these settings now?" "n"; then
    echo
    echo "Running integration proxy test (prober)..."
    PROBER="$SCRIPT_DIR/../../proxy/integration_test/prober.sh"
    if [ -x "$PROBER" ]; then
        # Prober will manage prompts and call the run_integration_test helper.
        "$PROBER" || {
            echo "Integration prober failed or was left running. You may re-run interactive configuration to adjust settings." >&2
        }
    else
    echo "⚠ Integration prober not found at: $PROBER" >&2
    fi
fi




    # ...existing code continues

# Ask if user wants to run deployment now (run_finalize will already have printed
# the final configuration summary for the user).
# If required keys are missing, use a safer confirmation prompt and default to 'n'.
# Use the same persistence policy as finalize to decide whether defaults count
# toward satisfying required keys.
# Determine whether persistence is allowed here
PERSIST_ALLOWED=0
if [ "${DEPLOY_CONFIG_EXISTS_AT_START:-0}" = "1" ] || [ "${SHOULD_PERSIST_DEFAULTS:-0}" = "1" ]; then
    PERSIST_ALLOWED=1
fi

# Check required keys
required_keys=(OPENPROJECT_HOST_NAME DOMAIN_NAME OPENPROJECT_HTTPS OPENPROJECT_TAG)
missing=()
for k in "${required_keys[@]}"; do
    if [ "$PERSIST_ALLOWED" -eq 1 ]; then
        v=$(get_effective "$k" || true)
    else
        v=$(get_cfg "$k" || true)
    fi
    if [ -z "$v" ]; then missing+=("$k"); fi
done

if [ "${#missing[@]}" -ne 0 ]; then
    deploy_prompt="Are you sure you wish to run the deployment now?"
    deploy_default="n"
else
    deploy_prompt="Would you like to run the deployment now?"
    deploy_default="y"
fi

if validate_yn "$deploy_prompt" "$deploy_default"; then
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

