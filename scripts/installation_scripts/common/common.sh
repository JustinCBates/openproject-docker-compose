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

    # Attempt to read defaults from the generated defaults file as a fallback.
    # Defaults file is expected next to this script's parent directory.
    local defaults_file
    defaults_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../interactive_config.cfg.defaults"

    # Helper to read a key from defaults file without sourcing (safe)
    read_default() {
        local key="$1"
        if [ -f "$defaults_file" ]; then
            grep -E "^${key}=" "$defaults_file" 2>/dev/null | head -1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' || true
        fi
    }

    # Helper: pick first non-empty value from (1) environment var, (2) config file, (3) defaults file
    get_effective() {
        local key="$1"
        local val=""
        # 1) environment variable with same name
        if [ -n "${!key:-}" ]; then
            printf "%s" "${!key}"
            return 0
        fi
        # 2) config file
        val=$(get_cfg "$key" 2>/dev/null || true)
        if [ -n "$val" ]; then
            printf "%s" "$val"
            return 0
        fi
        # 3) defaults file
        val=$(read_default "$key" 2>/dev/null || true)
        if [ -n "$val" ]; then
            printf "%s" "$val"
            return 0
        fi
        return 1
    }

    # Populate commonly-used current_* variables using get_effective where appropriate.
    current_host="$(get_effective "OPENPROJECT_HOST_NAME" || true)"
    current_https="$(get_effective "OPENPROJECT_HTTPS" || true)"
    current_tag="$(get_effective "OPENPROJECT_TAG" || true)"
    current_db_password="$(get_effective "DEFAULT_DBADMIN_PASSWORD" || true)"
    current_db_storage="$(get_effective "DATABASE_STORAGE_TYPE" || true)"
    current_git_user_cfg="$(get_effective "GIT_USERNAME" || true)"
    current_git_email_cfg="$(get_effective "GIT_EMAIL" || true)"
    current_domain="$(get_effective "DOMAIN_NAME" || true)"
    # Namespace / subdomain compatibility: prefer SUBDOMAIN then URI_NAMESPACE then legacy NAMESPACE
    current_subdomain="$(get_effective "SUBDOMAIN" || get_effective "URI_NAMESPACE" || get_effective "NAMESPACE" || true)"
    current_env_type="$(get_effective "ENVIRONMENT_TYPE" || true)"
    current_os_family_raw="$(get_effective "OS_FAMILY" || true)"
    current_relative_root="$(get_effective "RAILS_RELATIVE_URL_ROOT" || true)"

    # (detect_domain_name defined at top-level)

    # Sensible defaults
    if [ -z "$current_https" ]; then current_https="false"; fi
    if [ -z "$current_tag" ]; then current_tag="stable/16"; fi
    if [ -z "$current_db_storage" ]; then current_db_storage="docker-volumes"; fi
    if [ -z "$current_env_type" ]; then current_env_type="localdev"; fi

    if [ -z "$current_host" ]; then
        detected_hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
        current_host="$detected_hostname"
    fi

    # Populate current_domain using detection when config value is missing
    # or not a sensible FQDN (no dot). This avoids accepting short/partial
    # values like 'Statesmen' as a domain when a real hostname may be
    # discoverable.
    if [ -z "$current_domain" ] || ! printf "%s" "$current_domain" | grep -q '\.'; then
        detected_domain=$(detect_domain_name || true)
        if [ -n "$detected_domain" ]; then
            current_domain="$detected_domain"
        else
            # Fallback to system hostname if detection fails
            detected_hostname=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
            current_domain="$detected_hostname"
        fi
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

# Top-level helper: attempt to detect a sensible default domain name when not
# provided in the config. We prefer explicit config, then OPENPROJECT_HOST_NAME,
# then the system FQDN (hostname -f), then a conservative local HTTP probe.
detect_domain_name() {
    # 1) explicit config via env
    if [ -n "${OPENPROJECT_HOST_NAME:-}" ]; then
        echo "${OPENPROJECT_HOST_NAME}"
        return 0
    fi

    # 2) system FQDN
    local hn
    hn=$(hostname -f 2>/dev/null || true)
    if [ -n "$hn" ] && printf "%s" "$hn" | grep -q '\.'; then
        echo "$hn"
        return 0
    fi

    # 3) conservative local HTTP check: try common ports for redirects or Host headers
    for p in 80 8080 443; do
        if command -v curl >/dev/null 2>&1; then
            local hdrs
            hdrs=$(curl -sS --max-time 2 -I "http://127.0.0.1:$p" 2>/dev/null || true)
            if [ -n "$hdrs" ]; then
                local loc
                loc=$(printf "%s" "$hdrs" | grep -i '^Location:' | head -1 || true)
                if [ -n "$loc" ]; then
                    local hostpart
                    hostpart=$(printf "%s" "$loc" | sed -n 's#.*//\([^/:]*\).*#\1#p' || true)
                    if [ -n "$hostpart" ] && printf "%s" "$hostpart" | grep -q '\.'; then
                        echo "$hostpart"
                        return 0
                    fi
                fi
            fi
        fi
    done

    # No detection possible
    return 1
}


