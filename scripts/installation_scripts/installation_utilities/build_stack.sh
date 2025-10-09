#!/bin/bash

# build_stack.sh - Universal OpenProject Stack Builder
# Part of the OpenProject deployment framework

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Source UI helpers from common/ if available
if [ -f "$SCRIPT_DIR/../common/common_ui.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/../common/common_ui.sh"
fi
CONFIG_FILE="$SCRIPT_DIR/../interactive_config.cfg"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Parse common options
DRY_RUN=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        -n|--dry-run)
            DRY_RUN=1
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            # stop parsing on first non-option
            break
            ;;
    esac
done
export DRY_RUN

echo "=========================================="
echo "Universal OpenProject Stack Builder"
echo "=========================================="

# Function to load configuration
load_config() {
    local defaults_file="$SCRIPT_DIR/../interactive_config.cfg.defaults"
    if [ -f "$defaults_file" ]; then
        set -a
        # shellcheck source=/dev/null
        source "$defaults_file"
        set +a
    fi

    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        echo "✓ Configuration loaded from $(basename "$CONFIG_FILE")"

        # Validate required variables
        if [ -z "${OS_FAMILY:-}" ]; then
            echo "❌ OS_FAMILY not found in configuration"
            echo "Please run interactive_config.sh first to configure your environment."
            exit 1
        fi

        echo "✓ Detected OS Family: ${OS_FAMILY:-}"
    else
        echo "❌ Configuration file not found: $CONFIG_FILE"
        echo "Please run interactive_config.sh first to configure your environment."
        exit 1
    fi
}

# Function to validate prerequisites
validate_prerequisites() {
    echo "Validating prerequisites..."
    
    cd "$PROJECT_ROOT"
    
    # Check for .env file (should be created by configure_docker.sh)
    if [ ! -f ".env" ]; then
        echo "❌ .env file not found"
        echo "Please run configure_docker.sh first."
        exit 1
    fi
    
    # Check for docker-compose.override.yml (should be created by configure_docker.sh)
    if [ ! -f "docker-compose.override.yml" ]; then
        echo "❌ docker-compose.override.yml not found"
        echo "Please run configure_docker.sh first."
        exit 1
    fi
    
    # Check for base docker-compose.yml
    if [ ! -f "docker-compose.yml" ]; then
        echo "❌ docker-compose.yml not found in project root"
        exit 1
    fi
    
    echo "✓ All prerequisite files found"
}

# Function to validate OS-specific script exists
validate_os_script() {
    local os_family="$1"
    local os_script="$SCRIPT_DIR/${os_family}_install/build_stack.${os_family}.sh"
    
    if [ -f "$os_script" ] && [ -x "$os_script" ]; then
        echo "✓ OS-specific script found: build_stack.${os_family}.sh"
        return 0
    else
        echo "❌ OS-specific script not found or not executable: $os_script"
        return 1
    fi
}

# Function to delegate to OS-specific build
delegate_to_os_specific() {
    local os_family="$1"
    local os_script="$SCRIPT_DIR/${os_family}_install/build_stack.${os_family}.sh"
    
    echo "Delegating to OS-specific stack builder: $os_family"
    echo "Executing: $os_script"
    echo
    
    if "$os_script"; then
        echo
        echo "✓ OS-specific stack build completed successfully"
        return 0
    else
        echo
        echo "❌ OS-specific stack build failed"
        return 1
    fi
}

# Function to show OS support status
show_os_support() {
    echo "Supported OS Families:"
    echo "  ✓ debian    - Full implementation"
    echo "  ⚠ arch     - Stub implementation" 
    echo "  ⚠ redhat   - Stub implementation"
    echo "  ⚠ suse     - Stub implementation"
    echo "  ⚠ slackware - Stub implementation"
    echo
}

# Function to show file status
show_file_status() {
    echo "Configuration Files Status:"
    cd "$PROJECT_ROOT"
    
    if [ -f ".env" ]; then
        echo "  ✓ .env file exists"
    else
        echo "  ❌ .env file missing"
    fi
    
    if [ -f "docker-compose.yml" ]; then
        echo "  ✓ docker-compose.yml exists"
    else
        echo "  ❌ docker-compose.yml missing"
    fi
    
    if [ -f "docker-compose.override.yml" ]; then
        echo "  ✓ docker-compose.override.yml exists"
    else
        echo "  ❌ docker-compose.override.yml missing"
    fi
    
    echo
}

# Main execution
main() {
    echo "Starting universal OpenProject stack build process..."
    echo
    
    # Show OS support status
    show_os_support
    
    # Load configuration
    load_config
    echo
    
    # Show file status
    show_file_status
    
    # Validate prerequisites
    validate_prerequisites
    echo
    
    # Validate OS-specific script exists
    if ! validate_os_script "$OS_FAMILY"; then
        echo
        echo "Available OS families with scripts:"
        find "$SCRIPT_DIR" -name "*_install" -type d | while read -r dir; do
            os_name=$(basename "$dir" | sed 's/_install$//')
            script_path="$dir/build_stack.${os_name}.sh"
            if [ -f "$script_path" ]; then
                echo "  - $os_name"
            fi
        done
        exit 1
    fi
    
    echo
    
    # Delegate to OS-specific implementation
    if delegate_to_os_specific "$OS_FAMILY"; then
        echo
        echo "🎉 OpenProject stack build completed successfully!"
        echo "Your OpenProject instance should now be running."
    else
        echo
        echo "❌ OpenProject stack build failed"
        echo "Please check the OS-specific script output above for details."
        exit 1
    fi
}

# Run main function
main "$@"