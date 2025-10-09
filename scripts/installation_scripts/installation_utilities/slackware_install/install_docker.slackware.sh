#!/bin/bash

# Docker Installation Script for Slackware Family
# Supports: Slackware Linux

set -e  # Exit on any error

echo "=========================================="
echo "Docker Installation - Slackware Family"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source UI helpers if available
if [ -f "$SCRIPT_DIR/../common/common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common/common_ui.sh"
fi
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../../interactive_config.cfg"
DEFAULTS_FILE="$SCRIPT_DIR/../../interactive_config.cfg.defaults"
if [ -f "$DEFAULTS_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$DEFAULTS_FILE"
    set +a
fi

# Load configuration if available
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script requires root privileges. Please run as root."
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
        
        # Restart Docker service if running
        if pgrep dockerd > /dev/null; then
            echo "Restarting Docker daemon to apply configuration..."
            pkill dockerd
            sleep 2
            /usr/local/bin/dockerd &
        fi
    fi
    
    echo
    echo "Docker configuration completed successfully!"
    echo "Current versions:"
    /usr/local/bin/docker --version
    /usr/local/bin/docker compose version
    echo
    exit 0
fi

echo "Installing Docker on Slackware system..."
echo "Note: This is a manual installation process for Slackware"
echo

# Check Slackware version
if [ -f /etc/slackware-version ]; then
    SLACK_VERSION=$(cat /etc/slackware-version)
    echo "Detected: $SLACK_VERSION"
else
    echo "⚠ Cannot detect Slackware version"
fi

# Create necessary directories
echo "Step 1: Creating Docker directories..."
mkdir -p /var/lib/docker
mkdir -p /etc/docker
mkdir -p /usr/local/bin

# Download Docker binary (static binary for compatibility)
echo "Step 2: Downloading Docker static binary..."
DOCKER_VERSION="24.0.7"  # Use a stable version
cd /tmp

# Download Docker static binary
curl -fsSL "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz

# Extract Docker binaries
echo "Step 3: Extracting Docker binaries..."
tar -xzf docker.tgz
cp docker/* /usr/local/bin/
chmod +x /usr/local/bin/docker*

# Clean up downloaded files
rm -rf docker docker.tgz

# Create Docker group
echo "Step 4: Creating docker group..."
groupadd docker 2>/dev/null || echo "Docker group already exists"

# Create Docker daemon configuration
echo "Step 5: Creating Docker daemon configuration..."
cat > /etc/docker/daemon.json << EOF
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2"
}
EOF

# Create Docker init script for Slackware
echo "Step 6: Creating Docker init script..."
cat > /etc/rc.d/rc.docker << 'EOF'
#!/bin/bash
# Docker daemon init script for Slackware

DOCKER_DAEMON=/usr/local/bin/dockerd
DOCKER_PIDFILE=/var/run/docker.pid

docker_start() {
    if [ -f $DOCKER_PIDFILE ]; then
        echo "Docker daemon already running"
        return
    fi
    
    echo "Starting Docker daemon..."
    $DOCKER_DAEMON --pidfile=$DOCKER_PIDFILE --detach
}

docker_stop() {
    if [ ! -f $DOCKER_PIDFILE ]; then
        echo "Docker daemon not running"
        return
    fi
    
    echo "Stopping Docker daemon..."
    kill $(cat $DOCKER_PIDFILE)
    rm -f $DOCKER_PIDFILE
}

docker_restart() {
    docker_stop
    sleep 2
    docker_start
}

case "$1" in
    start)
        docker_start
        ;;
    stop)
        docker_stop
        ;;
    restart)
        docker_restart
        ;;
    status)
        if [ -f $DOCKER_PIDFILE ]; then
            echo "Docker daemon is running (PID: $(cat $DOCKER_PIDFILE))"
        else
            echo "Docker daemon is not running"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
EOF

# Make init script executable
chmod +x /etc/rc.d/rc.docker

# Download and install Docker Compose
echo "Step 7: Installing Docker Compose..."
COMPOSE_VERSION="2.21.0"  # Use a stable version
curl -fsSL "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create symbolic link for docker compose (plugin style)
ln -sf /usr/local/bin/docker-compose /usr/local/bin/docker-compose-plugin

# Add Docker to system startup (rc.local)
echo "Step 8: Adding Docker to system startup..."
if ! grep -q "rc.docker start" /etc/rc.d/rc.local 2>/dev/null; then
    echo "" >> /etc/rc.d/rc.local
    echo "# Start Docker daemon" >> /etc/rc.d/rc.local
    echo "if [ -x /etc/rc.d/rc.docker ]; then" >> /etc/rc.d/rc.local
    echo "  /etc/rc.d/rc.docker start" >> /etc/rc.d/rc.local
    echo "fi" >> /etc/rc.d/rc.local
fi

# Make rc.local executable
chmod +x /etc/rc.d/rc.local

# Add current user to docker group (if SUDO_USER is set)
if [ -n "$SUDO_USER" ]; then
    echo "Step 9: Adding user '$SUDO_USER' to docker group..."
    usermod -aG docker "$SUDO_USER"
    echo "⚠ Note: User '$SUDO_USER' needs to log out and back in for group changes to take effect"
fi

# Start Docker daemon
echo "Step 10: Starting Docker daemon..."
/etc/rc.d/rc.docker start

# Wait a moment for daemon to start
sleep 3

# Verify Docker installation
echo "Step 11: Verifying Docker installation..."
/usr/local/bin/docker --version
/usr/local/bin/docker-compose --version

# Test Docker daemon
if /usr/local/bin/docker info > /dev/null 2>&1; then
    echo "✓ Docker daemon is running correctly"
else
    echo "⚠ Docker daemon may not be running properly"
    echo "Check with: /etc/rc.d/rc.docker status"
fi

echo
echo "=========================================="
echo "Docker Installation Completed!"
echo "=========================================="
echo
echo "Slackware-specific information:"
echo "- Docker binaries installed in: /usr/local/bin/"
echo "- Init script created: /etc/rc.d/rc.docker"
echo "- Start Docker: /etc/rc.d/rc.docker start"
echo "- Stop Docker: /etc/rc.d/rc.docker stop"
echo "- Check status: /etc/rc.d/rc.docker status"
echo
echo "Next steps:"
echo "1. If you added a user to the docker group, log out and back in"
echo "2. Test Docker with: docker run hello-world"
echo "3. Docker Compose is available as 'docker-compose'"
echo "4. Docker will start automatically on boot"
echo

if [ "$ENVIRONMENT_TYPE" = "production" ]; then
    echo "🚨 PRODUCTION NOTES:"
    echo "- Configure Docker daemon logging"
    echo "- Set up log rotation manually"
    echo "- Consider firewall configuration"
    echo "- Monitor Docker daemon with custom scripts"
    echo "- Regularly update Docker binaries manually"
fi