#!/bin/bash

# common.sh - shared helpers for installation scripts
# Location: scripts/installation_scripts/common/common.sh

set -euo pipefail

# detect compose command (docker-compose or "docker compose")
detect_compose_cmd() {
    if command -v docker-compose >/dev/null 2>&1; then
        printf "%s" "docker-compose"
    elif docker compose version >/dev/null 2>&1; then
        printf "%s" "docker compose"
    else
        return 1
    fi
}

# get list of services from compose (one per line)
# usage: get_compose_services /path/to/project
get_compose_services() {
    local proj_root="${1:-.}"
    local compose_cmd
    compose_cmd=$(detect_compose_cmd) || return 1
    (cd "$proj_root" && $compose_cmd -f docker-compose.yml -f docker-compose.override.yml config --services 2>/dev/null || true)
}

# returns success if service has a local Dockerfile under ./<service>/Dockerfile
service_has_local_dockerfile() {
    local svc="$1"
    if [ -d "$svc" ] && [ -f "$svc/Dockerfile" ]; then
        return 0
    fi
    return 1
}

# returns success if compose service config contains a 'build:' key
service_has_compose_build() {
    local proj_root="${1:-.}"; shift
    local svc="$1"
    local compose_cmd
    compose_cmd=$(detect_compose_cmd) || return 1
    local svc_cfg
    svc_cfg=$(cd "$proj_root" && $compose_cmd -f docker-compose.yml -f docker-compose.override.yml config --service "$svc" 2>/dev/null || true)
    printf "%s" "$svc_cfg" | grep -q "^[[:space:]]*build:"
}

# decide action: prints "build|reason" or "pull|reason"
decide_service_action() {
    local proj_root="${1:-.}"; shift
    local svc="$1"

    if service_has_local_dockerfile "$svc"; then
        printf "build|local Dockerfile: %s" "$svc"
        return 0
    fi

    if service_has_compose_build "$proj_root" "$svc"; then
        printf "build|compose 'build:' key present"
        return 0
    fi

    printf "pull|remote image (no local build)"
    return 0
}

# -----------------------------------------------------------------------------
# Color / UI helpers (moved here from top-level common.sh)
# These are exported so any script that sources this file gets consistent
# coloring and helper functions (warn, caution, note, section, format_default)
# -----------------------------------------------------------------------------

