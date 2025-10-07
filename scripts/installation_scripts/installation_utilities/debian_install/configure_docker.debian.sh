#!/bin/bash

# configure_docker.debian.sh - Debian-specific Docker Configuration
# Configures Docker daemon settings, user permissions, and service management for Debian/Ubuntu systems
# Part of the OpenProject deployment framework

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"

echo "=========================================="
echo "Docker Configuration Utility (Debian)"
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

# Function to check if Docker is installed
check_docker_installed() {
    if command -v docker >/dev/null 2>&1; then
        echo "✓ Docker is installed: $(docker --version)"
        return 0
    else
        echo "❌ Docker is not installed"
        return 1
    fi
}

# Function to check if Docker daemon is running
check_docker_running() {
    if docker info >/dev/null 2>&1; then
        echo "✓ Docker daemon is running"
        return 0
    else
        echo "⚠ Docker daemon is not running or not accessible"
        return 1
    fi
}

# Function to configure APT repository for Docker
configure_docker_apt_repo() {
    echo "Configuring Docker APT repository..."
    
    # Update package index
    sudo apt-get update
    
    # Install packages to allow apt to use a repository over HTTPS
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    sudo apt-get update
    
    echo "✓ Docker APT repository configured"
}

# Function to add user to docker group
configure_docker_user() {
    local current_user="${USER:-$(whoami)}"
    
    echo "Configuring Docker user permissions..."
    
    # Check if docker group exists
    if getent group docker >/dev/null 2>&1; then
        echo "✓ Docker group exists"
    else
        echo "Creating docker group..."
        sudo groupadd docker
        echo "✓ Docker group created"
    fi
    
    # Check if user is already in docker group
    if groups "$current_user" | grep -q '\bdocker\b'; then
        echo "✓ User '$current_user' is already in docker group"
    else
        echo "Adding user '$current_user' to docker group..."
        sudo usermod -aG docker "$current_user"
        echo "✓ User '$current_user' added to docker group"
        echo "⚠ You may need to log out and back in for group changes to take effect"
    fi
}

# Function to configure Docker daemon settings for Debian
configure_docker_daemon() {
    echo "Configuring Docker daemon settings for Debian..."
    
    local daemon_config_dir="/etc/docker"
    local daemon_config_file="$daemon_config_dir/daemon.json"
    
    # Create docker config directory if it doesn't exist
    if [ ! -d "$daemon_config_dir" ]; then
        echo "Creating Docker configuration directory..."
        sudo mkdir -p "$daemon_config_dir"
    fi
    
    # Debian-specific daemon configuration
    local daemon_config='{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "features": {
    "buildkit": true
  }
}'
    
    # Check if daemon.json already exists
    if [ -f "$daemon_config_file" ]; then
        echo "⚠ Docker daemon configuration already exists: $daemon_config_file"
        echo "Current configuration:"
        sudo cat "$daemon_config_file" | head -10
        echo
        read -p "Do you want to backup and replace it? (y/n): " replace_config
        case $replace_config in
            [Yy]*)
                echo "Backing up existing configuration..."
                sudo cp "$daemon_config_file" "$daemon_config_file.backup.$(date +%Y%m%d_%H%M%S)"
                echo "$daemon_config" | sudo tee "$daemon_config_file" > /dev/null
                echo "✓ Docker daemon configuration updated"
                ;;
            *)
                echo "Keeping existing configuration"
                ;;
        esac
    else
        echo "Creating Docker daemon configuration..."
        echo "$daemon_config" | sudo tee "$daemon_config_file" > /dev/null
        echo "✓ Docker daemon configuration created"
    fi
}

# Function to configure UFW firewall for Docker (Debian/Ubuntu specific)
configure_ufw_for_docker() {
    echo "Configuring UFW firewall for Docker..."
    
    if command -v ufw >/dev/null 2>&1; then
        # Check if UFW is active
        if sudo ufw status | grep -q "Status: active"; then
            echo "UFW is active, configuring Docker rules..."
            
            # Allow Docker daemon
            sudo ufw allow 2376/tcp comment 'Docker daemon'
            
            # Allow Docker Swarm (if needed)
            sudo ufw allow 2377/tcp comment 'Docker Swarm cluster management'
            sudo ufw allow 7946/tcp comment 'Docker Swarm node communication TCP'
            sudo ufw allow 7946/udp comment 'Docker Swarm node communication UDP'
            sudo ufw allow 4789/udp comment 'Docker Swarm overlay network'
            
            # Configure UFW to work with Docker
            local ufw_docker_rules='
# Docker integration
*filter
:ufw-user-forward - [0:0]
:DOCKER-USER - [0:0]
-A DOCKER-USER -j ufw-user-forward
-A DOCKER-USER -j RETURN
COMMIT'
            
            if ! grep -q "DOCKER-USER" /etc/ufw/after.rules; then
                echo "Adding Docker rules to UFW..."
                echo "$ufw_docker_rules" | sudo tee -a /etc/ufw/after.rules > /dev/null
                sudo ufw reload
                echo "✓ UFW configured for Docker"
            else
                echo "✓ UFW already configured for Docker"
            fi
        else
            echo "✓ UFW is not active, no firewall configuration needed"
        fi
    else
        echo "✓ UFW not installed, no firewall configuration needed"
    fi
}

