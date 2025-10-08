#!/bin/bash

# Docker Installation Script for Debian Family
# Supports: Debian, Ubuntu, Linux Mint, Raspbian

set -e  # Exit on any error

echo "=========================================="
echo "Docker Installation - Debian Family"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source UI helpers if available
if [ -f "$SCRIPT_DIR/../common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common_ui.sh"
fi
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"

# Load configuration if available
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges. Please run with sudo."
    exit 1
fi

# Function to check if Docker is installed and get version
check_docker_installation() {
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ -n "$DOCKER_VERSION" ]; then
            echo "Docker $DOCKER_VERSION is already installed"
            return 0
        fi
    fi
    return 1
}

# Function to check if Docker Compose is installed and get version
check_docker_compose_installation() {
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ -n "$COMPOSE_VERSION" ]; then
            echo "Docker Compose $COMPOSE_VERSION is already installed"
            return 0
        fi
    fi
    return 1
}

# Function to compare version numbers
version_greater_equal() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

echo "Checking Docker installation status..."
echo

# Set minimum required versions
MIN_DOCKER_VERSION="20.10.0"
MIN_COMPOSE_VERSION="2.0.0"

DOCKER_INSTALLED=false
COMPOSE_INSTALLED=false
DOCKER_CURRENT=false
COMPOSE_CURRENT=false

# Check Docker installation and version
if check_docker_installation; then
    DOCKER_INSTALLED=true
    if version_greater_equal "$DOCKER_VERSION" "$MIN_DOCKER_VERSION"; then
        DOCKER_CURRENT=true
        echo "✓ Docker version $DOCKER_VERSION meets minimum requirement ($MIN_DOCKER_VERSION)"
    else
        echo "⚠ Docker version $DOCKER_VERSION is below minimum requirement ($MIN_DOCKER_VERSION)"
    fi
else
    echo "✗ Docker is not installed"
fi

# Check Docker Compose installation and version
if check_docker_compose_installation; then
    COMPOSE_INSTALLED=true
    if version_greater_equal "$COMPOSE_VERSION" "$MIN_COMPOSE_VERSION"; then
        COMPOSE_CURRENT=true
        echo "✓ Docker Compose version $COMPOSE_VERSION meets minimum requirement ($MIN_COMPOSE_VERSION)"
    else
        echo "⚠ Docker Compose version $COMPOSE_VERSION is below minimum requirement ($MIN_COMPOSE_VERSION)"
    fi
else
    echo "✗ Docker Compose is not installed"
fi

echo

# Skip installation if both Docker and Compose are current
if [ "$DOCKER_CURRENT" = true ] && [ "$COMPOSE_CURRENT" = true ]; then
    echo "✓ Docker and Docker Compose are already installed with current versions."
    echo "Skipping installation and proceeding to service configuration..."
    echo
    
    # Jump to service configuration section
    # Enable and start Docker service
    echo "Step: Configuring Docker service..."
    systemctl enable docker
    systemctl start docker
    
    # Add user to docker group if specified
    if [ -n "$DOCKER_USER" ]; then
        echo "Adding user '$DOCKER_USER' to docker group..."
        usermod -aG docker "$DOCKER_USER"
        echo "Note: User '$DOCKER_USER' will need to log out and back in for group changes to take effect."
    fi
    
    # Configure Docker daemon if in server environment
    if [ "$ENVIRONMENT_TYPE" = "server" ]; then
        echo "Configuring Docker daemon for server environment..."
        mkdir -p /etc/docker
        
        # Create daemon.json with production settings
        cat > /etc/docker/daemon.json << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "live-restore": true,
    "userland-proxy": false,
    "no-new-privileges": true
}
EOF
        
        # Restart Docker to apply configuration
        systemctl restart docker
    fi
    
    # Configure firewall for Docker if needed
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        echo "Configuring UFW firewall for Docker..."
        # Allow Docker subnet
        ufw allow from 172.17.0.0/16
        # Allow Docker daemon
        ufw allow 2376/tcp
    fi
    
    echo
    echo "Docker configuration completed successfully!"
    echo "Current versions:"
    docker --version
    docker compose version
    echo
    exit 0
fi

echo "Installing Docker on Debian-based system..."
echo

# Update package index
echo "Step 1: Updating package index..."
apt update

# Install prerequisite packages
echo "Step 2: Installing prerequisite packages..."
apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Remove old Docker versions if they exist
echo "Step 3: Removing old Docker versions..."
apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
echo "Step 4: Adding Docker GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Detect distribution for repository URL
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        ubuntu)
            DOCKER_REPO="ubuntu"
            ;;
        debian)
            DOCKER_REPO="debian"
            ;;
        raspbian)
            DOCKER_REPO="raspbian"
            ;;
        linuxmint)
            # Linux Mint uses Ubuntu repositories
            DOCKER_REPO="ubuntu"
            # Get Ubuntu version that Mint is based on
            if [ -f /etc/upstream-release/lsb-release ]; then
                . /etc/upstream-release/lsb-release
                VERSION_CODENAME="$DISTRIB_CODENAME"
            fi
            ;;
        *)
            echo "⚠ Unsupported distribution: $ID. Trying Ubuntu repository..."
            DOCKER_REPO="ubuntu"
            ;;
    esac
else
    echo "⚠ Cannot detect distribution. Trying Ubuntu repository..."
    DOCKER_REPO="ubuntu"
fi

# Add Docker repository
echo "Step 5: Adding Docker repository for $DOCKER_REPO..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DOCKER_REPO \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index with Docker repository
echo "Step 6: Updating package index with Docker repository..."
apt update

# Install Docker Engine
echo "Step 7: Installing Docker Engine..."
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
echo "Step 8: Starting and enabling Docker service..."
systemctl start docker
systemctl enable docker

# Add current user to docker group (if not root)
if [ -n "$SUDO_USER" ]; then
    echo "Step 9: Adding user '$SUDO_USER' to docker group..."
    usermod -aG docker "$SUDO_USER"
    echo "⚠ Note: User '$SUDO_USER' needs to log out and back in for group changes to take effect"
fi

# Verify Docker installation
echo "Step 10: Verifying Docker installation..."
docker --version
docker compose version

echo
echo "=========================================="
echo "Docker Installation Completed Successfully!"
echo "=========================================="
echo
echo "Next steps:"
echo "1. If you added a user to the docker group, log out and back in"
echo "2. Test Docker with: docker run hello-world"
echo "3. Docker Compose is available as 'docker compose'"
echo

if [ "$ENVIRONMENT_TYPE" = "production" ]; then
    echo "🚨 PRODUCTION NOTES:"
    echo "- Configure Docker daemon logging"
    echo "- Set up Docker log rotation"
    echo "- Configure resource limits"
    echo "- Review security settings"
fi