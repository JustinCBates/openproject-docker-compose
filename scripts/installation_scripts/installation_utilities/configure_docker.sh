#!/bin/bash

# configure_docker.sh - Universal Docker Configuration Utility
# Part of the OpenProject deployment framework

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../interactive_config.cfg"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo "=========================================="
echo " Docker Configuration Utility"
echo "=========================================="

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "✓ Configuration loaded from $(basename "$CONFIG_FILE")"
        
        # Validate required variables
        if [ -z "$OS_FAMILY" ]; then
            echo "❌ OS_FAMILY not found in configuration"
            echo "Please run interactive_config.sh first to configure your environment."
            exit 1
        fi
        
        echo "✓ Detected OS Family: $OS_FAMILY"
    else
        echo "❌ Configuration file not found: $CONFIG_FILE"
        echo "Please run interactive_config.sh first to configure your environment."
        exit 1
    fi
}

# Function to validate OS-specific script exists
validate_os_script() {
    local os_family="$1"
    local os_script="$SCRIPT_DIR/${os_family}_install/configure_docker.${os_family}.sh"
    
    if [ -f "$os_script" ] && [ -x "$os_script" ]; then
        echo "✓ OS-specific script found: configure_docker.${os_family}.sh"
        return 0
    else
        echo "❌ OS-specific script not found or not executable: $os_script"
        return 1
    fi
}

# Function to delegate to OS-specific configuration
delegate_to_os_specific() {
    local os_family="$1"
    local os_script="$SCRIPT_DIR/${os_family}_install/configure_docker.${os_family}.sh"
    
    echo "Delegating to OS-specific configuration: $os_family"
    echo "Executing: $os_script"
    echo
    
    if "$os_script"; then
        echo
        echo "✓ OS-specific Docker configuration completed successfully"
        return 0
    else
        echo
        echo "❌ OS-specific Docker configuration failed"
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

# Main execution
main() {
    echo "Starting universal Docker configuration process..."
    echo
    
    # Show OS support status
    show_os_support
    
    # Load configuration
    load_config
    echo
    
    # Validate OS-specific script exists
    if ! validate_os_script "$OS_FAMILY"; then
        echo
        echo "Available OS families with scripts:"
        find "$SCRIPT_DIR" -name "*_install" -type d | while read -r dir; do
            os_name=$(basename "$dir" | sed 's/_install$//')
            script_path="$dir/configure_docker.${os_name}.sh"
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
        echo "🎉 Docker configuration completed successfully!"
        echo "Ready to proceed with build_stack.sh"
    else
        echo
        echo "❌ Docker configuration failed"
        echo "Please check the OS-specific script output above for details."
        exit 1
    fi
}

# Run main function
main "$@"