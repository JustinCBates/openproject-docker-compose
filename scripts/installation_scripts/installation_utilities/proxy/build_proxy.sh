#!/bin/bash

# build_proxy.sh - Build the proxy image locally
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
COMPOSE_CMD="docker compose"

echo "=========================================="
echo "Proxy Build Utility"
echo "=========================================="

cd "$PROJECT_ROOT"

# Use docker compose to build the proxy service, if it exists
if [ -f "$PROJECT_ROOT/docker-compose.yml" ]; then
    # Check if proxy service is defined and has a build context
    if docker compose -f docker-compose.yml -f docker-compose.override.yml config --services | grep -q "^proxy$" 2>/dev/null; then
        echo "Building proxy image locally..."
        $COMPOSE_CMD -f docker-compose.yml -f docker-compose.override.yml build proxy
        echo "✓ Proxy image built"
    else
        echo "✓ No proxy service defined in compose files; skipping proxy build"
    fi
else
    echo "❌ docker-compose.yml not found; cannot build proxy"
    exit 1
fi

exit 0
