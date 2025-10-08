#!/usr/bin/env bash
# Generate a raw ANSI transcript of the interactive_config.sh run.
# Usage: ./generate_interactive_transcript.sh [--no-deploy]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
OUT_DIR="$SCRIPT_DIR/tests"
TMP_CAPTURE="/tmp/interactive_raw.$$"
OUT_RAW="$OUT_DIR/interactive_config_transcript"
OUT_ANSI="$OUT_DIR/interactive_config_transcript.ansi"

NO_DEPLOY_FLAG="--no-deploy"

CMD="(yes \"\" | head -n 400; printf 'n\n') | $SCRIPT_DIR/interactive_config.sh $NO_DEPLOY_FLAG"

echo "Generating interactive transcript..."
mkdir -p "$OUT_DIR"

# Use script to allocate a pty so colors/formatting are emitted
script -q -c "$CMD" "$TMP_CAPTURE"

# Strip the 'Script started on' header if present and any trailing 'Script done on' footer
if [ -f "$TMP_CAPTURE" ]; then
    # Remove first line (script header) and any trailing footer inserted by script
    sed '1d' "$TMP_CAPTURE" | sed '/^Script done on/,$d' > "$OUT_RAW"
    # Also provide an .ansi copy for convenience
    cp "$OUT_RAW" "$OUT_ANSI"
    echo "Wrote raw transcript: $OUT_RAW"
    echo "Also wrote ANSI copy: $OUT_ANSI"
    # Clean up
    rm -f "$TMP_CAPTURE"
else
    echo "Capture failed: $TMP_CAPTURE not found" >&2
    exit 2
fi

exit 0
