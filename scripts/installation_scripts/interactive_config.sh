#!/bin/bash

# OpenProject Interactive Deployment Script
# This script provides an interactive way to deploy OpenProject with Docker Compose
# Configuration is saved to interactive_config.cfg for use by utility scripts

set -e  # Exit on any error

echo "=========================================="
echo "OpenProject Interactive Deployment Script"
echo "=========================================="
echo

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
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        if [ -z "$input" ]; then
            input="$default"
        fi
    else
        read -p "$prompt: " input
    fi
    
    eval "$varname='$input'"
}

# Function to validate yes/no input
confirm() {
    local prompt="$1"
    local default="$2"
    
    if [ -n "$default" ]; then
        while true; do
            read -p "$prompt (y/n) [$default]: " yn
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
            read -p "$prompt (y/n): " yn
            case $yn in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
                * ) echo "Please answer yes or no.";;
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

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "No .env file found. Creating one from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "Created .env file from .env.example"
    else
        echo "Error: .env.example not found. Cannot create .env file."
        exit 1
    fi
else
    echo "Found existing .env file."
fi

echo
echo "Current configuration preview:"
echo "=============================="
if [ -f ".env" ]; then
    echo "Key settings from .env:"
    grep -E "^(OPENPROJECT_HOST|OPENPROJECT_HTTPS|TAG)" .env | head -5
fi
echo

if confirm "Would you like to modify the configuration interactively?" "y"; then
    echo
    echo "Interactive Configuration:"
    echo "========================="
    
    # Read current values from .env if they exist
    current_host=$(grep "^OPENPROJECT_HOST__NAME=" .env 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "localhost")
    current_https=$(grep "^OPENPROJECT_HTTPS=" .env 2>/dev/null | cut -d'=' -f2 || echo "false")
    current_tag=$(grep "^TAG=" .env 2>/dev/null | cut -d'=' -f2 || echo "16")
    
    # Get current git configuration if it exists
    current_git_user=$(git config --global user.name 2>/dev/null || echo "")
    current_git_email=$(git config --global user.email 2>/dev/null || echo "")
    
    echo "Environment Configuration:"
    echo "-------------------------"
    # Get current environment type from config if it exists
    current_env_type=$(grep "^ENVIRONMENT_TYPE=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 || echo "localdev")
    
    # Convert current environment to number for display
    case "$current_env_type" in
        localdev) current_env_num="1" ;;
        remotedev) current_env_num="2" ;;
        remotetest) current_env_num="3" ;;
        production) current_env_num="4" ;;
        *) current_env_num="1" ;;
    esac
    
    echo "Available environment types:"
    echo "  1) localdev    - Local development environment"
    echo "  2) remotedev   - Remote development server"
    echo "  3) remotetest  - Remote testing/staging server"
    echo "  4) production  - Production server"
    echo
    
    # Prompt for environment selection
    read -p "Select environment type (1-4) [$current_env_num]: " env_input
    if [ -z "$env_input" ]; then
        env_input="$current_env_num"
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
    echo "OpenProject Configuration:"
    echo "-------------------------"
    prompt_with_default "Enter the hostname for OpenProject" "$current_host" "host_name"
    prompt_with_default "Enable HTTPS? (true/false)" "$current_https" "use_https"
    prompt_with_default "OpenProject version tag" "$current_tag" "op_tag"
    
    echo
    echo "Git Configuration:"
    echo "-----------------"
    
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
    echo "Domain Configuration:"
    echo "--------------------"
    # Get current domain values from config if they exist
    current_domain=$(grep "^DOMAIN_NAME=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    current_subdomain=$(grep "^SUBDOMAIN=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
    
    prompt_with_default "Domain name (e.g., example.com)" "$current_domain" "domain_name"
    prompt_with_default "Subdomain (e.g., openproject, leave empty for none)" "$current_subdomain" "subdomain"
    
    echo
    echo "Operating System Configuration:"
    echo "------------------------------"
    
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
    
    # Get current OS family from config or detect it
    current_os_family=$(grep "^OS_FAMILY=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2 || detect_os_family)
    
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
    echo "  1) debian     - Debian, Ubuntu, Mint, Raspbian"
    echo "  2) redhat     - RHEL, CentOS, Fedora, Rocky, AlmaLinux"
    echo "  3) suse       - openSUSE, SLES"
    echo "  4) arch       - Arch Linux, Manjaro, EndeavourOS"
    echo "  5) slackware  - Slackware"
    echo
    
    # Show detected OS if available
    if [ "$current_os_family" != "unknown" ]; then
        echo "Detected OS family: $current_os_family"
    fi
    
    # Prompt for OS family selection
    read -p "Select OS family (1-5) [$current_os_num]: " os_input
    if [ -z "$os_input" ]; then
        os_input="$current_os_num"
    fi
    
    # Convert number to OS family name
    case "$os_input" in
        1|debian)
            os_family="debian"
            ;;
        2|redhat)
            os_family="redhat"
            ;;
        3|suse)
            os_family="suse"
            ;;
        4|arch)
            os_family="arch"
            ;;
        5|slackware)
            os_family="slackware"
            ;;
        *)
            echo "⚠ Invalid selection '$os_input'. Using detected/default: $current_os_family"
            os_family="$current_os_family"
            ;;
    esac
    
    echo "✓ OS family set to: $os_family"
    
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
        echo "PostgreSQL database admin password is already configured."
        if confirm "Keep current database admin password?"; then
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
    echo "Database Storage Configuration:"
    echo "------------------------------"
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
    
    read -p "Select database storage type (1-2) [$current_storage_num]: " storage_input
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

echo
echo "✓ Configuration saved to: $DEPLOY_CONFIG"
echo
echo "To deploy OpenProject, run:"
echo "  ./scripts/installation_scripts/deploy.sh"
echo
echo "Or use the utility scripts manually:"
echo "  1. ./scripts/installation_scripts/installation_utilities/configure_docker.sh"
echo "  2. ./scripts/installation_scripts/installation_utilities/build_stack.sh"
echo
echo "Configuration complete!"