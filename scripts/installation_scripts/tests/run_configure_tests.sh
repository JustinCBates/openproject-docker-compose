#!/usr/bin/env bash
# Run each configure_scripts/xx_*.sh in isolation and capture their outputs.
# This script uses a temporary DEPLOY_CONFIG and HOME so it doesn't modify the
# user's real configuration or global git settings.

set -eu
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURE_DIR="$ROOT_DIR/configure_scripts"
TEST_DIR="$ROOT_DIR/tests"
COMMON_UI="$ROOT_DIR/common/common_ui.sh"
COMMON_SH="$ROOT_DIR/common/common.sh"

mkdir -p "$TEST_DIR/logs"
mkdir -p "$TEST_DIR/tmp_home"
# Use a test config so real interactive_config.cfg is not modified
TEST_DEPLOY_CONFIG="$TEST_DIR/interactive_config_test.cfg"
: > "$TEST_DEPLOY_CONFIG"

echo "Using test DEPLOY_CONFIG: $TEST_DEPLOY_CONFIG"

i=0
for s in "$CONFIGURE_DIR"/*.sh; do
    i=$((i+1))
    base=$(basename "$s")
    # Discover run_ function name (first occurrence)
    fn=$(grep -m1 -Eo '^run_[A-Za-z0-9_]+' "$s" || true)
    if [ -z "$fn" ]; then
        echo "Skipping $base (no run_ function found)"
        continue
    fi

    log="$TEST_DIR/logs/${i}_${base%.sh}.ansi"
    echo "--- Running $base -> $fn (log: $log) ---"

    # Run in a clean subshell with controlled HOME and DEPLOY_CONFIG.
    # Pipe blank answers (200 lines) to accept defaults.
    (
        export HOME="$TEST_DIR/tmp_home"
        export DEPLOY_CONFIG="$TEST_DEPLOY_CONFIG"
        # Ensure common helpers are available
        if [ -f "$COMMON_SH" ]; then
            source "$COMMON_SH"
        fi
        if [ -f "$COMMON_UI" ]; then
            source "$COMMON_UI"
        fi
        # Source the module and invoke its run_* function
        # We run under /bin/bash so sourced functions behave as in normal run
        source "$s"
        # run the function (read blanks from stdin)
        # NOTE: the outer pipeline provides stdin; here we just call the fn
        $fn
    ) < <(yes "" | head -n 200) > "$log" 2>&1 || true

    echo "Wrote $log"
done

echo "All done. Logs in: $TEST_DIR/logs"

