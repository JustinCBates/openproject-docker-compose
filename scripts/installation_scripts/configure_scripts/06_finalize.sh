#!/bin/bash
# Finalize and save configuration

run_finalize() {
    if declare -f init_install_defaults >/dev/null 2>&1; then
        init_install_defaults
    fi
    cfg_saved_body=$(cat <<EOF
Configuration saved to: $DEPLOY_CONFIG
EOF
)
    section "Configuration saved to: $DEPLOY_CONFIG" "$cfg_saved_body"
    echo
    echo "To deploy OpenProject, run:"
    echo "  ./scripts/installation_scripts/deploy.sh"
    echo
    echo "Or use the utility scripts manually:"
    echo "  1. ./scripts/installation_scripts/installation_utilities/configure_docker.sh"
    echo "  2. ./scripts/installation_scripts/installation_utilities/build_stack.sh"
    echo
    echo "Configuration complete!"
    echo
}