# Color helpers (ANSI escapes)
RED=$'\e[31m'
# Bronze-ish color using 256-color escape (brown/bronze tone)
BRONZE=$'\e[38;5;136m'
# Keep YELLOW reserved for warnings
YELLOW=$'\e[33m'
RESET=$'\e[0m'
GREEN=$'\e[32m'
DIM=$'\e[2m'
# SUBDUED is a dimmed bronze for body text under headings
SUBDUED="${DIM}${BRONZE}"

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
    # Two leading blank lines before a top-level section
    printf "\n\n"
    # Usage: section "Title" ["optional multi-line body"]
    local title="$1"
    local body="${2-}"
    local underline
    # Compute max width between title and any body lines so all decorations
    # share the same width.
    local IFS=$'\n'
    local maxw=${#title}
    if [ -n "$body" ]; then
        for line in $body; do
            local l=${#line}
            if [ "$l" -gt "$maxw" ]; then
                maxw=$l
            fi
        done
    fi

    # Cap the computed width to the terminal width to avoid generating
    # extremely long decoration lines that can make the UI appear hung.
    local term_w=80
    if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
        local tw
        tw=$(tput cols 2>/dev/null || echo 0)
        if [ "$tw" -gt 0 ]; then
            term_w=$tw
        fi
    elif [ -n "${COLUMNS:-}" ] && [ "${COLUMNS:-0}" -gt 0 ]; then
        term_w=${COLUMNS}
    fi
    if [ "$maxw" -gt "$term_w" ]; then
        maxw=$term_w
    fi

    # Top '=' rule
    local rule
    rule=$(printf '%*s' "$maxw" '' | tr ' ' '=')
    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%b\n" "${BRONZE}${rule}${RESET}"
    else
        printf "%s\n" "$rule"
    fi

    # Title and underline (same width)
    echo -e "${BRONZE}${title}${RESET}"
    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%b\n" "${BRONZE}${rule}${RESET}"
    else
        printf "%s\n" "$rule"
    fi

    if [ -n "$body" ]; then
        # Subdued color: use BRONZE but dim by reducing brightness if terminal
        # doesn't support dim, fallback to RESET. We'll box the body with a
        # bottom underscore line matching width.
        # Print body lines and compute max width
        local IFS=$'\n'
        local maxw=0
        for line in $body; do
            # Print the body in a less prominent color (use SUBDUED)
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b
" "${SUBDUED}${line}${RESET}"
            else
                printf "%s
" "${line}"
            fi
            local l=${#line}
            if [ "$l" -gt "$maxw" ]; then
                maxw=$l
            fi
        done
        # Print bottom underscore box in BRONZE
        if [ "$maxw" -gt 0 ]; then
            local underscore
            underscore=$(printf '%*s' "$maxw" '' | tr ' ' '_')
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${underscore}${RESET}"
            else
                printf '%s\n' "$underscore"
            fi
        fi
    fi
}

# Print a stronger top-level section (supersection) with bolder decoration.
# This is visually distinct from `section()`: it uses an emphasized title color
# and extra spacing so callers can mark a super-container (e.g. "Interactive
# Configuration").
supersection() {
    # Usage: supersection "Title" ["optional multi-line body"]
    local title="$1"
    local body="${2-}"
    local IFS=$'\n'
    local maxw=${#title}
    if [ -n "$body" ]; then
        for line in $body; do
            local l=${#line}
            if [ "$l" -gt "$maxw" ]; then
                maxw=$l
            fi
        done
    fi

    # Determine terminal width cap
    local term_w=80
    if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
        local tw
        tw=$(tput cols 2>/dev/null || echo 0)
        if [ "$tw" -gt 0 ]; then
            term_w=$tw
        fi
    elif [ -n "${COLUMNS:-}" ] && [ "${COLUMNS:-0}" -gt 0 ]; then
        term_w=${COLUMNS}
    fi
    if [ "$maxw" -gt "$term_w" ]; then
        maxw=$term_w
    fi

    # Determine terminal width so the supersection uses the full width
    local term_w=80
    if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
        local tw
        tw=$(tput cols 2>/dev/null || echo 0)
        if [ "$tw" -gt 0 ]; then
            term_w=$tw
        fi
    elif [ -n "${COLUMNS:-}" ] && [ "${COLUMNS:-0}" -gt 0 ]; then
        term_w=${COLUMNS}
    fi

    # Top rule: full terminal width using '#' for stronger emphasis
    local rule
    rule=$(printf '%*s' "$term_w" '' | tr ' ' '#')

    # Leading blank lines to make the supersection stand out
    printf "\n\n\n"

    # Print rule, title (in YELLOW to emphasize), and rule again
    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%b\n" "${BRONZE}${rule}${RESET}"
        printf "%b\n" "${YELLOW}${title}${RESET}"
        printf "%b\n" "${BRONZE}${rule}${RESET}"
    else
        printf "%s\n" "$rule"
        printf "%s\n" "$title"
        printf "%s\n" "$rule"
    fi

    if [ -n "$body" ]; then
        local maxb=0
        for line in $body; do
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${SUBDUED}${line}${RESET}"
            else
                printf "%s\n" "$line"
            fi
            local l=${#line}
            if [ "$l" -gt "$maxb" ]; then
                maxb=$l
            fi
        done
        if [ "$maxb" -gt 0 ]; then
            local foot
            foot=$(printf '%*s' "$maxb" '' | tr ' ' '_')
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${foot}${RESET}"
            else
                printf '%s\n' "$foot"
            fi
        fi
    fi
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
