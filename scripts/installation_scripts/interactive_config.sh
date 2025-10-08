#!/bin/bash

# OpenProject Interactive Deployment Script
# This script provides an interactive way to deploy OpenProject with Docker Compose
# Configuration is saved to interactive_config.cfg for use by utility scripts

set -e  # Exit on any error

echo "=========================================="
echo "OpenProject Interactive Deployment Script"
echo "=========================================="
echo

# Source common helpers (colors, warn(), note())
if [ -f "$(dirname "${BASH_SOURCE[0]}")/common.sh" ]; then
    # shellcheck source=/dev/null
    source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
fi

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

# Function to prompt for user input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local varname="$3"
    # If we have a default and terminal supports colors, show it green in the prompt
    if [ -n "$default" ]; then
        # Build a colored default display only if stdout is a TTY. Avoid
        # calling format_default in a subshell, because command substitution
        # makes stdout non-tty and the color check would fail.
        if [ -t 1 ] && [ -n "$GREEN" ]; then
            def_display="${GREEN}${default}${RESET}"
            printf "%s [%b]: " "$prompt" "$def_display"
        else
            printf "%s [%s]: " "$prompt" "$default"
        fi
        read input
        if [ -z "$input" ]; then
            input="$default"
        fi
    else
        printf "%s: " "$prompt"
        read input
    fi

    eval "$varname='$input'"
}

