#!/bin/bash

# build_stack.suse.sh - openSUSE-specific OpenProject Stack Builder
# Part of the OpenProject deployment framework

echo "=========================================="
echo "openSUSE Stack Builder (STUB)"
echo "=========================================="

echo "⚠ openSUSE/SUSE implementation is not yet complete"
echo "This is a stub implementation for future development"
echo ""
echo "Planned openSUSE family optimizations:"
echo "  - Zypper-optimized Docker builds"
echo "  - openSUSE Build Service integration"
echo "  - SuSEfirewall2/firewalld configurations"
echo "  - SUSE-specific performance tuning"
echo ""
echo "For now, using basic Docker Compose build..."

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$PROJECT_ROOT"

# Basic Docker Compose build using override file created by configure_docker.suse.sh
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose not found"
    exit 1
fi

echo "Starting basic OpenProject stack..."
$COMPOSE_CMD -f docker-compose.yml -f docker-compose.override.yml up -d

echo "✓ Basic openSUSE stack deployment completed (stub implementation)"
echo "🔧 Full openSUSE family optimizations coming soon!"
echo ""
echo "Stack status:"
$COMPOSE_CMD ps
