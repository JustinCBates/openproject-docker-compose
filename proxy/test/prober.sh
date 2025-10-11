#!/usr/bin/env bash
set -euo pipefail

# prober.sh - interactive wrapper for run_integration_test.sh
# Provides a small menu to run the integration probe with options:
#  - default (bind to PROXY_HOST_PORT)
#  - pick a free host port
#  - run without host binding (--no-bind)
#  - teardown/clean

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$BASE_DIR/run_integration_test.sh"

if [ ! -x "$RUNNER" ]; then
    echo "Integration runner not found or not executable: $RUNNER" >&2
    exit 2
fi

# Simple prompt helper (no external dependencies)
prompt_yesno() {
    local prompt="$1"
    local default="$2"
    local ans
    while true; do
        printf "%s [%s]: " "$prompt" "$default"
        read -r ans
        if [ -z "$ans" ]; then ans="$default"; fi
        case "$ans" in
            y|Y|yes) return 0 ;;
            n|N|no) return 1 ;;
            *) echo "Please answer 'y' or 'n'" ;;
        esac
    done
}

cat <<EOF
Integration Prober
------------------
This helper runs a small proxy+hello stack to validate proxy settings.
Options:
  1) Run with current PROXY_HOST_PORT (bind)
  2) Auto-pick a free host port
  3) Run without host port binding (in-network only)
  4) Teardown last run (down)
  5) Clean (down -v and remove temp files)
  0) Abort
EOF

printf "Select an option [0]: "
read -r opt
case "$opt" in
    1)
        printf "Enter host port to bind (default 18082): "
        read -r port
        if [ -z "$port" ]; then port=18082; fi
        PROXY_HOST_PORT=$port "$RUNNER" --force up
        ;;
    2)
        "$RUNNER" --force --pick-port up
        ;;
    3)
        printf "Run without host binding. Continue? "
        if prompt_yesno "Run without host binding" "n"; then
            "$RUNNER" --force --no-bind up
        else
            echo "Aborted by user"
        fi
        ;;
    4)
        "$RUNNER" down || true
        ;;
    5)
        "$RUNNER" clean || true
        ;;
    0|"")
        echo "Cancelled"
        ;;
    *)
        echo "Unknown option"
        ;;
esac
