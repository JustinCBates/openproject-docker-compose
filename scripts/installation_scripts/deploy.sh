#!/bin/bash

# OpenProject Deployment Script
# This script executes utility scripts in order to perform the deployment

set -e  # Exit on any error

echo "=========================================="
echo "OpenProject Deployment Script"
echo "=========================================="
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
UTILITIES_DIR="$SCRIPT_DIR/installation_utilities"
CONFIG_FILE="$SCRIPT_DIR/interactive_config.cfg"

 # Source common UI helpers if available
 if [ -f "$SCRIPT_DIR/common_ui.sh" ]; then
     # shellcheck source=/dev/null
     source "$SCRIPT_DIR/common_ui.sh"
 fi

# Parse top-level options
DRY_RUN=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            # stop parsing other arguments (not supported)
            break
            ;;
    esac
done

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please run the interactive deployment script first:"
    echo "  ./scripts/interactive_config.sh"
    exit 1
fi

echo "Loading configuration from $CONFIG_FILE..."
source "$CONFIG_FILE"

echo "Starting deployment process..."
echo

# =============================================================================
# UTILITY SCRIPT EXECUTION - Run in order
# =============================================================================

echo "Step 1: Configuring Git User..."
echo "==============================="
if [ -f "$UTILITIES_DIR/setup_git_user.sh" ]; then
    "$UTILITIES_DIR/setup_git_user.sh"
    echo "✓ Git user configuration completed"
else
    if type warn >/dev/null 2>&1; then
        warn "setup_git_user.sh not found, skipping"
    else
        echo "⚠ Warning: setup_git_user.sh not found, skipping"
    fi
fi
echo

echo "Step 2: Installing Docker..."
echo "============================"
if [ -f "$UTILITIES_DIR/install_docker.sh" ]; then
    echo "Executing Docker installation dispatcher..."
    "$UTILITIES_DIR/install_docker.sh"
    echo "✓ Docker installation completed"
else
    if type warn >/dev/null 2>&1; then
        warn "install_docker.sh dispatcher not found, skipping Docker installation"
    else
        echo "⚠ Warning: install_docker.sh dispatcher not found, skipping Docker installation"
    fi
fi
echo

echo "Step 3: Configuring Docker..."
echo "============================"
if [ -f "$UTILITIES_DIR/configure_docker.sh" ]; then
    echo "Executing Docker configuration dispatcher..."
    "$UTILITIES_DIR/configure_docker.sh"
    echo "✓ Docker configuration completed"
else
    if type warn >/dev/null 2>&1; then
        warn "configure_docker.sh dispatcher not found, skipping Docker configuration"
    else
        echo "⚠ Warning: configure_docker.sh dispatcher not found, skipping Docker configuration"
    fi
fi
echo

echo "Step 4: Building the stack..."
echo "============================"
if [ -f "$UTILITIES_DIR/build_stack.sh" ]; then
    echo "Executing Build Stack dispatcher..."
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Note: running in dry-run mode — no images will be built or pulled"
        "$UTILITIES_DIR/build_stack.sh" --dry-run
    else
        "$UTILITIES_DIR/build_stack.sh"
    fi
    echo "✓ Docker Build Stack  completed"
else
    if type warn >/dev/null 2>&1; then
        warn "build_stack.sh dispatcher not found, skipping Docker Build Stack"
    else
        echo "⚠ Warning: build_stack.sh dispatcher not found, skipping Docker Build Stack"
    fi
fi
echo

echo "=========================================="
echo "Deployment process completed!"
echo "=========================================="

echo
echo "Configuration Summary:"
echo "====================="
echo "Environment Type: ${ENVIRONMENT_TYPE:-Not set}"
echo "Domain Name:      ${DOMAIN_NAME:-Not set}"
echo "Subdomain:        ${SUBDOMAIN:-Not set}"
echo "OpenProject Host: ${OPENPROJECT_HOST_NAME:-Not set}"
echo "HTTPS Enabled:    ${OPENPROJECT_HTTPS:-Not set}"
echo "Git User:         ${GIT_USERNAME:-Not set}"
echo "Git Email:        ${GIT_EMAIL:-Not set}"
echo

if [ "$ENVIRONMENT_TYPE" = "production" ]; then
    echo "🚨 PRODUCTION DEPLOYMENT NOTES:"
    echo "- Ensure all security settings are properly configured"
    echo "- Verify SSL certificates are valid"
    echo "- Check backup procedures are in place"
    echo "- Monitor system resources after deployment"
fi

echo "Deployment script completed successfully!"