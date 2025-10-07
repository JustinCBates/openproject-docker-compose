#!/bin/bash

# configure_docker.suse.sh - openSUSE-specific Docker Configuration
# Part of the OpenProject deployment framework

echo "=========================================="
echo "openSUSE Docker Configuration (STUB)"
echo "=========================================="

echo "⚠ openSUSE/SUSE implementation is not yet complete"
echo "This is a stub implementation for future development"
echo ""
echo "Planned openSUSE family optimizations:"
echo "  - Zypper package manager optimizations"
echo "  - openSUSE Build Service integration"
echo "  - SuSEfirewall2/firewalld configurations"
echo "  - SUSE-specific systemd configurations"
echo ""
echo "For now, using basic configuration..."

# Basic stub - just create minimal .env additions and override file
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

# Add basic SUSE variables to .env
{
    echo ""
    echo "# openSUSE-specific Docker configuration (STUB)"
    echo "DOCKER_BUILDKIT=1"
    echo "COMPOSE_DOCKER_CLI_BUILD=1"
} >> "$PROJECT_ROOT/.env"

# Create minimal override file
cat > "$PROJECT_ROOT/docker-compose.override.yml" << 'EOF'
# docker-compose.override.yml - openSUSE optimizations (STUB)
version: '3.8'

services:
  web:
    environment:
      - SUSE_STUB=true
EOF

echo "✓ Basic openSUSE configuration completed (stub implementation)"
echo "🔧 Full openSUSE family support coming soon!"