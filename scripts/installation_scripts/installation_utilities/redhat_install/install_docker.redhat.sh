#!/bin/bash

# Docker Installation Script for Red Hat Family
# Supports: RHEL, CentOS, Fedora, Rocky Linux, AlmaLinux

set -e  # Exit on any error

echo "=========================================="
echo "Docker Installation - Red Hat Family"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source UI helpers if available
if [ -f "$SCRIPT_DIR/../common/common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common/common_ui.sh"
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
    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        echo "Configuring firewalld for Docker..."
        # Allow Docker subnet
        firewall-cmd --permanent --zone=trusted --add-source=172.17.0.0/16
        # Add docker interface to trusted zone
        firewall-cmd --permanent --zone=trusted --add-interface=docker0
        firewall-cmd --reload
    fi
    
    echo
    echo "Docker configuration completed successfully!"
    echo "Current versions:"
    docker --version
    docker compose version
    echo
    exit 0
fi

echo "Installing Docker on Red Hat-based system..."
echo

# Detect package manager
if command -v dnf &> /dev/null; then
    PKG_MGR="dnf"
elif command -v yum &> /dev/null; then
    PKG_MGR="yum"
else
    echo "Error: Neither dnf nor yum package manager found"
    exit 1
fi

echo "Using package manager: $PKG_MGR"

# Update package index
echo "Step 1: Updating package index..."
$PKG_MGR update -y

# Install prerequisite packages
echo "Step 2: Installing prerequisite packages..."
$PKG_MGR install -y yum-utils device-mapper-persistent-data lvm2

# Remove old Docker versions if they exist
echo "Step 3: Removing old Docker versions..."
$PKG_MGR remove -y docker \
    docker-client \
    docker-client-latest \
    docker-common \
    docker-latest \
    docker-latest-logrotate \
    docker-logrotate \
    docker-engine \
    podman \
    runc 2>/dev/null || true

# Detect distribution for repository setup
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        rhel)
            DOCKER_REPO="rhel"
            ;;
        centos)
            DOCKER_REPO="centos"
            ;;
        fedora)
            DOCKER_REPO="fedora"
            ;;
        rocky)
            DOCKER_REPO="centos"  # Rocky uses CentOS repos
            ;;
        almalinux)
            DOCKER_REPO="centos"  # AlmaLinux uses CentOS repos
            ;;
        *)
            echo "⚠ Unsupported distribution: $ID. Trying CentOS repository..."
            DOCKER_REPO="centos"
            ;;
    esac
else
    echo "⚠ Cannot detect distribution. Trying CentOS repository..."
    DOCKER_REPO="centos"
fi

# Add Docker repository
echo "Step 4: Adding Docker repository for $DOCKER_REPO..."
if [ "$DOCKER_REPO" = "fedora" ]; then
    $PKG_MGR config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
else
    # For RHEL, CentOS, Rocky, AlmaLinux
    $PKG_MGR config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
fi

# For RHEL, enable additional repositories
if [ "$ID" = "rhel" ]; then
    echo "Step 5: Enabling additional RHEL repositories..."
    subscription-manager repos --enable=rhel-7-server-extras-rpms 2>/dev/null || \
    subscription-manager repos --enable=rhel-8-for-x86_64-appstream-rpms 2>/dev/null || \
    subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms 2>/dev/null || \
    echo "⚠ Could not enable additional repos (may not be needed)"
fi

# Install Docker Engine
echo "Step 6: Installing Docker Engine..."
$PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker service
echo "Step 7: Starting and enabling Docker service..."
systemctl start docker
systemctl enable docker

# Add current user to docker group (if not root)
if [ -n "$SUDO_USER" ]; then
    echo "Step 8: Adding user '$SUDO_USER' to docker group..."
    usermod -aG docker "$SUDO_USER"
    echo "⚠ Note: User '$SUDO_USER' needs to log out and back in for group changes to take effect"
fi

# Configure firewall if firewalld is running
if systemctl is-active --quiet firewalld; then
    echo "Step 9: Configuring firewalld for Docker..."
    firewall-cmd --permanent --zone=trusted --add-interface=docker0 2>/dev/null || true
    firewall-cmd --permanent --zone=trusted --add-masquerade 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
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
    echo "- Configure firewall rules properly"
    echo "- Review SELinux settings if enabled"
fi