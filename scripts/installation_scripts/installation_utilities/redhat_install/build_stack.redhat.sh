#!/bin/bash

# build_stack.redhat.sh - Red Hat-specific OpenProject Stack Builder
# Part of the OpenProject deployment framework

echo "=========================================="
echo "Red Hat Stack Builder (STUB)"
echo "=========================================="

echo "⚠ Red Hat/CentOS/Fedora implementation is not yet complete"
echo "This is a stub implementation for future development"
echo ""
echo "Planned Red Hat family optimizations:"
echo "  - DNF/YUM-optimized Docker builds"
echo "  - SELinux policy configurations"
echo "  - Firewalld integration"
echo "  - Red Hat-specific performance tuning"
echo ""
echo "For now, using basic Docker Compose build..."

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$PROJECT_ROOT"

# Basic Docker Compose build using override file created by configure_docker.redhat.sh
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
else
    echo "❌ Docker Compose not found"
    exit 1
fi

echo "Starting basic OpenProject stack..."
$COMPOSE_CMD -f docker-compose.yml -f docker-compose.override.yml up -d

echo "✓ Basic Red Hat stack deployment completed (stub implementation)"
echo "🔧 Full Red Hat family optimizations coming soon!"
echo ""
echo "Stack status:"
$COMPOSE_CMD ps

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source UI helpers if available
if [ -f "$SCRIPT_DIR/../common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common_ui.sh"
fi
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "OpenProject Stack Builder (Red Hat)"
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

# Function to check system requirements for Red Hat family
check_redhat_requirements() {
    echo "Checking Red Hat family system requirements..."
    
    # Check OS version
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "✓ OS: $PRETTY_NAME"
        
        # Check if supported Red Hat family version
        case "$ID" in
            rhel|centos)
                if [ "${VERSION_ID%.*}" -lt 7 ]; then
                    echo "⚠ OS version might be too old. Recommended: 7+"
                fi
                ;;
            fedora)
                if [ "${VERSION_ID}" -lt 30 ]; then
                    echo "⚠ Fedora version might be too old. Recommended: 30+"
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
    
    # Check SELinux status
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status=$(getenforce)
        echo "SELinux status: $selinux_status"
        if [ "$selinux_status" = "Enforcing" ]; then
            echo "⚠ SELinux is enforcing. May require additional configuration for containers."
        fi
    fi
}

# Function to validate Docker and Docker Compose
validate_docker() {
    echo "Validating Docker environment..."
    
    # Check Docker installation
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker is not installed"
        echo "Please install Docker first using install_docker.redhat.sh"
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
        echo "Install with: sudo dnf install docker-compose-plugin"
        exit 1
    fi
    
    echo "✓ Docker environment validated"
}

# Function to configure Red Hat family-specific optimizations
configure_redhat_optimizations() {
    echo "Applying Red Hat family-specific optimizations..."
    
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
OOMScoreAdjust=-999
EOF
        sudo systemctl daemon-reload
        echo "✓ Systemd override configured"
    else
        echo "✓ Systemd override already exists"
    fi
    
    # Configure SELinux for Docker (if SELinux is enabled)
    if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" = "Enforcing" ]; then
        echo "Configuring SELinux for Docker..."
        
        # Set SELinux booleans for containers
        sudo setsebool -P container_manage_cgroup on 2>/dev/null || true
        sudo setsebool -P virt_use_nfs on 2>/dev/null || true
        sudo setsebool -P virt_sandbox_use_all_caps on 2>/dev/null || true
        
        echo "✓ SELinux configured for Docker"
    fi
    
    # Optimize kernel parameters for containers
    local sysctl_file="/etc/sysctl.d/99-docker-redhat.conf"
    if [ ! -f "$sysctl_file" ]; then
        echo "Configuring kernel parameters for Docker on Red Hat..."
        sudo tee "$sysctl_file" > /dev/null << 'EOF'
# Docker optimizations for Red Hat family
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
fs.may_detach_mounts = 1
vm.max_map_count = 262144
vm.overcommit_memory = 1
kernel.panic = 10
kernel.panic_on_oops = 1
# Red Hat specific optimizations
net.ipv4.conf.all.route_localnet = 1
net.ipv4.ip_local_port_range = 1024 65000
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
EOF
        sudo sysctl -p "$sysctl_file"
        echo "✓ Kernel parameters optimized for Red Hat"
    else
        echo "✓ Kernel parameters already optimized"
    fi
    
    # Configure log rotation for containers
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
    create 0644 root root
}
EOF
        echo "✓ Container log rotation configured"
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

