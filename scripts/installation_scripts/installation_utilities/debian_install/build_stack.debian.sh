#!/bin/bash

# build_stack.debian.sh - Debian-specific OpenProject Stack Builder
# Builds, deploys, and manages the OpenProject Docker Compose stack with Debian optimizations
# Part of the OpenProject deployment framework

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "OpenProject Stack Builder (Debian)"
echo "=========================================="

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "✓ Configuration loaded from $(basename "$CONFIG_FILE")"
    else
        echo "⚠ Configuration file not found: $CONFIG_FILE"
        echo "Please run interactive_config.sh first to configure your environment."
        exit 1
    fi
}

# Function to check system requirements for Debian
check_debian_requirements() {
    echo "Checking Debian system requirements..."
    
    # Check OS version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "✓ OS: $PRETTY_NAME"
        
        # Check if supported Debian/Ubuntu version
        case "$ID" in
            ubuntu)
                if [ "${VERSION_ID%.*}" -lt 18 ]; then
                    echo "⚠ Ubuntu version might be too old. Recommended: 18.04+"
                fi
                ;;
            debian)
                if [ "${VERSION_ID}" -lt 10 ]; then
                    echo "⚠ Debian version might be too old. Recommended: 10+"
                fi
                ;;
        esac
    fi
    
    # Check available memory
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$mem_gb" -lt 2 ]; then
        echo "⚠ Low memory detected: ${mem_gb}GB. Recommended: 4GB+ for production"
    else
        echo "✓ Memory: ${mem_gb}GB"
    fi
    
    # Check available disk space
    local disk_gb=$(df -BG / | awk 'NR==2{print $4}' | sed 's/G//')
    if [ "$disk_gb" -lt 10 ]; then
        echo "⚠ Low disk space: ${disk_gb}GB. Recommended: 20GB+"
    else
        echo "✓ Disk space: ${disk_gb}GB available"
    fi
}

# Function to validate Docker and Docker Compose
validate_docker() {
    echo "Validating Docker environment..."
    
    # Check Docker installation
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker is not installed"
        echo "Please install Docker first using install_docker.debian.sh"
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker daemon is not running or not accessible"
        echo "Try: sudo systemctl start docker"
        echo "Or check permissions: sudo usermod -aG docker $USER"
        exit 1
    fi
    
    # Check Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
        echo "✓ Using docker-compose: $(docker-compose --version)"
    elif docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        echo "✓ Using docker compose plugin: $(docker compose version)"
    else
        echo "❌ Docker Compose not found"
        echo "Install with: sudo apt-get install docker-compose-plugin"
        exit 1
    fi
    
    echo "✓ Docker environment validated"
}

# Function to configure Debian-specific optimizations
configure_debian_optimizations() {
    echo "Applying Debian-specific optimizations..."
    
    # Configure systemd for Docker
    local systemd_override_dir="/etc/systemd/system/docker.service.d"
    local systemd_override_file="$systemd_override_dir/override.conf"
    
    if [ ! -f "$systemd_override_file" ]; then
        echo "Creating systemd override for Docker..."
        sudo mkdir -p "$systemd_override_dir"
        sudo tee "$systemd_override_file" > /dev/null << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TasksMax=1048576
EOF
        sudo systemctl daemon-reload
        echo "✓ Systemd override configured"
    else
        echo "✓ Systemd override already exists"
    fi
    
    # Configure Docker log rotation
    if [ ! -f /etc/logrotate.d/docker-containers ]; then
        echo "Configuring container log rotation..."
        sudo tee /etc/logrotate.d/docker-containers > /dev/null << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=10M
    missingok
    delaycompress
    copytruncate
    notifempty
}
EOF
        echo "✓ Container log rotation configured"
    fi
    
    # Optimize kernel parameters for containers
    local sysctl_file="/etc/sysctl.d/99-docker.conf"
    if [ ! -f "$sysctl_file" ]; then
        echo "Configuring kernel parameters for Docker..."
        sudo tee "$sysctl_file" > /dev/null << 'EOF'
# Docker optimizations
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
fs.may_detach_mounts = 1
vm.max_map_count = 262144
vm.overcommit_memory = 1
kernel.panic = 10
kernel.panic_on_oops = 1
EOF
        sudo sysctl -p "$sysctl_file"
        echo "✓ Kernel parameters optimized"
    else
        echo "✓ Kernel parameters already optimized"
    fi
}

