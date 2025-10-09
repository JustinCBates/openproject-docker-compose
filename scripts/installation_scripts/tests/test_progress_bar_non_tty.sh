#!/bin/bash
# CI-friendly test: run progress bar test in a non-TTY (redirected stdout)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_SCRIPT="$SCRIPT_DIR/test_progress_bar.sh"
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
OUT="$LOG_DIR/test_progress_bar_non_tty.ansi"

if [ ! -f "$TEST_SCRIPT" ]; then
    echo "Missing test script: $TEST_SCRIPT" >&2
    exit 2
fi

# Run the test but force non-tty by redirecting stdout to a file
# This ensures the progress bar fallback (plain lines/dots) is exercised.
bash "$TEST_SCRIPT" > "$OUT" 2>&1

echo "Wrote $OUT"
exit 0
