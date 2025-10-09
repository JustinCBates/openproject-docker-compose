#!/bin/bash
# Finalize and save configuration

run_finalize() {
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

    # Persist any remaining keys that were not explicitly saved by their owning utility.
    # This uses environment/exported variables (or variables populated by init_install_defaults)
    # as the source of truth for values not present in the user's interactive_config.cfg.
    remaining_keys=(
        "OPENPROJECT_HOST_NAME"
        "OPENPROJECT_HTTPS"
        "OPENPROJECT_TAG"
        "GIT_USERNAME"
        "GIT_EMAIL"
        "DOMAIN_NAME"
        "NAMESPACE"
        "ENVIRONMENT_TYPE"
        "OS_FAMILY"
    )

    for key in "${remaining_keys[@]}"; do
        # skip if already set in the config file
        if [ -n "$(get_cfg "$key")" ]; then
            continue
        fi

        # indirect expansion: use variable named like the key (exports from .cfg.defaults / env)
        val="${!key-}"
        if [ -n "$val" ]; then
            save_config "$key" "$val"
        fi
    done

    # Ensure we display the final config file to the user if it exists
    if [ -f "${DEPLOY_CONFIG:-scripts/installation_scripts/interactive_config.cfg}" ]; then
        echo
        echo "============================================================================================"
        echo "Configuration saved to: ${DEPLOY_CONFIG:-scripts/installation_scripts/interactive_config.cfg}"
        echo "============================================================================================"
        sed -n '1,240p' "${DEPLOY_CONFIG:-scripts/installation_scripts/interactive_config.cfg}"
        echo
    fi
}
