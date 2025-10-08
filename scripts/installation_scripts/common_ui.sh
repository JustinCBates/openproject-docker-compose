#!/bin/bash

# UI helpers for installation scripts (colors, warnings, and formatting)
# Location: scripts/installation_scripts/common_ui.sh

# Color helpers (ANSI escapes)
RED=$'\e[31m'
# Bronze-ish color using 256-color escape (brown/bronze tone)
BRONZE=$'\e[38;5;136m'
# Keep YELLOW reserved for warnings/cautions
YELLOW=$'\e[33m'
RESET=$'\e[0m'
GREEN=$'\e[32m'

# Determine whether colors should be enabled. This allows forcing colors
# by setting INSTALLER_FORCE_COLOR=1 in the environment (useful in some
# terminal wrappers), otherwise only enable when stdout is a TTY.
COLOR_ENABLED=0
# First, honor explicit forcing
if [ "${INSTALLER_FORCE_COLOR:-}" = "1" ]; then
    COLOR_ENABLED=1
fi

# Detect color support when not explicitly forced
if [ "$COLOR_ENABLED" -ne 1 ]; then
    if [ -t 1 ]; then
        # Prefer tput if available
        if command -v tput >/dev/null 2>&1; then
            ncolors=$(tput colors 2>/dev/null || echo 0)
            case "$ncolors" in
                ''|0) COLOR_SUPPORTED=0; COLOR_LEVEL=0 ;;
                [1-9]|1[0-5]) COLOR_SUPPORTED=1; COLOR_LEVEL=8 ;;
                16) COLOR_SUPPORTED=1; COLOR_LEVEL=16 ;;
                *) COLOR_SUPPORTED=1; COLOR_LEVEL=256 ;;
            esac
        else
            # Fallback to TERM heuristics
            if [ -n "${TERM:-}" ] && (echo "$TERM" | grep -Eiq 'color|ansi|xterm|screen|vt100'); then
                COLOR_SUPPORTED=1
                COLOR_LEVEL=8
            else
                COLOR_SUPPORTED=0
                COLOR_LEVEL=0
            fi
        fi
    else
        COLOR_SUPPORTED=0
        COLOR_LEVEL=0
    fi
    # Enable colors only if supported
    if [ "${COLOR_SUPPORTED:-0}" -eq 1 ]; then
        COLOR_ENABLED=1
    else
        COLOR_ENABLED=0
    fi
fi

# Export these so sourced scripts can inspect capabilities
export COLOR_ENABLED COLOR_SUPPORTED COLOR_LEVEL

# Print a red warning prefix followed by message
warn() {
    local msg="$*"
    # Use -e so color escapes are interpreted
    echo -e "${RED}⚠ WARNING:${RESET} ${msg}"
}

# Print a caution message in yellow (less severe than warn)
caution() {
    local msg="$*"
    echo -e "${YELLOW}⚠ Caution:${RESET} ${msg}"
}

# Print a non-fatal notice in bronze
note() {
    local msg="$*"
    echo -e "${BRONZE}NOTE:${RESET} ${msg}"
}

# Print a section heading (title + underline) in bronze
section() {
    local title="$*"
    local underline
    underline=$(printf '%*s' "${#title}" '' | tr ' ' '=')
    echo -e "${BRONZE}${title}${RESET}"
    echo -e "${BRONZE}${underline}${RESET}"
}

# Return a colored default value when stdout is a TTY
format_default() {
    local val="$1"
    if [ "${COLOR_ENABLED:-0}" = "1" ]; then
        printf "%b" "${GREEN}${val}${RESET}"
    else
        printf "%s" "$val"
    fi
}