# Function to enable and start Docker service
configure_docker_service() {
    echo "Configuring Docker service..."
    
    # Enable Docker service
    sudo systemctl enable docker
    
    # Enable Docker socket
    sudo systemctl enable docker.socket
    
    # Start Docker service
    sudo systemctl start docker
    
    # Check service status
    if sudo systemctl is-active --quiet docker; then
        echo "✓ Docker service is running"
    else
        echo "⚠ Docker service failed to start"
        sudo systemctl status docker --no-pager -l
    fi
}

# Function to configure Docker Compose for Debian
configure_docker_compose_debian() {
    echo "Configuring Docker Compose for Debian..."
    
    if command -v docker-compose >/dev/null 2>&1; then
        echo "✓ Docker Compose is installed: $(docker-compose --version)"
    elif docker compose version >/dev/null 2>&1; then
        echo "✓ Docker Compose (plugin) is available: $(docker compose version)"
    else
        echo "Installing Docker Compose..."
        
        # Install Docker Compose plugin (recommended method)
        sudo apt-get update
        sudo apt-get install -y docker-compose-plugin
        
        # Verify installation
        if docker compose version >/dev/null 2>&1; then
            echo "✓ Docker Compose plugin installed successfully"
        else
            echo "Installing standalone Docker Compose as fallback..."
            # Install standalone docker-compose
            sudo apt-get install -y docker-compose
            
            if command -v docker-compose >/dev/null 2>&1; then
                echo "✓ Docker Compose installed successfully"
            else
                echo "❌ Docker Compose installation failed"
            fi
        fi
    fi
}

# Function to test Docker installation
test_docker() {
    echo "Testing Docker installation..."
    
    if docker run --rm hello-world >/dev/null 2>&1; then
        echo "✓ Docker test successful"
    else
        echo "❌ Docker test failed"
        echo "Attempting to run test with more output..."
        docker run --rm hello-world
    fi
}

# Function to optimize Docker for Debian
optimize_docker_debian() {
    echo "Optimizing Docker for Debian..."
    
    # Configure log rotation
    local logrotate_config='/etc/logrotate.d/docker'
    if [ ! -f "$logrotate_config" ]; then
        echo "Configuring Docker log rotation..."
        sudo tee "$logrotate_config" > /dev/null << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=1M
    missingok
    delaycompress
    copytruncate
}
EOF
        echo "✓ Docker log rotation configured"
    else
        echo "✓ Docker log rotation already configured"
    fi
    
    # Set appropriate limits
    local limits_config='/etc/security/limits.d/docker.conf'
    if [ ! -f "$limits_config" ]; then
        echo "Configuring Docker resource limits..."
        sudo tee "$limits_config" > /dev/null << 'EOF'
# Docker resource limits
*               soft    nofile          65536
*               hard    nofile          65536
root            soft    nofile          65536
root            hard    nofile          65536
*               soft    memlock         unlimited
*               hard    memlock         unlimited
EOF
        echo "✓ Docker resource limits configured"
    else
        echo "✓ Docker resource limits already configured"
    fi
}

# Function to display Docker information
show_docker_info() {
    echo
    echo "Docker Configuration Summary (Debian):"
    echo "======================================"
    
    if command -v docker >/dev/null 2>&1; then
        echo "Docker Version: $(docker --version)"
        if docker info >/dev/null 2>&1; then
            echo "Docker Root Dir: $(docker info --format '{{.DockerRootDir}}')"
            echo "Storage Driver: $(docker info --format '{{.Driver}}')"
            echo "Logging Driver: $(docker info --format '{{.LoggingDriver}}')"
            echo "Cgroup Driver: $(docker info --format '{{.CgroupDriver}}')"
        fi
    fi
    
    if command -v docker-compose >/dev/null 2>&1; then
        echo "Docker Compose: $(docker-compose --version)"
    elif docker compose version >/dev/null 2>&1; then
        echo "Docker Compose: $(docker compose version)"
    fi
    
    echo "OS Release: $(lsb_release -ds)"
    echo "Kernel Version: $(uname -r)"
    echo "Current User: $(whoami)"
    echo "User Groups: $(groups)"
}

# Main execution
main() {
    echo "Starting Docker configuration for Debian/Ubuntu..."
    echo
    
    # Load configuration
    load_config
    
    # Check if Docker is installed
    if ! check_docker_installed; then
        echo "❌ Docker must be installed before configuration"
        echo "Please run install_docker.debian.sh first."
        exit 1
    fi
    
    # Configure Docker components
    configure_docker_user
    echo
    
    configure_docker_daemon
    echo
    
    configure_ufw_for_docker
    echo
    
    configure_docker_service
    echo
    
    configure_docker_compose_debian
    echo
    
    optimize_docker_debian
    echo
    
    # Check if Docker is running after configuration
    if check_docker_running; then
        test_docker
    else
        echo "⚠ Docker daemon is not running. Please restart Docker service."
        echo "Try: sudo systemctl restart docker"
    fi
    
    echo
    show_docker_info
    
    echo
    echo "Docker configuration for Debian completed!"
    echo
    echo "Next steps:"
    echo "1. If you were added to the docker group, log out and back in"
    echo "2. Verify Docker works: docker run hello-world"
    echo "3. Continue with OpenProject deployment"
    echo "4. For production use, consider configuring Docker registry mirrors"
}

# Run main function
main "$@"