# Function to validate yes/no input
validate_yn() {
    local prompt="$1"
    local default="$2"
    format_default() {
        local val="$1"
        if [ -t 1 ] && [ -n "$GREEN" ]; then
            printf "%s" "${GREEN}${val}${RESET}"
        else
            printf "%s" "$val"
        fi
    }

    if [ -n "$default" ]; then
        while true; do
            # Avoid command substitution for the same reason as above
            if [ -t 1 ] && [ -n "$GREEN" ]; then
                def_display="${GREEN}${default}${RESET}"
                printf "%s (y/n) [%b]: " "$prompt" "$def_display"
            else
                printf "%s (y/n) [%s]: " "$prompt" "$default"
            fi
            read yn
            # If empty input, use default
            if [ -z "$yn" ]; then
                yn="$default"
            fi
            case $yn in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    else
        # Original behavior when no default provided
        while true; do
            printf "%s (y/n): " "$prompt"
            read yn
            case $yn in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

# Function to validate true/false input
validate_tf() {
    local prompt="$1"
    local default="$2"
    format_default() {
        local val="$1"
        if [ -t 1 ] && [ -n "$GREEN" ]; then
            printf "%s" "${GREEN}${val}${RESET}"
        else
            printf "%s" "$val"
        fi
    }

    if [ -n "$default" ]; then
        while true; do
            if [ -t 1 ] && [ -n "$GREEN" ]; then
                def_display="${GREEN}${default}${RESET}"
                printf "%s (true/false) [%b]: " "$prompt" "$def_display"
            else
                printf "%s (true/false) [%s]: " "$prompt" "$default"
            fi
            read tf
            # If empty input, use default
            if [ -z "$tf" ]; then
                tf="$default"
            fi
            case $tf in
                [Tt]rue|[Tt] ) return 0;;
                [Ff]alse|[Ff] ) return 1;;
                * ) echo "Please answer true or false.";;
            esac
        done
    else
        # Original behavior when no default provided
        while true; do
            printf "%s (true/false): " "$prompt"
            read tf
            case $tf in
                [Tt]rue|[Tt] ) return 0;;
                [Ff]alse|[Ff] ) return 1;;
                * ) echo "Please answer true or false.";;
            esac
        done
    fi
}

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
section "Current configuration preview:"
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
    section "Interactive Configuration:"
    
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
    
    # Prompt for OpenProject version tag before environment selection
    prompt_with_default "OpenProject version tag" "$current_tag" "op_tag"

    section "Environment Configuration:"    

    # Get current environment type from config if it exists
    current_env_type=$(grep "^ENVIRONMENT_TYPE=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "localdev")
    
    # Convert current environment to number for display
    case "$current_env_type" in
        localdev) current_env_num="1" ;;
        remotedev) current_env_num="2" ;;
        remotetest) current_env_num="3" ;;
        production) current_env_num="4" ;;
        *) current_env_num="1" ;;
    esac
    
    echo "Available environment types:"
    # Print environment types, highlight the default line in green
    if type format_default >/dev/null 2>&1; then
        for num in 1 2 3 4; do
            case "$num" in
                1) label="localdev    - Local development environment";;
                2) label="remotedev   - Remote development server";;
                3) label="remotetest  - Remote testing/staging server";;
                4) label="production  - Production server";;
            esac
            if [ "$num" = "$current_env_num" ]; then
                printf "%b\n" "  ${GREEN}${num}) ${label}${RESET}"
            else
                printf "%s\n" "  ${num}) ${label}"
            fi
        done
    else
        echo "  1) localdev    - Local development environment"
        echo "  2) remotedev   - Remote development server"
        echo "  3) remotetest  - Remote testing/staging server"
        echo "  4) production  - Production server"
    fi
    echo
    


    # Prompt for environment selection (show default in green)
    if type format_default >/dev/null 2>&1; then
        def_display=$(format_default "$current_env_num")
        printf "%s [%b]: " "Select environment type (1-4)" "$def_display"
        read env_input
        if [ -z "$env_input" ]; then
            env_input="$current_env_num"
        fi
    else
        # Fallback: use printf + read so ANSI escapes render correctly in some shells
        printf "%s [%s]: " "Select environment type (1-4)" "$current_env_num"
        read env_input
        if [ -z "$env_input" ]; then
            env_input="$current_env_num"
        fi
    fi
    
    # Convert number to environment name
    case "$env_input" in
        1|localdev)
            environment_type="localdev"
            ;;
        2|remotedev)
            environment_type="remotedev"
            ;;
        3|remotetest)
            environment_type="remotetest"
            ;;
        4|production)
            environment_type="production"
            ;;
        *)
            echo "⚠ Invalid selection '$env_input'. Using default: localdev"
            environment_type="localdev"
            ;;
    esac
    
    echo "✓ Environment type set to: $environment_type"
    
    echo
    section "OpenProject Configuration:"
    prompt_with_default "Enter the hostname for OpenProject" "$current_host" "host_name"
    prompt_with_default "Enable HTTPS? (true/false)" "$current_https" "use_https"

    echo
    section "Proxy HTTPS redirect configuration:"
    # Default redirect behavior: true if HTTPS enabled, false otherwise
    use_https_lc=$(echo "$use_https" | tr '[:upper:]' '[:lower:]')
    if [ "$use_https_lc" = "true" ]; then
        default_redirect="true"
    else
        default_redirect="false"
    fi

    echo
    echo "Security note: If you disable HTTP->HTTPS redirects, users can access the site over plaintext HTTP."
    echo "This exposes credentials, cookies, and session tokens to on-path attackers (MITM), and prevents automatic TLS enforcement by browsers."
    echo "Only disable redirects if you understand and accept these risks."

    if validate_tf "Redirect HTTP to HTTPS?" "$default_redirect"; then
        proxy_redirect="true"
    else
        proxy_redirect="false"
    fi

    # Persist the choice to the deployment config
    save_config "PROXY_HTTP_TO_HTTPS_REDIRECT" "$proxy_redirect"
    echo "✓ PROXY_HTTP_TO_HTTPS_REDIRECT set to: $proxy_redirect"
    
    echo
    section "Git Configuration:"
    
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
    
    echo
    section "Domain Configuration:"
    # Get current domain values from config if they exist
    current_domain=$(grep "^DOMAIN_NAME=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    current_subdomain=$(grep "^SUBDOMAIN=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    
    prompt_with_default "Domain name (e.g., Statesmen.com)" "$current_domain" "domain_name"
    
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
    section "Operating System Configuration:"
    
    # Function to detect OS family
    detect_os_family() {
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            case "$ID" in
                ubuntu|debian|raspbian|linuxmint)
                    echo "debian"
                    ;;
                rhel|centos|fedora|rocky|almalinux|ol)
                    echo "redhat"
                    ;;
                opensuse*|sles|sled)
                    echo "suse"
                    ;;
                arch|manjaro|endeavouros|artix)
                    echo "arch"
                    ;;
                slackware)
                    echo "slackware"
                    ;;
                *)
                    echo "unknown"
                    ;;
            esac
        elif [ -f /etc/redhat-release ]; then
            echo "redhat"
        elif [ -f /etc/debian_version ]; then
            echo "debian"
        elif [ -f /etc/arch-release ]; then
            echo "arch"
        elif [ -f /etc/slackware-version ]; then
            echo "slackware"
        else
            echo "unknown"
        fi
    }
    
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
    
    # Convert current OS family to number for display
    case "$current_os_family" in
        debian) current_os_num="1" ;;
        redhat) current_os_num="2" ;;
        suse) current_os_num="3" ;;
        arch) current_os_num="4" ;;
        slackware) current_os_num="5" ;;
        *) current_os_num="1" ;;
    esac
    
    echo "Available OS families:"
    # Print OS families and highlight the detected/default one in green
    if type format_default >/dev/null 2>&1; then
        for num in 1 2 3 4 5; do
            case "$num" in
                1) label="debian     - Debian, Ubuntu, Mint, Raspbian";;
                2) label="redhat     - RHEL, CentOS, Fedora, Rocky, AlmaLinux";;
                3) label="suse       - openSUSE, SLES";;
                4) label="arch       - Arch Linux, Manjaro, EndeavourOS";;
                5) label="slackware  - Slackware";;
            esac
            if [ "$num" = "$current_os_num" ]; then
                printf "%b\n" "  ${GREEN}${num}) ${label}${RESET}"
            else
                printf "%s\n" "  ${num}) ${label}"
            fi
        done
    else
        echo "  1) debian     - Debian, Ubuntu, Mint, Raspbian"
        echo "  2) redhat     - RHEL, CentOS, Fedora, Rocky, AlmaLinux"
        echo "  3) suse       - openSUSE, SLES"
        echo "  4) arch       - Arch Linux, Manjaro, EndeavourOS"
        echo "  5) slackware  - Slackware"
    fi
    echo
    
    # Show detected OS if available
    if [ "$current_os_family" != "unknown" ]; then
        echo "Detected OS family: $current_os_family"
        echo
    warn "Changing from the detected OS family may cause errors"
        echo "   in the configure and build process. The installation utilities"
        echo "   are optimized for the detected OS family."
        echo
    fi
    
    # Prompt for OS family selection (show default in green)
    if type format_default >/dev/null 2>&1; then
        def_display=$(format_default "$current_os_num")
        printf "%s [%b]: " "Select OS family (1-5)" "$def_display"
        read os_input
        if [ -z "$os_input" ]; then
            os_input="$current_os_num"
        fi
    else
        # Fallback: use printf + read so ANSI escapes render correctly in some shells
        printf "%s [%s]: " "Select OS family (1-5)" "$current_os_num"
        read os_input
        if [ -z "$os_input" ]; then
            os_input="$current_os_num"
        fi
    fi
    
    # Convert number to OS family name
    case "$os_input" in
        1|debian)
            selected_os_family="debian"
            ;;
        2|redhat)
            selected_os_family="redhat"
            ;;
        3|suse)
            selected_os_family="suse"
            ;;
        4|arch)
            selected_os_family="arch"
            ;;
        5|slackware)
            selected_os_family="slackware"
            ;;
        *)
            echo "⚠ Invalid selection '$os_input'. Using detected/default: $current_os_family"
            selected_os_family="$current_os_family"
            ;;
    esac
    
    # Check if user selected different OS from detected and ask for confirmation.
    # Normalize to lowercase to avoid prompting when values differ only by case.
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
    echo "Database Configuration:"
    echo "----------------------"
    echo "Set the PostgreSQL database admin password for OpenProject."
    echo ""
    echo "This password will be used for:"
    echo "• PostgreSQL database administrator access"
    echo "• Database initialization and maintenance"
    echo "• NOT the OpenProject web application login"
    echo ""
    echo "Password Security Recommendations:"
    echo "• Use at least 12 characters"
    echo "• Include uppercase, lowercase, numbers, and symbols"
    echo "• Avoid dictionary words or personal information"
    echo "• Consider using a password manager"
    echo ""
    
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
    section "Database Storage Configuration:"
    echo "Choose how to store database data:"
    echo "  1) docker-volumes  - Use Docker managed volumes (recommended for most cases)"
    echo "  2) bind-mounts     - Use host filesystem paths (easier for backups)"
    echo
    
    # Get current storage type from config if it exists
    current_db_storage=$(grep "^DATABASE_STORAGE_TYPE=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 || echo "docker-volumes")
    
    # Convert current storage type to number for display
    case "$current_db_storage" in
        docker-volumes) current_storage_num="1" ;;
        bind-mounts) current_storage_num="2" ;;
        *) current_storage_num="1" ;;
    esac
    
    # Use printf + read to allow colored default display when available
    printf "%s [%s]: " "Select database storage type (1-2)" "$current_storage_num"
    read storage_input
    if [ -z "$storage_input" ]; then
        storage_input="$current_storage_num"
    fi
    
    case "$storage_input" in
        1|docker-volumes)
            db_storage_type="docker-volumes"
            echo "✓ Using Docker managed volumes for database storage"
            ;;
        2|bind-mounts)
            db_storage_type="bind-mounts"
            echo "✓ Using host filesystem bind mounts for database storage"
            
            # Get the bind mount path if using bind mounts
            current_db_path=$(grep "^DATABASE_HOST_PATH=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "/opt/openproject/data")
            prompt_with_default "Host path for database data" "$current_db_path" "db_host_path"
            ;;
        *)
            echo "⚠ Invalid selection '$storage_input'. Using default: docker-volumes"
            db_storage_type="docker-volumes"
            ;;
    esac
    
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

section "Configuration saved to: $DEPLOY_CONFIG"
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
    if [ -f "./scripts/installation_scripts/deploy.sh" ]; then
        ./scripts/installation_scripts/deploy.sh
    else
        echo "❌ Error: deploy.sh not found at ./scripts/installation_scripts/deploy.sh"
        echo "Please run the deployment manually using the commands shown above."
        exit 1
    fi
else
    echo
    echo "Deployment skipped. Run './scripts/installation_scripts/deploy.sh' when ready."
fi