# Generate a defaults file used as fallbacks by interactive_config.sh.
# The file is written to the same directory as interactive_config.cfg and
# named interactive_config.cfg.defaults. It contains a small set of keys
# that the interactive script will source before loading user config.
generate_interactive_config_defaults() {
    # Optional first arg: base directory where interactive_config.cfg.defaults will be written
    local base_dir="${1-}"
    if [ -z "$base_dir" ]; then
        base_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/.."
    fi
    local defaults_file
    defaults_file="$base_dir/interactive_config.cfg.defaults"

    # Determine sensible defaults without relying on config file values
    local host
    host="${OPENPROJECT_HOST_NAME:-}"
    if [ -z "$host" ]; then
        host=$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo "localhost")
    fi

    # Defaults: enable HTTPS and redirect by default in generated defaults
    local https
    https="${OPENPROJECT_HTTPS:-}"
    if [ -z "$https" ]; then
        https="true"
    fi

    local tag
    tag="${OPENPROJECT_TAG:-}"
    if [ -z "$tag" ]; then
        tag="stable/16"
    fi

    local domain
    domain=$(detect_domain_name || true)
    if [ -z "$domain" ]; then
        domain="$host"
    fi
    # Attempt to detect global git user/email for inclusion in defaults
    local git_user git_email
    git_user="${GIT_USERNAME:-}"
    git_email="${GIT_EMAIL:-}"
    if [ -z "$git_user" ]; then
        git_user=$(git config --global user.name 2>/dev/null || true)
    fi
    if [ -z "$git_email" ]; then
        git_email=$(git config --global user.email 2>/dev/null || true)
    fi

    # Attempt to detect OS_FAMILY from /etc/os-release (map common IDs to known families)
    local os_family
    os_family="${OS_FAMILY:-}"
    if [ -z "$os_family" ] && [ -f /etc/os-release ]; then
        # Read ID and ID_LIKE (lowercase)
        local id id_like
        id=$(awk -F= '/^ID=/{print tolower($2)}' /etc/os-release 2>/dev/null | sed 's/"//g' || true)
        id_like=$(awk -F= '/^ID_LIKE=/{print tolower($2)}' /etc/os-release 2>/dev/null | sed 's/"//g' || true)
        # Simple mapping heuristics
        case "$id" in
            debian|ubuntu|pop) os_family="debian";;
            rhel|centos|fedora) os_family="redhat";;
            suse|opensuse) os_family="suse";;
            arch) os_family="arch";;
            slackware) os_family="slackware";;
        esac
        if [ -z "$os_family" ] && [ -n "$id_like" ]; then
            case "$id_like" in
                *debian*) os_family="debian";;
                *rhel*|*fedora*) os_family="redhat";;
                *suse*) os_family="suse";;
                *arch*) os_family="arch";;
            esac
        fi
    fi

    # Write defaults file (overwrite)
# Write defaults file (overwrite)
    # Compute defaults. We intentionally do NOT emit a combined DOMAIN/namespace
    # value here anymore: the renderer computes a path-only runtime value from
    # `DOMAIN_NAME` and `URI_NAMESPACE` and writes `RAILS_RELATIVE_URL_ROOT`.
cat > "$defaults_file" <<EOF
# Generated defaults for interactive_config.sh
DOMAIN_NAME="$domain"
OPENPROJECT_HOST_NAME="$host"
OPENPROJECT_HTTPS="${https}"
OPENPROJECT_TAG="$tag"
URI_NAMESPACE="StatesmenProjects"
# NOTE: The defaults generator no longer emits a combined DOMAIN_NAME/namespace
# value. The renderer will derive the runtime path-only value
# (`RAILS_RELATIVE_URL_ROOT`) from `DOMAIN_NAME` and `URI_NAMESPACE`.
OS_FAMILY="${os_family:-}"
# Installer-specified defaults
DEFAULT_DBADMIN_PASSWORD="admin123"
ENVIRONMENT_TYPE="production"
PROXY_HTTPS_REDIRECT="true"
DATABASE_STORAGE_TYPE="docker-volumes"
# Proxy bind and port defaults
PROXY_BIND_ADDRESS="0.0.0.0"
PROXY_HTTP_PORT="80"
PROXY_HTTPS_PORT="443"
PROXY_TLS_MODE="internal"
NAMESPACE_ENABLED="false"
EOF

    # Append git defaults if detected (keep them on separate lines)
    if [ -n "$git_user" ] || [ -n "$git_email" ]; then
        {
            if [ -n "$git_user" ]; then
                printf 'GIT_USERNAME="%s"\n' "$git_user"
            fi
            if [ -n "$git_email" ]; then
                printf 'GIT_EMAIL="%s"\n' "$git_email"
            fi
        } >> "$defaults_file"
    fi
    return 0
}
