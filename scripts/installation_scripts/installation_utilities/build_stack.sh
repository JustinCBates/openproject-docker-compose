#!/bin/bash

# build_stack.sh - OpenProject Docker Stack Builder
# Builds, deploys, and manages the OpenProject Docker Compose stack
# Part of the OpenProject deployment framework

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../interactive_config.cfg"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=========================================="
echo "OpenProject Docker Stack Builder"
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

# Function to validate Docker and Docker Compose
validate_docker() {
    echo "Validating Docker environment..."
    
    # Check Docker installation
    if ! command -v docker >/dev/null 2>&1; then
        echo "❌ Docker is not installed"
        echo "Please install Docker first using the appropriate install script."
        exit 1
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker daemon is not running or not accessible"
        echo "Please start Docker daemon or check permissions."
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
        echo "Please install Docker Compose."
        exit 1
    fi
    
    echo "✓ Docker environment validated"
}

# Function to validate project files
validate_project_files() {
    echo "Validating OpenProject files..."
    
    cd "$PROJECT_ROOT"
    
    # Check for docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        echo "❌ docker-compose.yml not found in project root"
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

# Function to pull Docker images
pull_images() {
    echo "Pulling Docker images..."
    
    cd "$PROJECT_ROOT"
    
    # Pull images without starting containers
    $COMPOSE_CMD pull
    
    echo "✓ Docker images pulled successfully"
}

# Function to build custom images if needed
build_images() {
    echo "Building custom Docker images..."
    
    cd "$PROJECT_ROOT"
    
    # Check if there are any build contexts in docker-compose.yml
    if grep -q "build:" docker-compose.yml; then
        echo "Found build contexts, building images..."
        $COMPOSE_CMD build --no-cache
        echo "✓ Custom images built successfully"
    else
        echo "✓ No custom images to build"
    fi
}

# Function to create necessary directories
create_directories() {
    echo "Creating necessary directories..."
    
    cd "$PROJECT_ROOT"
    
    # Create directories that might be needed
    local dirs_to_create=(
        "data"
        "logs"
        "backups"
        "uploads"
    )
    
    for dir in "${dirs_to_create[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "✓ Created directory: $dir"
        fi
    done
    
    # Set proper permissions
    if [ -d "data" ]; then
        chmod 755 data
    fi
    
    echo "✓ Directories created and configured"
}

# Function to validate configuration
validate_configuration() {
    echo "Validating configuration..."
    
    cd "$PROJECT_ROOT"
    
    # Check if required environment variables are set
    local required_vars=(
        "OPENPROJECT_HOST_NAME"
        "OPENPROJECT_HTTPS"
        "TAG"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" .env; then
            echo "⚠ Missing configuration: $var"
        fi
    done
    
    # Validate admin password is set
    if [ -n "$DEFAULT_ADMIN_PASSWORD" ] && [ "$DEFAULT_ADMIN_PASSWORD" != "admin123" ]; then
        echo "✓ Custom admin password configured"
    else
        echo "⚠ Using default admin password (change after deployment)"
    fi
    
    echo "✓ Configuration validated"
}

# Function to start the stack
start_stack() {
    echo "Starting OpenProject stack..."
    
    cd "$PROJECT_ROOT"
    
    # Start services in detached mode
    $COMPOSE_CMD up -d
    
    echo "✓ OpenProject stack started"
}

# Function to check stack health
check_stack_health() {
    echo "Checking stack health..."
    
    cd "$PROJECT_ROOT"
    
    # Wait a moment for containers to start
    sleep 5
    
    # Check container status
    echo "Container status:"
    $COMPOSE_CMD ps
    
    # Check for any failed containers
    if $COMPOSE_CMD ps | grep -q "Exit"; then
        echo "⚠ Some containers have exited"
        echo "Checking logs for failed containers..."
        $COMPOSE_CMD logs --tail=20
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
    
    # Wait for service to be ready
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "$protocol://$host" | grep -q "200\|302\|401"; then
            echo "✓ OpenProject is responding at $protocol://$host"
            break
        else
            echo "Attempt $attempt/$max_attempts: Waiting for OpenProject to start..."
            sleep 10
            ((attempt++))
        fi
    done
    
    if [ $attempt -gt $max_attempts ]; then
        echo "⚠ OpenProject may not be fully ready yet"
        echo "Please check the logs and try accessing it manually"
    fi
}

# Function to show deployment summary
show_deployment_summary() {
    echo
    echo "Deployment Summary:"
    echo "=================="
    
    local host="${OPENPROJECT_HOST_NAME:-localhost}"
    local protocol="http"
    
    if [ "${OPENPROJECT_HTTPS:-false}" = "true" ]; then
        protocol="https"
    fi
    
    echo "OpenProject URL: $protocol://$host"
    echo "Environment: ${ENVIRONMENT_TYPE:-localdev}"
    
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
    
    cd "$PROJECT_ROOT"
    echo
    echo "Current stack status:"
    $COMPOSE_CMD ps
}

# Function to handle cleanup on exit
cleanup() {
    echo
    echo "Build process interrupted"
    cd "$PROJECT_ROOT"
    
    # Don't automatically stop containers on script exit unless they're in a bad state
    if $COMPOSE_CMD ps | grep -q "Exit"; then
        echo "Cleaning up failed containers..."
        $COMPOSE_CMD down
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Build and deploy the OpenProject Docker stack"
    echo
    echo "Options:"
    echo "  --pull-only     Only pull images, don't start stack"
    echo "  --build-only    Only build images, don't start stack"
    echo "  --no-pull       Skip pulling images"
    echo "  --no-build      Skip building custom images"
    echo "  --help          Show this help message"
    echo
    echo "Environment Variables:"
    echo "  OPENPROJECT_HOST_NAME    - Hostname for OpenProject"
    echo "  OPENPROJECT_HTTPS        - Enable HTTPS (true/false)"
    echo "  DEFAULT_ADMIN_PASSWORD   - Admin password for installation"
    echo "  ENVIRONMENT_TYPE         - Environment type (localdev/production/etc)"
}

# Main execution
main() {
    local pull_only=false
    local build_only=false
    local skip_pull=false
    local skip_build=false
    
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
    
    echo "Starting OpenProject stack build process..."
    echo
    
    # Load configuration
    load_config
    
    # Validate environment
    validate_docker
    validate_project_files
    validate_configuration
    
    # Create necessary directories
    create_directories
    
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
    echo "🎉 OpenProject stack deployment completed successfully!"
    echo
    
    # Disable cleanup trap since everything succeeded
    trap - EXIT
}

# Run main function with all arguments
main "$@"