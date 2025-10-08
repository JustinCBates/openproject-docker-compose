#!/bin/bash

# build_stack.debian.sh - Debian-specific OpenProject Stack Builder
# Part of the OpenProject deployment framework

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "Debian-specific OpenProject Stack Builder"
echo "=========================================="

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "✓ Configuration loaded from $(basename "$CONFIG_FILE")"
    else
        echo "❌ Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
}

# Function to validate Docker Compose setup
validate_docker_compose() {
    echo "Validating Docker Compose setup..."
    
    # Check Docker Compose command availability
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
        echo "✓ Using docker-compose: $(docker-compose --version)"
    elif docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        echo "✓ Using docker compose plugin: $(docker compose version)"
    else
        echo "❌ Docker Compose not found"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker daemon is not running or not accessible"
        exit 1
    fi
    
    echo "✓ Docker Compose environment validated"
}

# Function to validate configuration files
validate_config_files() {
    echo "Validating configuration files..."
    
    cd "$PROJECT_ROOT"
    
    # Check base docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        echo "❌ docker-compose.yml not found"
        exit 1
    fi
    
    # Check .env file (created by configure_docker.debian.sh)
    if [ ! -f ".env" ]; then
        echo "❌ .env file not found"
        echo "Please run configure_docker.sh first."
        exit 1
    fi
    
    # Check docker-compose.override.yml (created by configure_docker.debian.sh)
    if [ ! -f "docker-compose.override.yml" ]; then
        echo "❌ docker-compose.override.yml not found"
        echo "Please run configure_docker.sh first."
        exit 1
    fi
    
    echo "✓ All configuration files validated"
}

