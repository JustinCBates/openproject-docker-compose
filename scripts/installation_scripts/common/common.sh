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

# Note: color and UI helpers (warn, caution, note, format_default and
# color variable detection) have been moved to `common_ui.sh` so all UI
# rendering helpers live together. See
# `scripts/installation_scripts/common/common_ui.sh` for their
# implementations.
