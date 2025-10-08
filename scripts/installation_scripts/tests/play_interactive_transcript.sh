#!/usr/bin/env bash
# Play back a saved ANSI transcript to the terminal.
# If `pv` is available, it can optionally throttle the output to better
# reproduce the timing of the original session. Otherwise this falls back to `cat`.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANSCRIPT_DEFAULT="$SCRIPT_DIR/interactive_config_transcript.ansi"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [TRANSCRIPT_FILE]

Play a saved ANSI transcript back to the terminal. By default this plays
the recorded transcript at:
  $TRANSCRIPT_DEFAULT

Options:
  -s SPEED    Playback speed multiplier (e.g. 0.5 for half-speed, 2 for double)
  -h, --help  Show this help message

If "pv" is installed it will be used to throttle output. When not present
the script will use "cat" and output as fast as possible.
EOF
}

SPEED=1
FILE=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        -s)
            shift
            SPEED="$1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            FILE="$1"
            shift
            ;;
    esac
done

if [ -z "$FILE" ]; then
    FILE="$TRANSCRIPT_DEFAULT"
fi

if [ ! -f "$FILE" ]; then
    echo "Error: transcript file not found: $FILE" >&2
    exit 2
fi

# Decide on playback command: pv (if available) or cat
if command -v pv >/dev/null 2>&1; then
    filesize=$(wc -c <"$FILE" 2>/dev/null || echo 0)
    if [ "$filesize" -le 0 ]; then
        pv -q <"$FILE"
    else
        # baseline duration 10s -> baseline_rate bytes/sec
        baseline_rate=$(( filesizE / 10 + 1 )) 2>/dev/null || baseline_rate=0
        # If baseline_rate is zero, just stream with pv quietly
        if [ "$baseline_rate" -le 0 ]; then
            pv -q <"$FILE"
        else
            # Compute rate as baseline_rate * SPEED using awk for float support
            rate=$(awk -v r="$baseline_rate" -v s="$SPEED" 'BEGIN{printf "%d", r*s}')
            if [ "$rate" -le 0 ]; then
                pv -q <"$FILE"
            else
                pv -q -L "$rate" <"$FILE"
            fi
        fi
    fi
else
    # No pv: if SPEED >= 1 then fast playback via cat; if SPEED < 1 insert sleeps
    # Use awk to check numeric comparison
    if awk -v s="$SPEED" 'BEGIN{ if (s+0 >= 1) exit 0; else exit 1 }'; then
        cat "$FILE"
    else
        inv_speed=$(awk -v s="$SPEED" 'BEGIN{printf "%f", 1.0/s}')
        while IFS= read -r line || [ -n "$line" ]; do
            printf '%s\n' "$line"
            sleep "$inv_speed"
        done <"$FILE"
    fi
fi

exit 0
