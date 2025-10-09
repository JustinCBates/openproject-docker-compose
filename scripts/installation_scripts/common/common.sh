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

# init_install_defaults - populate common 'current_*' variables from
# the deployment config file and sensible fallbacks. Callers should
# source this file and then call init_install_defaults to prepare a
# consistent environment for modular configure scripts.
get_cfg() {
    local key="$1"
    DEPLOY_CONFIG="${DEPLOY_CONFIG:-$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../interactive_config.cfg}"
    grep -E "^${key}=" "$DEPLOY_CONFIG" 2>/dev/null | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' || true
}

init_install_defaults() {
    # Ensure DEPLOY_CONFIG is set by caller; default to interactive_config.cfg
    DEPLOY_CONFIG="${DEPLOY_CONFIG:-$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../interactive_config.cfg}"

    # Populate commonly-used current_* variables with values from config
    current_host=$(get_cfg "OPENPROJECT_HOST_NAME")
    current_https=$(get_cfg "OPENPROJECT_HTTPS")
    current_tag=$(get_cfg "OPENPROJECT_TAG")
    current_db_password=$(get_cfg "DEFAULT_DBADMIN_PASSWORD")
    current_db_storage=$(get_cfg "DATABASE_STORAGE_TYPE")
    current_git_user_cfg=$(get_cfg "GIT_USERNAME")
    current_git_email_cfg=$(get_cfg "GIT_EMAIL")
    current_domain=$(get_cfg "DOMAIN_NAME")
    current_subdomain=$(get_cfg "SUBDOMAIN")
    current_env_type=$(get_cfg "ENVIRONMENT_TYPE")
    current_os_family_raw=$(get_cfg "OS_FAMILY")
    current_relative_root=$(get_cfg "OPENPROJECT_RAILS__RELATIVE__URL__ROOT")

    # Sensible defaults
    if [ -z "$current_https" ]; then current_https="false"; fi
    if [ -z "$current_tag" ]; then current_tag="16"; fi
    if [ -z "$current_db_storage" ]; then current_db_storage="docker-volumes"; fi
    if [ -z "$current_env_type" ]; then current_env_type="localdev"; fi

    if [ -z "$current_host" ]; then
        detected_hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
        current_host="$detected_hostname"
    fi

    # Git defaults: prefer config file values, then global git config, then system user
    if [ -n "$current_git_user_cfg" ]; then
        current_git_user="$current_git_user_cfg"
    else
        current_git_user="$(git config --global user.name 2>/dev/null || echo "")"
    fi
    if [ -n "$current_git_email_cfg" ]; then
        current_git_email="$current_git_email_cfg"
    else
        current_git_email="$(git config --global user.email 2>/dev/null || echo "")"
    fi

    if [ -z "$current_git_user" ]; then
        current_git_user="$(whoami)"
    fi
    if [ -z "$current_git_email" ]; then
        current_git_email="$(whoami)@$(hostname -f)"
    fi

    export DEPLOY_CONFIG
}
