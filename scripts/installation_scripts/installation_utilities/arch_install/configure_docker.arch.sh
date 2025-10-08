#!/bin/bash

# configure_docker.arch.sh - Arch Linux-specific Docker Configuration
# Part of the OpenProject deployment framework

echo "=========================================="
echo "Arch Linux Docker Configuration (STUB)"
echo "=========================================="

echo "⚠ Arch Linux implementation is not yet complete"
echo "This is a stub implementation for future development"
echo ""
echo "Planned Arch Linux optimizations:"
echo "  - Pacman package manager optimizations"
echo "  - AUR package support"
echo "  - systemd-specific configurations"
echo "  - Arch-specific kernel parameters"
echo ""
echo "For now, using basic configuration..."

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Update .env file with basic configuration from interactive_config.cfg
env_file="$PROJECT_ROOT/.env"
if [ -f "$env_file" ]; then
    # Update basic settings if they exist in config
    if [ -n "$OPENPROJECT_HOST_NAME" ]; then
        sed -i "s/^OPENPROJECT_HOST__NAME=.*/OPENPROJECT_HOST__NAME=$OPENPROJECT_HOST_NAME/" "$env_file"
    fi
    if [ -n "$OPENPROJECT_HTTPS" ]; then
        sed -i "s/^OPENPROJECT_HTTPS=.*/OPENPROJECT_HTTPS=$OPENPROJECT_HTTPS/" "$env_file"
    fi
    if [ -n "$OPENPROJECT_TAG" ]; then
        sed -i "s/^TAG=.*/TAG=$OPENPROJECT_TAG/" "$env_file"
    fi
    if [ -n "$DEFAULT_ADMIN_PASSWORD" ]; then
        if grep -q "^OPENPROJECT_ADMIN_PASSWORD=" "$env_file"; then
            sed -i "s/^OPENPROJECT_ADMIN_PASSWORD=.*/OPENPROJECT_ADMIN_PASSWORD=$DEFAULT_ADMIN_PASSWORD/" "$env_file"
        else
            echo "OPENPROJECT_ADMIN_PASSWORD=$DEFAULT_ADMIN_PASSWORD" >> "$env_file"
        fi
    fi
fi

# Add basic Arch variables to .env
{
    echo ""
    echo "# Arch Linux-specific Docker configuration (STUB)"
    echo "DOCKER_BUILDKIT=1"
    echo "COMPOSE_DOCKER_CLI_BUILD=1"
} >> "$PROJECT_ROOT/.env"

# Create minimal override file
cat > "$PROJECT_ROOT/docker-compose.override.yml" << 'EOF'
# docker-compose.override.yml - Arch Linux optimizations (STUB)
version: '3.8'

services:
  web:
    environment:
      - ARCH_STUB=true
EOF

echo "✓ Basic Arch Linux configuration completed (stub implementation)"
echo "🔧 Full Arch Linux support coming soon!"