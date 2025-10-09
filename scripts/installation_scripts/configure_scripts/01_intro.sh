#!/bin/bash
# Interactive intro + preview merged

run_intro() {
    if declare -f init_install_defaults >/dev/null 2>&1; then
        init_install_defaults
    fi
    interactive_body=$(cat <<EOF
Follow a guided prompt sequence to gather deployment settings. 
Press <Enter> to accept any default shown. 
Changes are saved to interactive_config.cfg.
EOF
)
    supersection "Interactive Configuration:" "$interactive_body"

    # Inline preview (previously run_preview)
    local cfg_preview_body
    cfg_preview_body=$(cat <<'EOF'
Preview of the existing `interactive_config.cfg` (truncated). 
Confirm or update values in the following prompts.
EOF
)
    section "Current configuration preview:" "$cfg_preview_body"
    if [ -f "$DEPLOY_CONFIG" ]; then
        echo "Key settings from configuration:"
        if [ -s "$DEPLOY_CONFIG" ]; then
            sed -n '1,200p' "$DEPLOY_CONFIG" | sed -e '/^[[:space:]]*$/d' || echo "No previous configuration found"
        else
            echo "No previous configuration found"
        fi
    else
        echo "No previous configuration found"
    fi
    echo
}