# Function to validate project files
validate_project_files() {
    echo "Validating OpenProject files..."
    
    cd "$PROJECT_ROOT"
    
    # Check for docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        echo "❌ docker-compose.yml not found in project root: $PROJECT_ROOT"
        exit 1
    fi
    
    # Check for .env file
    if [ ! -f ".env" ]; then
        echo "⚠ .env file not found"
        if [ -f ".env.example" ]; then
            echo "Creating .env from .env.example..."
            cp .env.example .env
            echo "✓ .env file created"
        else
            echo "❌ .env.example not found"
            exit 1
        fi
    fi
    
    echo "✓ Project files validated"
}

# Function to pull Docker images with Debian optimizations
pull_images() {
    echo "Pulling Docker images with optimizations..."
    
    cd "$PROJECT_ROOT"
    
    # Use parallel pulls for faster download
    $COMPOSE_CMD pull --parallel
    
    # Clean up unused images to save space
    docker image prune -f
    
    echo "✓ Docker images pulled and optimized"
}

# Function to build custom images if needed
build_images() {
    echo "Building custom Docker images..."
    
    cd "$PROJECT_ROOT"
    
    # Check if there are any build contexts in docker-compose.yml
    if grep -q "build:" docker-compose.yml; then
        echo "Found build contexts, building images..."
        
        # Use BuildKit for better performance
        export DOCKER_BUILDKIT=1
        export COMPOSE_DOCKER_CLI_BUILD=1
        
        $COMPOSE_CMD build --no-cache --parallel
        echo "✓ Custom images built successfully"
    else
        echo "✓ No custom images to build"
    fi
}

# Function to create necessary directories with Debian permissions
create_directories() {
    echo "Creating necessary directories with proper permissions..."
    
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
            # Set proper ownership and permissions
            if [ "$dir" = "data" ] || [ "$dir" = "uploads" ]; then
                # These directories need to be writable by the container
                chmod 755 "$dir"
                # Set SELinux context if available
                if command -v setsebool >/dev/null 2>&1; then
                    sudo setsebool -P container_manage_cgroup on
                fi
            fi
            echo "✓ Created directory: $dir"
        fi
    done
    
    echo "✓ Directories created and configured"
}

# Function to configure firewall for OpenProject
configure_firewall() {
    echo "Configuring firewall for OpenProject..."
    
    if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "Status: active"; then
        echo "Configuring UFW for OpenProject..."
        
        # Allow HTTP and HTTPS
        sudo ufw allow 80/tcp comment 'OpenProject HTTP'
        sudo ufw allow 443/tcp comment 'OpenProject HTTPS'
        
        # Allow SSH (be careful not to lock yourself out)
        sudo ufw allow ssh
        
        echo "✓ UFW configured for OpenProject"
    elif command -v iptables >/dev/null 2>&1; then
        echo "Note: iptables detected. Please manually configure firewall rules if needed:"
        echo "  sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT"
        echo "  sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT"
    else
        echo "✓ No active firewall detected"
    fi
}

# Function to start the stack with Debian optimizations
start_stack() {
    echo "Starting OpenProject stack with Debian optimizations..."
    
    cd "$PROJECT_ROOT"
    
    # Start services in detached mode with resource limits
    $COMPOSE_CMD up -d
    
    # Wait for containers to stabilize
    sleep 10
    
    echo "✓ OpenProject stack started"
}

# Function to check stack health
check_stack_health() {
    echo "Checking stack health..."
    
    cd "$PROJECT_ROOT"
    
    # Check container status
    echo "Container status:"
    $COMPOSE_CMD ps
    
    # Check for any failed containers
    if $COMPOSE_CMD ps | grep -q "Exit\|Restarting"; then
        echo "⚠ Some containers have issues"
        echo "Checking logs for problematic containers..."
        $COMPOSE_CMD logs --tail=50 --timestamps
    else
        echo "✓ All containers are running"
    fi
    
    # Check system resources
    echo
    echo "System resource usage:"
    echo "Memory: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
    echo "Disk: $(df -h / | awk 'NR==2 {print $3"/"$2" ("$5" used)"}')"
    
    # Test basic connectivity
    local host="${OPENPROJECT_HOST_NAME:-localhost}"
    local protocol="http"
    
    if [ "${OPENPROJECT_HTTPS:-false}" = "true" ]; then
        protocol="https"
    fi
    
    echo "Testing connectivity to $protocol://$host..."
    
    # Wait for service to be ready
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
        echo "Check logs: $COMPOSE_CMD logs -f"
    fi
}

