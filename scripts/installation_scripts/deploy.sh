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
UTILITIES_DIR="$SCRIPT_DIR/utilities"
CONFIG_FILE="$SCRIPT_DIR/deploy_interactive.cfg"

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please run the interactive deployment script first:"
    echo "  ./scripts/deploy_interactive.sh"
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
if [ -f "$UTILITIES_DIR/git_user.sh" ]; then
    "$UTILITIES_DIR/git_user.sh"
    echo "✓ Git user configuration completed"
else
    echo "⚠ Warning: git_user.sh not found, skipping"
fi
echo

echo "Step 2: Installing Docker..."
echo "============================"
if [ -n "$OS_FAMILY" ] && [ -f "$UTILITIES_DIR/$OS_FAMILY/install_docker.sh" ]; then
    echo "Installing Docker for $OS_FAMILY family..."
    "$UTILITIES_DIR/$OS_FAMILY/install_docker.sh"
    echo "✓ Docker installation completed"
else
    if [ -z "$OS_FAMILY" ]; then
        echo "⚠ Warning: OS_FAMILY not set in configuration, skipping Docker installation"
    else
        echo "⚠ Warning: install_docker.sh for $OS_FAMILY not found, skipping"
    fi
fi
echo

# TODO: Add more utility scripts as they are created
# echo "Step 2: Validating Environment..."
# echo "================================="
# if [ -f "$UTILITIES_DIR/01-validate-environment.sh" ]; then
#     "$UTILITIES_DIR/01-validate-environment.sh"
#     echo "✓ Environment validation completed"
# else
#     echo "⚠ Warning: 01-validate-environment.sh not found, skipping"
# fi
# echo

# echo "Step 3: Setting up Directories..."
# echo "================================="
# if [ -f "$UTILITIES_DIR/02-setup-directories.sh" ]; then
#     "$UTILITIES_DIR/02-setup-directories.sh"
#     echo "✓ Directory setup completed"
# else
#     echo "⚠ Warning: 02-setup-directories.sh not found, skipping"
# fi
# echo

# echo "Step 4: Configuring Docker Compose..."
# echo "====================================="
# if [ -f "$UTILITIES_DIR/03-configure-docker-compose.sh" ]; then
#     "$UTILITIES_DIR/03-configure-docker-compose.sh"
#     echo "✓ Docker Compose configuration completed"
# else
#     echo "⚠ Warning: 03-configure-docker-compose.sh not found, skipping"
# fi
# echo

# echo "Step 5: Setting up HTTPS..."
# echo "=========================="
# if [ -f "$UTILITIES_DIR/04-setup-https.sh" ]; then
#     "$UTILITIES_DIR/04-setup-https.sh"
#     echo "✓ HTTPS setup completed"
# else
#     echo "⚠ Warning: 04-setup-https.sh not found, skipping"
# fi
# echo

# echo "Step 6: Configuring Networking..."
# echo "================================="
# if [ -f "$UTILITIES_DIR/05-configure-networking.sh" ]; then
#     "$UTILITIES_DIR/05-configure-networking.sh"
#     echo "✓ Networking configuration completed"
# else
#     echo "⚠ Warning: 05-configure-networking.sh not found, skipping"
# fi
# echo

# echo "Step 7: Setting up SMTP..."
# echo "========================="
# if [ -f "$UTILITIES_DIR/06-setup-smtp.sh" ]; then
#     "$UTILITIES_DIR/06-setup-smtp.sh"
#     echo "✓ SMTP setup completed"
# else
#     echo "⚠ Warning: 06-setup-smtp.sh not found, skipping"
# fi
# echo

# echo "Step 8: Applying Configuration..."
# echo "================================="
# if [ -f "$UTILITIES_DIR/07-apply-configuration.sh" ]; then
#     "$UTILITIES_DIR/07-apply-configuration.sh"
#     echo "✓ Configuration applied"
# else
#     echo "⚠ Warning: 07-apply-configuration.sh not found, skipping"
# fi
# echo

# echo "Step 9: Health Check..."
# echo "======================"
# if [ -f "$UTILITIES_DIR/08-health-check.sh" ]; then
#     "$UTILITIES_DIR/08-health-check.sh"
#     echo "✓ Health check completed"
# else
#     echo "⚠ Warning: 08-health-check.sh not found, skipping"
# fi
# echo

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