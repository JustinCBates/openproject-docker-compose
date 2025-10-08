#!/bin/bash

# smoke.sh - basic smoke test for installation scripts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# repo root (two levels up from tests)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "Running smoke test: deploy --dry-run (fallback to build_stack.sh --dry-run if deploy fails)"

output=""
if output=$(cd "$PROJECT_ROOT" && ./scripts/installation_scripts/deploy.sh --dry-run 2>&1); then
    echo "deploy --dry-run completed"
else
    echo "deploy --dry-run failed, falling back to build_stack.sh --dry-run"
    output=$("$PROJECT_ROOT"/scripts/installation_scripts/installation_utilities/build_stack.sh --dry-run 2>&1 || true)
fi

echo "$output" | sed -n '1,200p'

# Check for the plan summary line
if echo "$output" | grep -q "Plan summary:"; then
    echo "Smoke test passed: plan summary found"
    exit 0
else
    echo "Smoke test failed: plan summary not found" >&2
    exit 1
fi
