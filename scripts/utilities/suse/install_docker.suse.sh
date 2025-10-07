#!/bin/bash

# Docker Installation Script for SUSE Family
# Supports: openSUSE Leap, openSUSE Tumbleweed, SLES

set -e  # Exit on any error

echo "=========================================="
echo "Docker Installation - SUSE Family"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../../deploy_interactive.cfg"

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
    elif command -v SuSEfirewall2 &> /dev/null; then
        echo "Configuring SuSEfirewall2 for Docker..."
        # Configure SuSE firewall for Docker
        echo "FW_TRUSTED_NETS=\"172.17.0.0/16\"" >> /etc/sysconfig/SuSEfirewall2
        SuSEfirewall2 restart
    fi
    
    echo
    echo "Docker configuration completed successfully!"
    echo "Current versions:"
    docker --version
    docker compose version
    echo
    exit 0
fi

echo "Installing Docker on SUSE-based system..."
echo

# Update package index
echo "Step 1: Updating package index..."
zypper refresh

# Install prerequisite packages
echo "Step 2: Installing prerequisite packages..."
zypper install -y curl

# Remove old Docker versions if they exist
echo "Step 3: Removing old Docker versions..."
zypper remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Detect SUSE distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        opensuse-leap)
            SUSE_VERSION="leap"
            VERSION_ID="$VERSION_ID"
            ;;
        opensuse-tumbleweed)
            SUSE_VERSION="tumbleweed"
            VERSION_ID="tumbleweed"
            ;;
        sles)
            SUSE_VERSION="sles"
            VERSION_ID="$VERSION_ID"
            ;;
        *)
            echo "⚠ Unsupported SUSE distribution: $ID"
            echo "Attempting installation with openSUSE Leap repository..."
            SUSE_VERSION="leap"
            VERSION_ID="15.4"
            ;;
    esac
else
    echo "⚠ Cannot detect SUSE distribution. Using openSUSE Leap..."
    SUSE_VERSION="leap"
    VERSION_ID="15.4"
fi

echo "Detected SUSE variant: $SUSE_VERSION $VERSION_ID"

# Add Docker repository
echo "Step 4: Adding Docker repository..."
if [ "$SUSE_VERSION" = "tumbleweed" ]; then
    # For Tumbleweed, use the Factory repository
    zypper addrepo https://download.opensuse.org/repositories/Virtualization:containers/openSUSE_Factory/Virtualization:containers.repo
else
    # For Leap and SLES
    case "$VERSION_ID" in
        15.*)
            zypper addrepo https://download.opensuse.org/repositories/Virtualization:containers/15.5/Virtualization:containers.repo
            ;;
        *)
            echo "⚠ Using default repository for version $VERSION_ID"
            zypper addrepo https://download.opensuse.org/repositories/Virtualization:containers/15.5/Virtualization:containers.repo
            ;;
    esac
fi

# Refresh repositories
echo "Step 5: Refreshing repositories..."
zypper refresh

# Install Docker
echo "Step 6: Installing Docker..."
zypper install -y docker docker-compose

# Alternative: Install Docker CE from official Docker repository
# This section is commented out but can be used if the above fails
# echo "Step 6 (Alternative): Installing Docker CE from official repository..."
# zypper install -y \
#     apt-transport-https \
#     ca-certificates \
#     curl \
#     gnupg
# 
# # Add Docker GPG key
# curl -fsSL https://download.docker.com/linux/sles/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
# 
# # Add Docker repository
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/sles $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
# 
# zypper refresh
# zypper install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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

# Configure firewall if SuSEfirewall2 or firewalld is running
if systemctl is-active --quiet SuSEfirewall2; then
    echo "Step 9: Configuring SuSEfirewall2 for Docker..."
    # Add Docker interface to trusted zone
    echo "DOCKER_INTERFACES=\"docker0\"" >> /etc/sysconfig/SuSEfirewall2
    systemctl restart SuSEfirewall2
elif systemctl is-active --quiet firewalld; then
    echo "Step 9: Configuring firewalld for Docker..."
    firewall-cmd --permanent --zone=trusted --add-interface=docker0 2>/dev/null || true
    firewall-cmd --permanent --zone=trusted --add-masquerade 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
fi

# Verify Docker installation
echo "Step 10: Verifying Docker installation..."
docker --version
if command -v docker-compose &> /dev/null; then
    docker-compose --version
else
    echo "Note: docker-compose may be available as 'docker compose'"
    docker compose version 2>/dev/null || echo "Docker Compose plugin not found"
fi

echo
echo "=========================================="
echo "Docker Installation Completed Successfully!"
echo "=========================================="
echo
echo "Next steps:"
echo "1. If you added a user to the docker group, log out and back in"
echo "2. Test Docker with: docker run hello-world"
echo "3. Docker Compose may be available as 'docker-compose' or 'docker compose'"
echo

if [ "$ENVIRONMENT_TYPE" = "production" ]; then
    echo "🚨 PRODUCTION NOTES:"
    echo "- Configure Docker daemon logging"
    echo "- Set up Docker log rotation"
    echo "- Configure firewall rules properly"
    echo "- Review AppArmor/SELinux settings if enabled"
fi