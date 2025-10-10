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

    # Note: summary printed by interactive_config.sh before offering interactive edit
    if declare -f pop_sigint_trap >/dev/null 2>&1; then
        pop_sigint_trap
    fi
}
