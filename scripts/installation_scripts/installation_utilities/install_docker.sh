#!/bin/bash

# Docker Installation Dispatcher Script
# This script reads the OS family from configuration and calls the appropriate install script

set -e  # Exit on any error

echo "=========================================="
echo "Docker Installation Dispatcher"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../interactive_config.cfg"

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please run the interactive deployment script first:"
    echo "  ./scripts/installation_scripts/interactive_config.sh"
    exit 1
fi

echo "Loading configuration from $CONFIG_FILE..."
source "$CONFIG_FILE"

# Check if OS_FAMILY is set
if [ -z "$OS_FAMILY" ]; then
    echo "Error: OS_FAMILY not found in configuration file"
    echo "Please run the interactive deployment script to configure your OS family:"
    echo "  ./scripts/installation_scripts/interactive_config.sh"
    exit 1
fi

echo "Detected OS family: $OS_FAMILY"

# Check if OS-specific Docker installation script exists
DOCKER_INSTALL_SCRIPT="$SCRIPT_DIR/${OS_FAMILY}_install/install_docker.$OS_FAMILY.sh"
if [ ! -f "$DOCKER_INSTALL_SCRIPT" ]; then
    echo "Error: Docker installation script not found: $DOCKER_INSTALL_SCRIPT"
    echo "Please ensure the OS-specific install_docker.$OS_FAMILY.sh script exists"
    echo "Supported OS families: debian, redhat, suse, arch, slackware"
    exit 1
fi

echo "Found Docker installation script for $OS_FAMILY"
echo "Executing: $DOCKER_INSTALL_SCRIPT"
echo

# Execute the OS-specific Docker installation script
"$DOCKER_INSTALL_SCRIPT"

echo
echo "Docker installation dispatcher completed successfully!"
