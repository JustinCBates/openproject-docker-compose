#!/usr/bin/env bash
set -euo pipefail

# Simple smoke test for Caddyfile template rendering.
# This script sets test env variables, renders the template using gomplate,
# and validates it with `caddy adapt` inside the running proxy container.

# Export a minimal set of env vars for rendering
export OPENPROJECT_HOST_NAME="example.test"
export RAILS_RELATIVE_URL_ROOT="/testroot"

# Use the renderer
if [ ! -x ./scripts/deploy/render_caddy.sh ]; then
  echo "render_caddy.sh not found or not executable" >&2
  exit 2
fi

# Run renderer (it will run gomplate and caddy adapt inside container)
./scripts/deploy/render_caddy.sh

echo "Smoke render test completed successfully."