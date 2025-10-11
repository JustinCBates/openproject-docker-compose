#!/bin/bash
# Finalize and save configuration

run_finalize() {
    # Clear the terminal for interactive runs (only when stdout is a TTY)
    if [ -t 1 ]; then
        clear
    fi

    # Show the exact values that will be used in the build (.env)
    if [ -f "${SCRIPT_DIR:-.}/../common/config_render.sh" ]; then
        # shellcheck source=/dev/null
        source "${SCRIPT_DIR:-.}/../common/config_render.sh"
    fi

    if type detect_deployment_values >/dev/null 2>&1; then
        DEFAULTS_FILE="${SCRIPT_DIR:-.}/interactive_config.cfg.defaults"
        detect_deployment_values "" "$DEFAULTS_FILE" "$DEPLOY_CONFIG"
        build_env=$(render_env)

        echo
        printf "%s\n" "Values that will be used in the build (.env):"
        printf "%s\n" "----------------------------------------"
        printf "%s\n" "$build_env" | sed 's/^/    /'

        # Validate required keys against the build_env
        missing=()
        for k in OPENPROJECT_HOST_NAME DOMAIN_NAME OPENPROJECT_HTTPS OPENPROJECT_TAG; do
            if ! printf "%s\n" "$build_env" | grep -q "^${k}=" ; then
                missing+=("$k")
            else
                val=$(printf "%s\n" "$build_env" | grep "^${k}=" | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//')
                if [ -z "$val" ]; then missing+=("$k"); fi
            fi
        done

        if [ "${#missing[@]}" -ne 0 ]; then
            if [ "${COLOR_ENABLED:-0}" = "1" ]; then
                printf "%b\n" "${RED}✗ Configuration missing required keys: ${missing[*]}${RESET}"
            else
                printf "%s\n" "✗ Configuration missing required keys: ${missing[*]}"
            fi
        else
            if [ "${COLOR_ENABLED:-0}" = "1" ]; then
                printf "%b\n" "${GREEN}✓ Configuration appears valid: required keys present.${RESET}"
            else
                printf "%s\n" "✓ Configuration appears valid: required keys present."
            fi
        fi
    else
        echo "⚠ Renderer unavailable; falling back to reading saved config file for display."
        if [ -f "$DEPLOY_CONFIG" ]; then
            echo
            printf "%s\n" "Configuration from ${DEPLOY_CONFIG}:"
            sed -n '1,200p' "$DEPLOY_CONFIG" | sed 's/^/    /'
        else
            echo "No configuration file found to display."
        fi
    fi
}
