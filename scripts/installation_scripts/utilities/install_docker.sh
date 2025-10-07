#!/bin/bash

# Docker Installation Dispatcher Script
# This script reads the OS family from configuration and calls the appropriate install script

set -e  # Exit on any error

echo "=========================================="
echo "Docker Installation Dispatcher"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../deploy_interactive.cfg"
UTILITIES_DIR="$SCRIPT_DIR"

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file not found at $CONFIG_FILE"
    echo "Please run the interactive deployment script first:"
    echo "  ./scripts/deploy_interactive.sh"
    exit 1
fi

echo "Loading configuration from $CONFIG_FILE..."
source "$CONFIG_FILE"

# Validate OS_FAMILY variable
if [ -z "$OS_FAMILY" ]; then
    echo "Error: OS_FAMILY not found in configuration file"
    echo "Please run the interactive deployment script to configure your OS family:"
    echo "  ./scripts/deploy_interactive.sh"
    exit 1
fi

echo "Detected OS family: $OS_FAMILY"

# Check if OS-specific directory exists
OS_UTILITIES_DIR="$UTILITIES_DIR/$OS_FAMILY"
if [ ! -d "$OS_UTILITIES_DIR" ]; then
    echo "Error: OS-specific utilities directory not found: $OS_UTILITIES_DIR"
    echo "Supported OS families: debian, redhat, suse, arch, slackware"
    exit 1
fi

# Check if OS-specific Docker installation script exists
DOCKER_INSTALL_SCRIPT="$OS_UTILITIES_DIR/install_docker.$OS_FAMILY.sh"
if [ ! -f "$DOCKER_INSTALL_SCRIPT" ]; then
    echo "Error: Docker installation script not found: $DOCKER_INSTALL_SCRIPT"
    echo "Please ensure the OS-specific install_docker.$OS_FAMILY.sh script exists"
    exit 1
fi

# Check if script is executable
if [ ! -x "$DOCKER_INSTALL_SCRIPT" ]; then
    echo "Error: Docker installation script is not executable: $DOCKER_INSTALL_SCRIPT"
    echo "Making it executable..."
    chmod +x "$DOCKER_INSTALL_SCRIPT"
fi

echo
echo "Calling OS-specific Docker installation script..."
echo "Script: $DOCKER_INSTALL_SCRIPT"
echo "Environment: ${ENVIRONMENT_TYPE:-Not set}"
echo

# Execute the OS-specific Docker installation script
echo "=========================================="
"$DOCKER_INSTALL_SCRIPT"

# Check if Docker installation was successful
echo
echo "=========================================="
echo "Verifying Docker Installation"
echo "=========================================="

if command -v docker &> /dev/null; then
    echo "✓ Docker binary found: $(which docker)"
    echo "✓ Docker version: $(docker --version)"
    
    # Test Docker daemon connectivity
    if docker info > /dev/null 2>&1; then
        echo "✓ Docker daemon is running and accessible"
        
        # Test basic Docker functionality
        echo "Testing Docker with hello-world container..."
        if docker run --rm hello-world > /dev/null 2>&1; then
            echo "✓ Docker is working correctly!"
        else
            echo "⚠ Docker daemon is running but hello-world test failed"
            echo "This might be normal if internet access is limited"
        fi
    else
        echo "⚠ Docker daemon is not running or not accessible"
        echo "You may need to start Docker manually or check permissions"
    fi
else
    echo "✗ Docker binary not found in PATH"
    echo "Installation may have failed"
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    echo "✓ Docker Compose found: $(docker-compose --version)"
elif docker compose version &> /dev/null; then
    echo "✓ Docker Compose plugin found: $(docker compose version)"
else
    echo "⚠ Docker Compose not found"
    echo "Some functionality may be limited"
fi

echo
echo "=========================================="
echo "Docker Installation Summary"
echo "=========================================="
echo "OS Family: $OS_FAMILY"
echo "Environment: ${ENVIRONMENT_TYPE:-Not set}"
echo "Installation Script: $DOCKER_INSTALL_SCRIPT"
echo

if [ "$ENVIRONMENT_TYPE" = "production" ]; then
    echo "🚨 PRODUCTION DEPLOYMENT DETECTED"
    echo "Additional steps recommended:"
    echo "- Configure Docker daemon for production"
    echo "- Set up monitoring and logging"
    echo "- Configure resource limits"
    echo "- Review security settings"
    echo "- Set up backup procedures"
    echo
fi

echo "Next steps:"
echo "1. If you were added to the docker group, log out and back in"
echo "2. Continue with OpenProject deployment: ./scripts/deploy.sh"
echo "3. Or run the interactive deployment: ./scripts/deploy_interactive.sh"
echo

echo "Docker installation dispatcher completed successfully!"