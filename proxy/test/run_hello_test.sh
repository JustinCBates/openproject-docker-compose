#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# repo root is two levels up from proxy/test -> /opt/openproject
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/proxy/docker-compose.test.yml"

cmd=${1:-up}

case "$cmd" in
  up)
    echo "Building and starting hello test container..."
    docker compose -f "$COMPOSE_FILE" build --pull --no-cache
    docker compose -f "$COMPOSE_FILE" up -d
    echo "Started. To test via proxy, configure your proxy to reverse_proxy to 'hello:8080' or curl http://localhost:8081"
    ;;
  down)
    echo "Stopping test container..."
    docker compose -f "$COMPOSE_FILE" down
    ;;
  clean)
    echo "Removing test container and volume..."
    docker compose -f "$COMPOSE_FILE" down -v --rmi local || true
    ;;
  *)
    echo "Usage: $0 {up|down|clean}"
    exit 2
    ;;
esac