# Function to pull Docker images with Debian optimizations
pull_images() {
    echo "Pulling Docker images with Debian optimizations..."
    
    cd "$PROJECT_ROOT"
    
    # Use BuildKit for improved performance (set in .env by configure_docker.debian.sh)
    export DOCKER_BUILDKIT=1
    export COMPOSE_DOCKER_CLI_BUILD=1
    # Determine services that do NOT have a local build context and pull only those
    # Get rendered compose config and service list
    rendered_cfg=$($COMPOSE_CMD -f docker-compose.yml -f docker-compose.override.yml config 2>/dev/null || true)
    services=$($COMPOSE_CMD -f docker-compose.yml -f docker-compose.override.yml config --services 2>/dev/null || true)

    no_build_services=()
    for svc in $services; do
        # Use docker compose to render the service config and check for a 'build' key
        svc_cfg=$($COMPOSE_CMD -f docker-compose.yml -f docker-compose.override.yml config --service "$svc" 2>/dev/null || true)
        if printf "%s" "$svc_cfg" | grep -q "^[[:space:]]*build:"; then
            # service has a build context; skip pulling
            continue
        else
            no_build_services+=("$svc")
        fi
    done

    if [ ${#no_build_services[@]} -eq 0 ]; then
        echo "✓ No remote-only images to pull"
    else
        echo "Pulling images for services: ${no_build_services[*]}"
        $COMPOSE_CMD -f docker-compose.yml -f docker-compose.override.yml pull "${no_build_services[@]}"
    fi
    
    echo "✓ Docker images pulled successfully"
}

# Function to build custom images if needed
build_images() {
    echo "Building custom Docker images with Debian optimizations..."
    
    cd "$PROJECT_ROOT"
    
    # Check if there are any build contexts in docker-compose files
    if grep -q "build:" docker-compose.yml docker-compose.override.yml 2>/dev/null; then
        echo "Found build contexts, building images..."
        
        # Use BuildKit for better performance and caching
        export DOCKER_BUILDKIT=1
        export COMPOSE_DOCKER_CLI_BUILD=1
        
        # Build images using both base and override files
        $COMPOSE_CMD -f docker-compose.yml -f docker-compose.override.yml build --no-cache --parallel
        
        echo "✓ Custom images built successfully"
    else
        echo "✓ No custom images to build"
    fi
}

# Function to create necessary directories with Debian permissions
create_directories() {
    echo "Creating necessary directories with Debian-specific permissions..."
    
    cd "$PROJECT_ROOT"
    
    # Create directories that might be needed
    local dirs_to_create=(
        "data"
        "logs"
        "backups"
        "uploads"
        "tmp"
    )
    
    for dir in "${dirs_to_create[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            # Set Debian-appropriate permissions
            chmod 755 "$dir"
            echo "✓ Created directory: $dir"
        fi
    done
    
    # Set specific permissions for data directories
    if [ -d "data" ]; then
        chmod 755 data
        # Ensure proper ownership for web user (if running as non-root)
        if [ "$(id -u)" != "0" ]; then
            # For non-root deployment, ensure user can write to data directory
            chmod 775 data
        fi
    fi
    
    echo "✓ Directories created with Debian-appropriate permissions"
}

# Function to start the stack with Debian optimizations
start_stack() {
    echo "Starting OpenProject stack with Debian optimizations..."
    
    cd "$PROJECT_ROOT"
    
    # Start services using both base and override files
    $COMPOSE_CMD -f docker-compose.yml -f docker-compose.override.yml up -d
    
    echo "✓ OpenProject stack started"
}

# Function to check stack health with Debian-specific checks
check_stack_health() {
    echo "Checking OpenProject stack health..."
    
    cd "$PROJECT_ROOT"
    
    # Wait for containers to stabilize
    sleep 10
    
    # Check container status
    echo "Container status:"
    $COMPOSE_CMD ps
    
    # Check for any failed containers
    if $COMPOSE_CMD ps | grep -q "Exit\|Restarting"; then
        echo "⚠ Some containers have issues"
        echo "Checking logs for problematic containers..."
        $COMPOSE_CMD logs --tail=50 --timestamps
        return 1
    else
        echo "✓ All containers are running"
    fi
    
    # Test basic connectivity
    local host="${OPENPROJECT_HOST_NAME:-localhost}"
    local protocol="http"
    
    if [ "${OPENPROJECT_HTTPS:-false}" = "true" ]; then
        protocol="https"
    fi
    
    echo "Testing connectivity to $protocol://$host..."
    
    # Wait for service to be ready with Debian-specific timeout
    local max_attempts=60
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$protocol://$host" 2>/dev/null | grep -q "200\|302\|401"; then
            echo "✓ OpenProject is responding at $protocol://$host"
            break
        else
            echo "Attempt $attempt/$max_attempts: Waiting for OpenProject to start..."
            sleep 5
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo "⚠ OpenProject may not be fully ready yet"
        echo "This is normal for initial startup on Debian systems"
        echo "Check logs: $COMPOSE_CMD logs -f"
        return 1
    fi
    
    return 0
}

# Function to configure UFW firewall status
check_firewall_status() {
    echo "Checking UFW firewall status..."
    
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status=$(sudo ufw status | head -1)
        echo "UFW Status: $ufw_status"
        
        if sudo ufw status | grep -q "80\|443"; then
            echo "✓ UFW rules for OpenProject ports are configured"
        else
            echo "⚠ UFW rules may need configuration for ports 80/443"
        fi
    else
        echo "✓ UFW not installed (firewall management not needed)"
    fi
}

# Function to show Debian deployment summary
show_debian_deployment_summary() {
    echo
    echo "Debian OpenProject Deployment Summary:"
    echo "====================================="
    
    local host="${OPENPROJECT_HOST_NAME:-localhost}"
    local protocol="http"
    
    if [ "${OPENPROJECT_HTTPS:-false}" = "true" ]; then
        protocol="https"
    fi
    
    echo "OpenProject URL: $protocol://$host"
    echo "Environment: ${ENVIRONMENT_TYPE:-localdev}"
    echo "OS: Debian/Ubuntu with optimizations"
    
    if [ -n "$DEFAULT_DBADMIN_PASSWORD" ]; then
        if [ "$DEFAULT_DBADMIN_PASSWORD" = "admin123" ]; then
            echo "Admin Login: admin / admin123 (⚠ CHANGE THIS PASSWORD!)"
        else
            echo "Admin Login: admin / [your configured password]"
        fi
    fi
    
    echo
    echo "Debian-specific features enabled:"
    echo "  ✓ BuildKit for optimized builds"
    echo "  ✓ APT cache volumes for faster rebuilds"
    echo "  ✓ UFW firewall integration"
    echo "  ✓ Systemd service optimizations"
    echo "  ✓ Debian-specific environment variables"
    
    echo
    echo "Useful commands:"
    echo "  View logs:       $COMPOSE_CMD logs -f"
    echo "  Stop stack:      $COMPOSE_CMD down"
    echo "  Restart:         $COMPOSE_CMD restart"
    echo "  Update:          $COMPOSE_CMD pull && $COMPOSE_CMD up -d"
    echo "  Check UFW:       sudo ufw status"
    echo "  System logs:     sudo journalctl -u docker"
    
    cd "$PROJECT_ROOT"
    echo
    echo "Current stack status:"
    $COMPOSE_CMD ps
    
    echo
    echo "System information:"
    echo "Memory usage: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
    echo "Disk usage: $(df -h / | awk 'NR==2 {print $5" used"}')"
}

# Main execution
main() {
    echo "Starting Debian-specific OpenProject stack build..."
    echo
    
    # Load configuration
    load_config
    echo
    
    # Validate Docker Compose setup
    validate_docker_compose
    echo
    
    # Validate configuration files
    validate_config_files
    echo
    
    # Create necessary directories
    create_directories
    echo
    
    # Build proxy image via helper if present (keeps proxy build logic in its own script)
    if [ -f "$SCRIPT_DIR/../proxy/build_proxy.sh" ]; then
        "$SCRIPT_DIR/../proxy/build_proxy.sh"
        echo
    fi

    # Build custom images if needed (do this before pulling so services with local build contexts are built locally)
    build_images
    echo
    
    # Pull images for services without local build contexts
    pull_images
    echo
    
    # Start the stack
    start_stack
    echo
    
    # Check stack health
    if check_stack_health; then
        echo "✓ Stack health check passed"
    else
        echo "⚠ Stack health check had warnings (may be normal for initial startup)"
    fi
    echo
    
    # Check firewall status
    check_firewall_status
    echo
    
    # Show deployment summary
    show_debian_deployment_summary
    
    echo
    echo "🎉 Debian-specific OpenProject stack deployment completed!"
}

# Run main function
main "$@"