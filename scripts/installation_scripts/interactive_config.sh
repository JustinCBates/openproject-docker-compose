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
    interactive_body=$(cat <<'EOF'
Follow a guided prompt sequence to gather deployment settings. 
Press <Enter> to accept any default shown. 
Changes are saved to interactive_config.cfg.
EOF
)
    supersection "Interactive Configuration:" "$interactive_body"
    
    # Read current values from config file if they exist. This enumerates
    # known keys found in interactive_config.cfg so the interactive prompts
    # can show sensible defaults.
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

    # Provide sensible fallbacks for any keys that were empty
    if [ -z "$current_https" ]; then current_https="false"; fi
    if [ -z "$current_tag" ]; then current_tag="16"; fi
    if [ -z "$current_db_storage" ]; then current_db_storage="docker-volumes"; fi
    if [ -z "$current_env_type" ]; then current_env_type="localdev"; fi
    

    # If no hostname in config, try to detect from system
    if [ -z "$current_host" ]; then
        detected_hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
        current_host="$detected_hostname"
    fi
    
    # Get current git configuration if it exists
    current_git_user=$(git config --global user.name 2>/dev/null || echo "")
    current_git_email=$(git config --global user.email 2>/dev/null || echo "")

    # Repo Settings
    repo_body=$(cat <<'EOF'
Repository and git configuration for OpenProject.
EOF
)
    section "Repo Settings" "$repo_body"
    git_version_body=$(cat <<'EOF'
Choose the OpenProject repository tag (release or branch) to deploy. 
If unsure, use the default stable tag.
EOF
)
    subsection "OpenProject Version Configuration" "$git_version_body"
    # Prompt for OpenProject version tag before environment selection
    prompt_with_default "OpenProject version tag" "$current_tag" "op_tag"
    echo " "

    git_cfg_body=$(cat <<'EOF'
Enter the Git user.name and user.email used by installer scripts when creating 
or patching local artifacts (commits, config templates). 
These values become global git config if provided.
EOF
)
    subsection "Git Configuration" "$git_cfg_body"
    # Get Git configuration from config file first, then fall back to global git config
    current_git_user_cfg=$(grep "^GIT_USERNAME=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    current_git_email_cfg=$(grep "^GIT_EMAIL=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    
    # Use config file values if they exist, otherwise use global git config
    if [ -n "$current_git_user_cfg" ]; then
        current_git_user="$current_git_user_cfg"
    fi
    if [ -n "$current_git_email_cfg" ]; then
        current_git_email="$current_git_email_cfg"
    fi
    
    # If still no values, provide helpful defaults
    if [ -z "$current_git_user" ]; then
        current_git_user="$(whoami)"
    fi
    if [ -z "$current_git_email" ]; then
        current_git_email="$(whoami)@$(hostname -f)"
    fi
    
    prompt_with_default "Git username" "$current_git_user" "git_username"
    prompt_with_default "Git email" "$current_git_email" "git_email"

    # Environment Configuration
    env_section_body=$(cat <<'EOF'
Select the environment type that best matches your deployment goals. Defaults are provided when possible.
EOF
)
    section "Environment Configuration:" "$env_section_body"
    # Get current environment type from config if it exists
    current_env_type=$(grep "^ENVIRONMENT_TYPE=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "localdev")
    
        # Provide detailed descriptions for each environment in the section body
        env_body=$(cat <<'EOF'
Available environment types:

localdev    - Local development: single-machine setup for developers. Runs
    services in a way that optimizes for quick iteration and debugging, may
    enable extra development-only features, and is NOT tuned for production
    reliability or security. Use this for local testing, feature work, and when
    you don't need high availability.

remotedev   - Remote development server: suitable for remote development teams
    or staging where multiple developers need access. This configuration is
    closer to production in security and networking but still intended for
    iterative feature testing rather than live production traffic. Backups and
    snapshots are recommended.

remotetest  - Remote testing/staging: an environment that mirrors production as
    closely as possible for automated testing, QA and pre-release verification.
    Use this for load testing and acceptance testing before promoting images to
    production. Expect stricter access controls and possibly separate data
    stores.

production  - Production server: configured for security, reliability, and
    maintainability. Enables TLS, appropriate persistence, backups, and
    monitoring. Only use this configuration when hosting real user data and
    traffic.
EOF
)
    subsection "Environment Configuration" "$env_body"
    # Use numbered_list_prompt to print list, prompt and validate selection.
    # Pass the token default (e.g. 'localdev') and let the helper map it to
    # the numeric default internally.
    numbered_list_prompt "$current_env_type" env_token env_idx \
        "localdev    - Local development environment" \
        "remotedev   - Remote development server" \
        "remotetest  - Remote testing/staging server" \
        "production  - Production server"

    # Use the returned token directly
    environment_type="$env_token"
    echo "✓ Environment type set to: $environment_type"
    
    # Operating System Configuration (moved under Environment Configuration)
    os_sub_body=$(cat <<'EOF'
Select the OS family (Debian, RedHat, SUSE, Arch, Slackware). 
Installer steps and package commands will be tailored to this choice. 
Use the detected OS when possible.
EOF
)
    subsection "Operating System Configuration" "$os_sub_body"
    
    # Source OS detection helper from common/
    if [ -f "$SCRIPT_DIR/common/common_os.sh" ]; then
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/common/common_os.sh"
    fi

    # Prefer system detection for OS family. Only fall back to the saved
    # `OS_FAMILY` from the deployment config when the detection cannot
    # identify the system (returns 'unknown' or empty).
    detected_os_family=$(detect_os_family)
    if [ -n "$detected_os_family" ] && [ "$detected_os_family" != "unknown" ]; then
        current_os_family="$detected_os_family"
    else
        # Read OS_FAMILY from config if present, strip surrounding quotes and whitespace
        current_os_family_raw=$(grep "^OS_FAMILY=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 || true)
        if [ -n "$current_os_family_raw" ]; then
            # remove any surrounding single or double quotes and trim whitespace
            current_os_family=$(echo "$current_os_family_raw" | sed -e "s/^['\"]//" -e "s/['\"]$//" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        else
            current_os_family="$detected_os_family"
        fi
    fi

    # Show detected OS if available
    if [ "$current_os_family" != "unknown" ]; then
        echo "Detected OS family: $current_os_family"
        echo
    warn "Changing from the detected OS family may cause errors"
        echo "   in the configure and build process. The installation utilities"
        echo "   are optimized for the detected OS family."
        echo
    fi

    echo "Available OS families:"

    # Convert current OS family to number for display
    case "$current_os_family" in
        debian) current_os_num="1" ;;
        redhat) current_os_num="2" ;;
        suse) current_os_num="3" ;;
        arch) current_os_num="4" ;;
        slackware) current_os_num="5" ;;
        *) current_os_num="1" ;;
    esac

    # Prompt for OS family and use token directly
    numbered_list_prompt "$current_os_family" os_token os_idx \
        "debian     - Debian, Ubuntu, Mint, Raspbian" \
        "redhat     - RHEL, CentOS, Fedora, Rocky, AlmaLinux" \
        "suse       - openSUSE, SLES" \
        "arch       - Arch Linux, Manjaro, EndeavourOS" \
        "slackware  - Slackware"

    selected_os_family="$os_token"

    # Check if user selected different OS from detected and ask for confirmation.
    lc_current_os=$(echo "$current_os_family" | tr '[:upper:]' '[:lower:]')
    lc_selected_os=$(echo "$selected_os_family" | tr '[:upper:]' '[:lower:]')

    if [ "$lc_current_os" != "unknown" ] && [ "$lc_selected_os" != "$lc_current_os" ]; then
        echo
    warn "You selected '$selected_os_family' but detected OS is '$current_os_family'"
        echo "   This may cause compatibility issues with:"
        echo "   • Package installation commands"
        echo "   • Service management"
        echo "   • File paths and configurations"
        echo "   • Docker setup procedures"
        echo
        if validate_yn "Are you sure you want to use '$selected_os_family' instead of '$current_os_family'?" "n"; then
            os_family="$selected_os_family"
            echo "✓ Using user-selected OS family: $os_family"
        else
            os_family="$current_os_family"
            echo "✓ Using detected OS family: $os_family"
        fi
    else
        os_family="$selected_os_family"
        echo "✓ OS family set to: $os_family"
    fi
    echo
    web_host_body=$(cat <<'EOF'
Provide the public hostname where OpenProject will be served (e.g., example.com). 
Enable HTTPS if you have or will configure TLS certificates.
EOF
)
    subsection "Web Configuration" "$web_host_body"
    prompt_with_default "Enter the hostname for OpenProject" "$current_host" "host_name"
    prompt_with_default "Enable HTTPS? (true/false)" "$current_https" "use_https"

    echo
    proxy_intro_body=$(cat <<'EOF'
Proxy and TLS redirect settings.
EOF
)
    subsection "Web Configuration" "$proxy_intro_body"
    # Default redirect behavior: true if HTTPS enabled, false otherwise
    use_https_lc=$(echo "$use_https" | tr '[:upper:]' '[:lower:]')
    if [ "$use_https_lc" = "true" ]; then
        default_redirect="true"
    else
        default_redirect="false"
    fi

    echo
    proxy_body=$(cat <<'EOF'
Security note: If you disable HTTP->HTTPS redirects, users can access the site over plaintext HTTP. 
This exposes credentials, cookies, and session tokens to on-path attackers (MITM), 
and prevents automatic TLS enforcement by browsers. 
Only disable redirects if you understand and accept these risks.
EOF
)
    subsection "Proxy HTTPS redirect configuration" "$proxy_body"

    if validate_tf "Redirect HTTP to HTTPS?" "$default_redirect"; then
        proxy_redirect="true"
    else
        proxy_redirect="false"
    fi

    # Persist the choice to the deployment config
    save_config "PROXY_HTTP_TO_HTTPS_REDIRECT" "$proxy_redirect"
    echo "✓ PROXY_HTTP_TO_HTTPS_REDIRECT set to: $proxy_redirect"
    
    echo
    
    echo
    web_endpoint_body=$(cat <<'EOF'
Domain and subdomain endpoint settings.
EOF
)
    section "Web Endpoint URL Configuration" "$web_endpoint_body"
    # Get current domain values from config if they exist
    domain_body=$(cat <<'EOF'
Domain is the public host where OpenProject will be available (e.g., example.com).
EOF
)
    subsection "Domain Configuration:" "$domain_body"
    current_domain=$(grep "^DOMAIN_NAME=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    prompt_with_default "Domain name (e.g., Statesmen.com)" "$current_domain" "domain_name"

    subdomain_body=$(cat <<'EOF'
Optional subdomain used to namespace projects (leave empty for none). 
To keep an existing subdomain you must retype it below.
EOF
)
    subsection "Subdomain Configuration" "$subdomain_body"
    current_subdomain=$(grep "^SUBDOMAIN=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
        
    # Handle subdomain differently - inform user of current value, no default
    if [ -n "$current_subdomain" ]; then
    # Use caution() to print a yellow caution message with a symbol
    caution "To keep the current subdomain [$current_subdomain] you must retype it below; leaving the prompt empty will remove the subdomain."
    prompt_with_default "Subdomain (leave empty to remove current subdomain, or enter new value)" "" "subdomain"
    else
        echo "No subdomain currently set"
        prompt_with_default "Subdomain (e.g., StatesmenProjects, leave empty for none)" "" "subdomain"
    fi
    
    
    
    echo
    db_section_body=$(cat <<'EOF'
Database and storage configuration for PostgreSQL. Choose passwords and storage options.
EOF
)
    section "Database Configuration:" "$db_section_body"
    dbpw_body=$(cat <<'EOF'
PostgreSQL administrator password used for DB initialization and maintenance.

This password will be used for:
• PostgreSQL database administrator access
• Database initialization and maintenance
• NOT the OpenProject web application login

Password Security Recommendations:
• Use at least 12 characters
• Include uppercase, lowercase, numbers, and symbols
• Avoid dictionary words or personal information
• Consider using a password manager
EOF
)
    subsection "Database Password" "$dbpw_body"
    
    # Get current database admin password from config if it exists (for re-runs)
    current_default_admin_password=$(grep "^DEFAULT_DBADMIN_PASSWORD=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    
    if [ -n "$current_default_admin_password" ]; then
        echo "Current PostgreSQL database admin password: $current_default_admin_password"
        if validate_yn "Keep current database admin password?" "y"; then
            default_admin_password="$current_default_admin_password"
            echo "✓ Using existing database admin password"
        else
            echo -n "Enter new PostgreSQL database admin password: "
            read -s default_admin_password
            echo
            echo "✓ Database admin password updated"
        fi
    else
        echo -n "Enter PostgreSQL database admin password: "
        read -s default_admin_password
        echo
        if [ -z "$default_admin_password" ]; then
            echo "⚠ No password entered. Using default 'admin123' (CHANGE THIS AFTER INSTALLATION!)"
            default_admin_password="admin123"
        else
            echo "✓ Database admin password set"
        fi
    fi
    
    echo
    db_storage_body=$(cat <<'EOF'
Choose how to store database data and where it will reside on the host.
EOF
)
    subsection "Database Storage" "$db_storage_body"
    # Determine current storage type (fallback to docker-volumes) and index for display
    current_db_storage=$(grep "^DATABASE_STORAGE_TYPE=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "docker-volumes")
    case "$current_db_storage" in
        docker-volumes) current_storage_num="1" ;;
        bind-mounts) current_storage_num="2" ;;
        *) current_storage_num="1" ;;
    esac

    # Print database storage options and prompt with helper
    numbered_list_prompt "$current_db_storage" storage_token storage_idx \
        "docker-volumes  - Use Docker managed volumes (recommended for most cases)" \
        "bind-mounts     - Use host filesystem paths (easier for backups)"

    db_storage_type="$storage_token"
    if [ "$db_storage_type" = "docker-volumes" ]; then
        echo "✓ Using Docker managed volumes for database storage"
    elif [ "$db_storage_type" = "bind-mounts" ]; then
        echo "✓ Using host filesystem bind mounts for database storage"
        # Get the bind mount path if using bind mounts
        current_db_path=$(grep "^DATABASE_HOST_PATH=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "/opt/openproject/data")
        prompt_with_default "Host path for database data" "$current_db_path" "db_host_path"
    else
        echo "⚠ Invalid selection '$storage_idx'. Using default: docker-volumes"
        db_storage_type="docker-volumes"
    fi
    
    # Save all configuration to interactive_config.cfg file
    save_config "OPENPROJECT_HOST_NAME" "$host_name"
    save_config "OPENPROJECT_HTTPS" "$use_https"
    save_config "OPENPROJECT_TAG" "$op_tag"
    save_config "DEFAULT_DBADMIN_PASSWORD" "$default_admin_password"
    save_config "DATABASE_STORAGE_TYPE" "$db_storage_type"
    if [ "$db_storage_type" = "bind-mounts" ] && [ -n "$db_host_path" ]; then
        save_config "DATABASE_HOST_PATH" "$db_host_path"
    fi
    save_config "GIT_USERNAME" "$git_username"
    save_config "GIT_EMAIL" "$git_email"
    save_config "DOMAIN_NAME" "$domain_name"
    save_config "SUBDOMAIN" "$subdomain"
    save_config "ENVIRONMENT_TYPE" "$environment_type"
    save_config "OS_FAMILY" "$os_family"
    
    # Configure git if values were provided
    if [ -n "$git_username" ]; then
        git config --global user.name "$git_username"
        echo "Git username set to: $git_username"
    fi
    if [ -n "$git_email" ]; then
        git config --global user.email "$git_email"
        echo "Git email set to: $git_email"
    fi
    
    echo
    echo "Configuration saved to interactive_config.cfg!"
    echo "Note: .env file will be updated during deployment by configure_docker scripts."
fi

# =============================================================================
# CONFIGURATION COMPLETION
# =============================================================================

cfg_saved_body=$(cat <<'EOF'
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