# Function to show deployment summary
show_deployment_summary() {
    echo
    echo "Deployment Summary (Debian):"
    echo "============================"
    
    local host="${OPENPROJECT_HOST_NAME:-localhost}"
    local protocol="http"
    
    if [ "${OPENPROJECT_HTTPS:-false}" = "true" ]; then
        protocol="https"
    fi
    
    echo "OpenProject URL: $protocol://$host"
    echo "Environment: ${ENVIRONMENT_TYPE:-localdev}"
    echo "OS: $(lsb_release -ds 2>/dev/null || echo 'Debian/Ubuntu')"
    
    if [ -n "$DEFAULT_ADMIN_PASSWORD" ]; then
        if [ "$DEFAULT_ADMIN_PASSWORD" = "admin123" ]; then
            echo "Admin Login: admin / admin123 (⚠ CHANGE THIS PASSWORD!)"
        else
            echo "Admin Login: admin / [your configured password]"
        fi
    fi
    
    echo
    echo "Useful commands:"
    echo "  View logs:    $COMPOSE_CMD logs -f"
    echo "  Stop stack:   $COMPOSE_CMD down"
    echo "  Restart:      $COMPOSE_CMD restart"
    echo "  Update:       $COMPOSE_CMD pull && $COMPOSE_CMD up -d"
    echo "  System logs:  sudo journalctl -u docker"
    
    cd "$PROJECT_ROOT"
    echo
    echo "Current stack status:"
    $COMPOSE_CMD ps
    
    echo
    echo "System information:"
    echo "Memory usage: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
    echo "Disk usage: $(df -h / | awk 'NR==2 {print $5" used"}')"
}

# Function to handle cleanup on exit
cleanup() {
    echo
    echo "Build process interrupted"
    cd "$PROJECT_ROOT"
    
    # Don't automatically stop containers on script exit unless they're in a bad state
    if $COMPOSE_CMD ps 2>/dev/null | grep -q "Exit"; then
        echo "Cleaning up failed containers..."
        $COMPOSE_CMD down
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Build and deploy OpenProject Docker stack with Debian optimizations"
    echo
    echo "Options:"
    echo "  --pull-only     Only pull images, don't start stack"
    echo "  --build-only    Only build images, don't start stack"
    echo "  --no-pull       Skip pulling images"
    echo "  --no-build      Skip building custom images"
    echo "  --no-optimize   Skip Debian-specific optimizations"
    echo "  --help          Show this help message"
}

# Main execution
main() {
    local pull_only=false
    local build_only=false
    local skip_pull=false
    local skip_build=false
    local skip_optimize=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --pull-only)
                pull_only=true
                shift
                ;;
            --build-only)
                build_only=true
                shift
                ;;
            --no-pull)
                skip_pull=true
                shift
                ;;
            --no-build)
                skip_build=true
                shift
                ;;
            --no-optimize)
                skip_optimize=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    echo "Starting OpenProject stack build process for Debian..."
    echo
    
    # Load configuration
    load_config
    
    # Check requirements
    check_debian_requirements
    echo
    
    # Validate environment
    validate_docker
    validate_project_files
    
    # Apply Debian optimizations unless skipped
    if [ "$skip_optimize" = false ]; then
        configure_debian_optimizations
        echo
    fi
    
    # Create necessary directories
    create_directories
    
    # Configure firewall
    configure_firewall
    echo
    
    # Pull images unless skipped
    if [ "$skip_pull" = false ]; then
        pull_images
    fi
    
    # Build custom images unless skipped
    if [ "$skip_build" = false ]; then
        build_images
    fi
    
    # Exit early if only pulling or building
    if [ "$pull_only" = true ]; then
        echo "✓ Images pulled successfully"
        exit 0
    fi
    
    if [ "$build_only" = true ]; then
        echo "✓ Images built successfully"
        exit 0
    fi
    
    # Start the stack
    start_stack
    
    # Check health
    check_stack_health
    
    # Show summary
    show_deployment_summary
    
    echo
    echo "🎉 OpenProject stack deployment completed successfully on Debian!"
    echo
    
    # Disable cleanup trap since everything succeeded
    trap - EXIT
}

# Run main function with all arguments
main "$@"