# Function to pull Docker images with Red Hat optimizations
pull_images() {
    echo "Pulling Docker images with Red Hat optimizations..."
    
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

# Function to create necessary directories with Red Hat permissions
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
                # Set SELinux context if SELinux is enabled
                if command -v semanage >/dev/null 2>&1 && [ "$(getenforce)" = "Enforcing" ]; then
                    sudo chcon -R -t container_file_t "$dir" 2>/dev/null || true
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
    
    # Check for firewalld (default on Red Hat family)
    if command -v firewall-cmd >/dev/null 2>&1 && sudo firewall-cmd --state >/dev/null 2>&1; then
        echo "Configuring firewalld for OpenProject..."
        
        # Add services to firewall
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        
        # Allow Docker daemon communication
        sudo firewall-cmd --permanent --add-port=2376/tcp
        
        # Reload firewall
        sudo firewall-cmd --reload
        
        echo "✓ Firewalld configured for OpenProject"
    # Check for iptables as fallback
    elif command -v iptables >/dev/null 2>&1; then
        echo "Note: iptables detected. Consider configuring firewall rules:"
        echo "  sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT"
        echo "  sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT"
        echo "  sudo service iptables save"
    else
        echo "✓ No active firewall detected"
    fi
}

# Function to start the stack with Red Hat optimizations
start_stack() {
    echo "Starting OpenProject stack with Red Hat optimizations..."
    
    cd "$PROJECT_ROOT"
    
    # Start services in detached mode
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
    
    # Check SELinux denials if SELinux is enabled
    if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce)" = "Enforcing" ]; then
        local denials=$(sudo ausearch -m avc -ts recent 2>/dev/null | grep -c docker || echo "0")
        if [ "$denials" -gt 0 ]; then
            echo "⚠ SELinux denials detected: $denials"
            echo "Check with: sudo ausearch -m avc -ts recent | grep docker"
        else
            echo "✓ No recent SELinux denials"
        fi
    fi
    
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
    echo "Deployment Summary (Red Hat):"
    echo "============================="
    
    local host="${OPENPROJECT_HOST_NAME:-localhost}"
    local protocol="http"
    
    if [ "${OPENPROJECT_HTTPS:-false}" = "true" ]; then
        protocol="https"
    fi
    
    echo "OpenProject URL: $protocol://$host"
    echo "Environment: ${ENVIRONMENT_TYPE:-localdev}"
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "OS: $PRETTY_NAME"
    fi
    
    if [ -n "$DEFAULT_DBADMIN_PASSWORD" ]; then
        if [ "$DEFAULT_DBADMIN_PASSWORD" = "admin123" ]; then
            echo "Admin Login: admin / admin123 (⚠ CHANGE THIS PASSWORD!)"
        else
            echo "Admin Login: admin / [your configured password]"
        fi
    fi
    
    echo
    echo "Useful commands:"
    echo "  View logs:       $COMPOSE_CMD logs -f"
    echo "  Stop stack:      $COMPOSE_CMD down"
    echo "  Restart:         $COMPOSE_CMD restart"
    echo "  Update:          $COMPOSE_CMD pull && $COMPOSE_CMD up -d"
    echo "  System logs:     sudo journalctl -u docker"
    echo "  Package updates: sudo dnf update (Fedora) or sudo yum update (RHEL/CentOS)"
    
    if command -v getenforce >/dev/null 2>&1; then
        echo "  SELinux status:  getenforce"
        echo "  SELinux denials: sudo ausearch -m avc -ts recent | grep docker"
    fi
    
    cd "$PROJECT_ROOT"
    echo
    echo "Current stack status:"
    $COMPOSE_CMD ps
    
    echo
    echo "System information:"
    echo "Memory usage: $(free -h | awk '/^Mem:/ {print $3"/"$2}')"
    echo "Disk usage: $(df -h / | awk 'NR==2 {print $5" used"}')"
    
    if command -v getenforce >/dev/null 2>&1; then
        echo "SELinux: $(getenforce)"
    fi
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
    echo "Build and deploy OpenProject Docker stack with Red Hat family optimizations"
    echo
    echo "Options:"
    echo "  --pull-only     Only pull images, don't start stack"
    echo "  --build-only    Only build images, don't start stack"
    echo "  --no-pull       Skip pulling images"
    echo "  --no-build      Skip building custom images"
    echo "  --no-optimize   Skip Red Hat-specific optimizations"
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
    
    echo "Starting OpenProject stack build process for Red Hat family..."
    echo
    
    # Load configuration
    load_config
    
    # Check requirements
    check_redhat_requirements
    echo
    
    # Validate environment
    validate_docker
    validate_project_files
    
    # Apply Red Hat optimizations unless skipped
    if [ "$skip_optimize" = false ]; then
        configure_redhat_optimizations
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
    echo "🎉 OpenProject stack deployment completed successfully on Red Hat family OS!"
    echo
    
    # Disable cleanup trap since everything succeeded
    trap - EXIT
}

# Run main function with all arguments
main "$@"