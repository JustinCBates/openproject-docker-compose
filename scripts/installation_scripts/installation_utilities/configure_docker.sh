#!/bin/bash

# configure_docker.sh - Docker Configuration Utility
# Configures Docker daemon settings, user permissions, and service management
# Part of the OpenProject deployment framework

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../interactive_config.cfg"

echo "=========================================="
echo "Docker Configuration Utility"
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

# Function to configure Docker daemon settings
configure_docker_daemon() {
    echo "Configuring Docker daemon settings..."
    
    local daemon_config_dir="/etc/docker"
    local daemon_config_file="$daemon_config_dir/daemon.json"
    
    # Create docker config directory if it doesn't exist
    if [ ! -d "$daemon_config_dir" ]; then
        echo "Creating Docker configuration directory..."
        sudo mkdir -p "$daemon_config_dir"
    fi
    
    # Basic daemon configuration
    local daemon_config='{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
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

# Function to enable and start Docker service
configure_docker_service() {
    echo "Configuring Docker service..."
    
    # Check if systemd is available
    if command -v systemctl >/dev/null 2>&1; then
        echo "Enabling Docker service..."
        sudo systemctl enable docker
        
        echo "Starting Docker service..."
        sudo systemctl start docker
        
        # Check service status
        if sudo systemctl is-active --quiet docker; then
            echo "✓ Docker service is running"
        else
            echo "⚠ Docker service failed to start"
            sudo systemctl status docker --no-pager -l
        fi
    else
        echo "⚠ systemctl not available. Please manually start Docker service."
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

# Function to configure Docker Compose
configure_docker_compose() {
    echo "Checking Docker Compose..."
    
    if command -v docker-compose >/dev/null 2>&1; then
        echo "✓ Docker Compose is installed: $(docker-compose --version)"
    elif docker compose version >/dev/null 2>&1; then
        echo "✓ Docker Compose (plugin) is available: $(docker compose version)"
    else
        echo "⚠ Docker Compose not found"
        echo "Installing Docker Compose..."
        
        # Install Docker Compose based on OS family
        case "${OS_FAMILY:-debian}" in
            debian)
                sudo apt-get update
                sudo apt-get install -y docker-compose-plugin
                ;;
            redhat)
                sudo dnf install -y docker-compose-plugin
                ;;
            arch)
                sudo pacman -S --noconfirm docker-compose
                ;;
            suse)
                sudo zypper install -y docker-compose
                ;;
            *)
                echo "⚠ Unknown OS family. Please install Docker Compose manually."
                ;;
        esac
        
        # Verify installation
        if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
            echo "✓ Docker Compose installed successfully"
        else
            echo "❌ Docker Compose installation failed"
        fi
    fi
}

# Function to display Docker information
show_docker_info() {
    echo
    echo "Docker Configuration Summary:"
    echo "============================"
    
    if command -v docker >/dev/null 2>&1; then
        echo "Docker Version: $(docker --version)"
        if docker info >/dev/null 2>&1; then
            echo "Docker Root Dir: $(docker info --format '{{.DockerRootDir}}')"
            echo "Storage Driver: $(docker info --format '{{.Driver}}')"
            echo "Logging Driver: $(docker info --format '{{.LoggingDriver}}')"
        fi
    fi
    
    if command -v docker-compose >/dev/null 2>&1; then
        echo "Docker Compose: $(docker-compose --version)"
    elif docker compose version >/dev/null 2>&1; then
        echo "Docker Compose: $(docker compose version)"
    fi
    
    echo "Current User: $(whoami)"
    echo "User Groups: $(groups)"
}

# Main execution
main() {
    echo "Starting Docker configuration..."
    echo
    
    # Load configuration
    load_config
    
    # Check if Docker is installed
    if ! check_docker_installed; then
        echo "❌ Docker must be installed before configuration"
        echo "Please run the appropriate install_docker script for your OS first."
        exit 1
    fi
    
    # Configure Docker components
    configure_docker_user
    echo
    
    configure_docker_daemon
    echo
    
    configure_docker_service
    echo
    
    configure_docker_compose
    echo
    
    # Check if Docker is running after configuration
    if check_docker_running; then
        test_docker
    else
        echo "⚠ Docker daemon is not running. Please restart Docker service."
    fi
    
    echo
    show_docker_info
    
    echo
    echo "Docker configuration completed!"
    echo
    echo "Next steps:"
    echo "1. If you were added to the docker group, log out and back in"
    echo "2. Verify Docker works: docker run hello-world"
    echo "3. Continue with OpenProject deployment"
}

# Run main function
main "$@"