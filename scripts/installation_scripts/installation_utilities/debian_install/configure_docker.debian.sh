#!/bin/bash

# configure_docker.debian.sh - Debian-specific Docker Configuration
# Part of the OpenProject deployment framework

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source UI helpers if available
if [ -f "$SCRIPT_DIR/../common/common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common/common_ui.sh"
fi
# Source shared config renderer
if [ -f "$SCRIPT_DIR/../common/config_render.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common/config_render.sh"
fi
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "Debian-specific Docker Configuration"
echo "=========================================="

# Function to load configuration
load_config() {
    local defaults_file="$SCRIPT_DIR/../../interactive_config.cfg.defaults"
    if [ -f "$defaults_file" ]; then
        set -a
        # shellcheck source=/dev/null
        source "$defaults_file"
        set +a
    fi

    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        echo "✓ Configuration loaded from $(basename "$CONFIG_FILE")"
    else
        echo "❌ Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

# Function to update .env file with Debian-specific variables
update_env_file() {
    local env_file="$PROJECT_ROOT/.env"
    
    echo "Updating .env file with configuration and Debian-specific variables..."
    
    # Ensure .env file exists. If it's missing but .env.example is present, create it
    if [ ! -f "$env_file" ]; then
        if [ -f "$PROJECT_ROOT/.env.example" ]; then
            echo "No .env found at $env_file. Creating from .env.example..."
            cp "$PROJECT_ROOT/.env.example" "$env_file"
            echo "Created $env_file from .env.example"
        else
            echo "❌ .env file not found: $env_file"
            echo "Please create a .env file or run interactive_config.sh to generate configuration."
            exit 1
        fi
    fi
    
    # Update .env file with values from interactive_config.cfg
    if [ -n "$OPENPROJECT_HOST_NAME" ]; then
        if grep -q "^OPENPROJECT_HOST__NAME=" "$env_file"; then
            sed -i "s|^OPENPROJECT_HOST__NAME=.*|OPENPROJECT_HOST__NAME=$OPENPROJECT_HOST_NAME|" "$env_file"
        else
            echo "OPENPROJECT_HOST__NAME=$OPENPROJECT_HOST_NAME" >> "$env_file"
        fi
        echo "✓ Updated hostname: $OPENPROJECT_HOST_NAME"
    fi

    # Relative URL root for path-based deployments (e.g. /subdomain)
    # Prefer renderer path value (RAILS_RELATIVE_URL_ROOT)
    local write_relroot="${RAILS_RELATIVE_URL_ROOT:-}"
    if [ -n "$write_relroot" ]; then
        if grep -q "^RAILS_RELATIVE_URL_ROOT=" "$env_file"; then
            sed -i "s|^RAILS_RELATIVE_URL_ROOT=.*|RAILS_RELATIVE_URL_ROOT=$write_relroot|" "$env_file"
        else
            echo "RAILS_RELATIVE_URL_ROOT=$write_relroot" >> "$env_file"
        fi
        echo "✓ Updated relative URL root: $write_relroot"
    fi
    
    if [ -n "$OPENPROJECT_HTTPS" ]; then
        if grep -q "^OPENPROJECT_HTTPS=" "$env_file"; then
            sed -i "s|^OPENPROJECT_HTTPS=.*|OPENPROJECT_HTTPS=$OPENPROJECT_HTTPS|" "$env_file"
        else
            echo "OPENPROJECT_HTTPS=$OPENPROJECT_HTTPS" >> "$env_file"
        fi
        echo "✓ Updated HTTPS setting: $OPENPROJECT_HTTPS"
    fi
    
    if [ -n "$OPENPROJECT_TAG" ]; then
        # If OPENPROJECT_TAG uses the 'channel/version' form (e.g. 'stable/16'),
        # map to a canonical Docker tag using the version component and '-slim'
        # (e.g. '16-slim'). Otherwise sanitize by replacing '/' with '-'.
        if printf '%s' "$OPENPROJECT_TAG" | grep -q '/'; then
            version_part="${OPENPROJECT_TAG##*/}"
            sanitized_tag="${version_part}-slim"
        else
            sanitized_tag="${OPENPROJECT_TAG//\//-}"
        fi

        if grep -q "^TAG=" "$env_file"; then
            sed -i "s|^TAG=.*|TAG=$sanitized_tag|" "$env_file"
        else
            echo "TAG=$sanitized_tag" >> "$env_file"
        fi
        echo "✓ Updated OpenProject tag: $OPENPROJECT_TAG (written as $sanitized_tag)"
    fi
    
    if [ -n "$DEFAULT_DBADMIN_PASSWORD" ]; then
        if grep -q "^OPENPROJECT_ADMIN_PASSWORD=" "$env_file"; then
            sed -i "s|^OPENPROJECT_ADMIN_PASSWORD=.*|OPENPROJECT_ADMIN_PASSWORD=$DEFAULT_DBADMIN_PASSWORD|" "$env_file"
        else
            echo "OPENPROJECT_ADMIN_PASSWORD=$DEFAULT_DBADMIN_PASSWORD" >> "$env_file"
        fi
        echo "✓ Updated admin password"
    fi

    # Honor storage preference from interactive_config.cfg
    # If DATABASE_STORAGE_TYPE is set to "docker-volumes", use named volumes
    if [ -n "$DATABASE_STORAGE_TYPE" ] && [ "$DATABASE_STORAGE_TYPE" = "docker-volumes" ]; then
        pgdata_setting="pgdata"
        opdata_setting="opdata"
    else
        pgdata_setting="/var/lib/postgresql/data"
        opdata_setting="/var/openproject/assets"
    fi

    if grep -q "^PGDATA=" "$env_file"; then
        sed -i "s|^PGDATA=.*|PGDATA=${pgdata_setting}|" "$env_file"
    else
        echo "PGDATA=${pgdata_setting}" >> "$env_file"
    fi

    if grep -q "^OPDATA=" "$env_file"; then
        sed -i "s|^OPDATA=.*|OPDATA=${opdata_setting}|" "$env_file"
    else
        echo "OPDATA=${opdata_setting}" >> "$env_file"
    fi

    echo "✓ Updated storage settings: PGDATA=${pgdata_setting}, OPDATA=${opdata_setting}"
    
    # Add Debian-specific environment variables idempotently. We use a marker block
    # so repeated runs will replace the prior block instead of appending duplicates.
    local start_marker="# BEGIN openproject-debian-config"
    local end_marker="# END openproject-debian-config"

    # Prepare the block content
    read -r -d '' debian_block <<EOF || true
${start_marker}
# Debian-specific Docker configuration
DOCKER_BUILDKIT=1
COMPOSE_DOCKER_CLI_BUILD=1
DEBIAN_FRONTEND=noninteractive
DEBIAN_PRIORITY=critical
APT_LISTCHANGES_FRONTEND=none
${end_marker}
EOF

    # Remove any existing marker block between the start and end markers
    if grep -q "^${start_marker}$" "$env_file" 2>/dev/null; then
        # Use awk to remove the block in-place safely
        awk -v s="$start_marker" -v e="$end_marker" '
            $0 == s {skip=1; next}
            $0 == e {skip=0; next}
            !skip {print}
        ' "$env_file" > "$env_file.tmp" && mv "$env_file.tmp" "$env_file"
    fi

    # Append the canonical block
    printf "%s\n" "$debian_block" >> "$env_file"
    
    echo "✓ .env file updated with configuration and Debian-specific variables"
}

# Function to create docker-compose.override.yml with Debian optimizations
create_override_file() {
    local override_file="$PROJECT_ROOT/docker-compose.override.yml"
    
    echo "Creating docker-compose.override.yml with Debian optimizations..."
    
        # Generate the override content into a temp file and atomically replace the existing file
        tmp_override=$(mktemp /tmp/docker-compose.override.yml.XXXXXX)
                cat > "$tmp_override" <<'EOF'
# docker-compose.override.yml - Debian-specific OpenProject optimizations
# Generated by configure_docker.debian.sh

services:
    db:
        environment:
            # Debian-specific PostgreSQL optimizations
            POSTGRES_INITDB_ARGS: "--locale=C.UTF-8 --encoding=UTF8"
        volumes:
            # APT cache volume for faster builds
            - apt-cache:/var/cache/apt

    web:
        environment:
            # Debian-specific Rails optimizations
            DEBIAN_FRONTEND: noninteractive
            APT_LISTCHANGES_FRONTEND: none
            RAILS_ENV: "${RAILS_ENV:-production}"
        volumes:
            # APT cache volume for faster builds
            - apt-cache:/var/cache/apt
            # Debian-specific temp directory
            - /tmp:/tmp:rw
        sysctls:
            # Debian kernel optimizations for Rails
            net.core.somaxconn: 65535
            net.ipv4.tcp_tw_reuse: 1

    proxy:
        environment:
            # Debian-specific Caddy optimizations
            DEBIAN_FRONTEND: noninteractive
        ports:
            # Standard HTTP/HTTPS ports for Debian UFW rules
            - "80:80"
            - "443:443"
        volumes:
            # APT cache volume for faster builds
            - apt-cache:/var/cache/apt

volumes:
    # Debian APT cache volume for faster package installations
    apt-cache:
        driver: local
        driver_opts:
            type: tmpfs
            device: tmpfs
            o: "size=512m,uid=0,gid=0"

networks:
    default:
        driver: bridge
        driver_opts:
            # Debian-specific bridge optimizations
            com.docker.network.bridge.name: "openproject-br"
            com.docker.network.bridge.enable_icc: "true"
            com.docker.network.bridge.enable_ip_masquerade: "true"
EOF

    # If the override file does not exist yet, move the temp file into place.
    # If it exists, replace it only if the content changed to avoid unnecessary writes.
    if [ ! -f "$override_file" ]; then
        mv "$tmp_override" "$override_file"
    else
        if ! cmp -s "$tmp_override" "$override_file"; then
            mv "$tmp_override" "$override_file"
        else
            rm -f "$tmp_override"
        fi
    fi

    echo "✓ docker-compose.override.yml created/updated with Debian optimizations"
}

# Function to configure UFW firewall rules
configure_ufw_firewall() {
    echo "Configuring UFW firewall for OpenProject..."
    
    # Check if UFW is installed and active
    if command -v ufw >/dev/null 2>&1; then
        echo "✓ UFW firewall detected"
        
        # Allow OpenProject ports
        echo "Configuring UFW rules for OpenProject..."
        sudo ufw allow 80/tcp comment 'OpenProject HTTP'
        sudo ufw allow 443/tcp comment 'OpenProject HTTPS'
        
        # Allow SSH if not already allowed
        sudo ufw allow ssh comment 'SSH access'
        
        echo "✓ UFW firewall configured for OpenProject"
    else
        echo "⚠ UFW not installed, skipping firewall configuration"
    fi
}

# Function to optimize systemd for Docker
configure_systemd_docker() {
    echo "Configuring systemd optimizations for Docker..."
    
    local systemd_override_dir="/etc/systemd/system/docker.service.d"
    local systemd_override_file="$systemd_override_dir/debian-override.conf"
    
    # Create systemd override directory
    if [ ! -d "$systemd_override_dir" ]; then
        sudo mkdir -p "$systemd_override_dir"
    fi
    
    # Create Debian-specific systemd override
    sudo tee "$systemd_override_file" > /dev/null << 'EOF'
[Service]
# Debian-specific Docker service optimizations
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TasksMax=1048576
OOMScoreAdjust=-999

# Debian-specific environment
Environment="DEBIAN_FRONTEND=noninteractive"
Environment="APT_LISTCHANGES_FRONTEND=none"

# Restart policy for Debian systems
Restart=always
RestartSec=10s
EOF

    # Reload systemd and restart Docker
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    
    echo "✓ Systemd Docker service optimized for Debian"
}

# Function to configure APT for Docker builds
configure_apt_optimizations() {
    echo "Configuring APT optimizations for Docker builds..."
    
    # Create APT configuration for Docker builds
    local apt_config_dir="/etc/apt/apt.conf.d"
    local apt_docker_conf="$apt_config_dir/99-docker-debian"
    
    sudo tee "$apt_docker_conf" > /dev/null << 'EOF'
// Debian-specific APT optimizations for Docker builds
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT::Get::Assume-Yes "true";
APT::Get::Fix-Missing "true";
Dpkg::Use-Pty "0";
APT::Acquire::Retries "3";
EOF

    echo "✓ APT optimized for Docker builds"
}

# Function to show Debian configuration summary
show_debian_summary() {
    echo
    echo "Debian Docker Configuration Summary:"
    echo "==================================="
    echo "✓ .env file updated with Debian-specific variables"
    echo "✓ docker-compose.override.yml created with Debian optimizations"
    echo "✓ UFW firewall configured (if available)"
    echo "✓ Systemd Docker service optimized"
    echo "✓ APT configured for efficient Docker builds"
    echo
    echo "Debian-specific optimizations include:"
    echo "  - BuildKit support enabled"
    echo "  - APT cache volumes for faster builds"
    echo "  - UFW firewall rules for ports 80/443"
    echo "  - Systemd service limits and restart policies"
    echo "  - PostgreSQL and Rails environment optimizations"
    echo
}

# Main execution
main() {
    echo "Starting Debian-specific Docker configuration..."
    echo
    
    # Load configuration
    load_config
    echo

    # Ensure a path-only relative URL root is present. Prefer RAILS_RELATIVE_URL_ROOT
    # when available, otherwise compute from URI_NAMESPACE/NAMESPACE and export
    # RAILS_RELATIVE_URL_ROOT so downstream steps can use the canonical path value.
    if [ -z "${RAILS_RELATIVE_URL_ROOT:-}" ]; then
        ns="${URI_NAMESPACE:-${NAMESPACE:-}}"
        if [ -n "${ns}" ]; then
            _relroot="/${ns%/}"
        else
            _relroot=""
        fi
        export RAILS_RELATIVE_URL_ROOT="${_relroot}"
        echo "✓ Computed relative URL root: ${RAILS_RELATIVE_URL_ROOT}"
    else
        echo "✓ Using provided RAILS_RELATIVE_URL_ROOT: ${RAILS_RELATIVE_URL_ROOT}"
    fi

    # Ensure renderer has computed deployment values (RAILS_RELATIVE_URL_ROOT etc.)
    if type detect_deployment_values >/dev/null 2>&1; then
        detect_deployment_values "$PROJECT_ROOT"
    fi

    # Configure proxy (render Caddyfile/template) if proxy utility exists
    if [ -f "$SCRIPT_DIR/../proxy/configure_proxy.sh" ]; then
        if [ "${INTEGRATION_TEST:-}" = "1" ]; then
            "$SCRIPT_DIR/../proxy/configure_proxy.sh" --integration-test
        else
            "$SCRIPT_DIR/../proxy/configure_proxy.sh"
        fi
    fi
    echo
    
    # Update .env file with Debian-specific variables
    update_env_file
    echo

    # Centralized generation of .env and docker-compose.override.yml
    # Use config_render helper to detect values and write files. We skip
    # writing the Caddy template here because proxy/configure_proxy.sh
    # has its own rendering flow and enforces additional guards.
    if type detect_deployment_values >/dev/null 2>&1; then
        detect_deployment_values "$PROJECT_ROOT"
        # write_files APPLY_FLAG SKIP_CADDY
        write_files true true
        echo "✓ Deployment .env and docker-compose.override.yml generated"
    fi
    
    # Create docker-compose.override.yml with Debian optimizations
    create_override_file
    echo
    
    # Configure UFW firewall
    configure_ufw_firewall
    echo
    
    # Configure systemd optimizations
    configure_systemd_docker
    echo
    
    # Configure APT optimizations
    configure_apt_optimizations
    echo
    
    # Show summary
    show_debian_summary
    
    echo "🎉 Debian-specific Docker configuration completed successfully!"
}

# Run main function
main "$@"