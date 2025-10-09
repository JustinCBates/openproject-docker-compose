#!/bin/bash
# Preview helper for interactive configuration

run_preview() {

    local cfg_preview_body
    cfg_preview_body=$(cat <<'EOF'
Preview of the existing {RESET}interactive_config.cfg{BRONZE}{DIM}. 
Confirm or update values in the following prompts.
EOF
)
    local interactive_intro
    interactive_intro=$(cat <<'EOF'
    This script will help you deploy OpenProject using Docker Compose.
    You can press Enter to accept default values shown in brackets.
EOF
)
    supersection "OpenProject Interactive Deployment Script" "$interactive_intro"
    
    # Protect the preview output with a SIGINT handler to avoid leaving the
    # terminal in an odd state if the user interrupts while we write to the TTY.
    if declare -f push_sigint_trap >/dev/null 2>&1; then
        push_sigint_trap
    fi
    section "Current configuration preview:" "$cfg_preview_body"

    # Ensure defaults/initialization have been performed so current_* vars exist
    if ! declare -f init_install_defaults >/dev/null 2>&1; then
        # try sourcing common if not present
        COMMON_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/../common/common.sh"
        if [ -f "$COMMON_SH" ]; then
            # shellcheck source=/dev/null
            source "$COMMON_SH"
        fi
    fi
    if declare -f init_install_defaults >/dev/null 2>&1; then
        init_install_defaults
    fi

    echo "Key settings (effective values):"
    # Print merged values, prefer current_* variables populated by init_install_defaults
    printf "  DOMAIN_NAME=%s\n" "${current_domain:-$(get_cfg DOMAIN_NAME || true)}"
    printf "  OPENPROJECT_HOST_NAME=%s\n" "${current_host:-$(get_cfg OPENPROJECT_HOST_NAME || true)}"
    printf "  OPENPROJECT_HTTPS=%s\n" "${current_https:-$(get_cfg OPENPROJECT_HTTPS || true)}"
    printf "  OPENPROJECT_TAG=%s\n" "${current_tag:-$(get_cfg OPENPROJECT_TAG || true)}"
    printf "  NAMESPACE=%s\n" "${current_subdomain:-$(get_cfg NAMESPACE || true)}"
    echo
    if declare -f pop_sigint_trap >/dev/null 2>&1; then
        pop_sigint_trap
    fi
}
