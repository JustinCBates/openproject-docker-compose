#!/bin/bash
# Simple test harness for progress_bar helpers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source the UI helpers (adjust path to common_ui.sh)
COMMON_UI="$ROOT_DIR/common/common_ui.sh"
if [ ! -f "$COMMON_UI" ]; then
    echo "Missing common_ui.sh: $COMMON_UI" >&2
    exit 2
fi
# shellcheck source=/dev/null
source "$COMMON_UI"

LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
OUT="$LOG_DIR/test_progress_bar.ansi"

# Run tests in a subshell so we can capture output easily
(
    echo "=== progress_bar known-width test ==="
    # Known-width: 10 ticks, width 20, 0.2s interval for quick test
    progress_bar_init "Known-width test" 10 20
    for i in $(seq 1 10); do
        sleep 0.2
        progress_bar_tick
    done
    progress_bar_finish "Known-width complete"

    echo ""
    echo "=== progress_bar indeterminate test ==="
    progress_bar_init "Indeterminate test"
    for i in $(seq 1 8); do
        sleep 0.15
        progress_bar_tick
    done
    progress_bar_finish "Indeterminate complete"
) | tee "$OUT"

# Print location of captured output
echo "Wrote $OUT"

exit 0
