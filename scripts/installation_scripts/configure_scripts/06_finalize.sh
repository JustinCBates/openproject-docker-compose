#!/bin/bash
# Finalize and save configuration

run_finalize() {
    # Clear the terminal for interactive runs (only when stdout is a TTY)
    if [ -t 1 ]; then
        clear
    fi

    # Print a concise final summary (avoid duplicating the section header)
    echo
    # Simple validity checks: required keys present and non-empty
    missing=()
    for k in OPENPROJECT_HOST_NAME DOMAIN_NAME OPENPROJECT_HTTPS OPENPROJECT_TAG; do
        v=$(get_effective "$k" || true)
        if [ -z "$v" ]; then missing+=("$k"); fi
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        if [ "${COLOR_ENABLED:-0}" = "1" ]; then
            printf "%b\n" "${GREEN}✓ Configuration appears valid: required keys present.${RESET}"
        else
            printf "%s\n" "✓ Configuration appears valid: required keys present."
        fi
    else
        if [ "${COLOR_ENABLED:-0}" = "1" ]; then
            printf "%b\n" "${RED}✗ Configuration missing required keys: ${missing[*]}${RESET}"
        else
            printf "%s\n" "✗ Configuration missing required keys: ${missing[*]}"
        fi
    fi
    echo "============================================================================================"
    echo "Configuration saved to: ${DEPLOY_CONFIG:-scripts/installation_scripts/interactive_config.cfg}"
    echo "============================================================================================"
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
            # Persist silently here so final output remains a single coherent block
            save_config "$key" "$val" >/dev/null 2>&1
        fi
    done

    # Print a canonical, ordered view of the final configuration. Use the
    # same key ordering and validity rules as `print_config_summary`, but
    # display a single-column KEY="value" listing (no .cfg.defaults column).
    echo
    # Color and marker helpers similar to print_config_summary
    # Color tokens (match common_ui.sh defaults if present)
    GREEN=${GREEN:-"\033[32m"}
    RED=${RED:-"\033[31m"}
    YELLOW=${YELLOW:-"\033[33m"}
    RESET=${RESET:-"\033[0m"}
    COLOR_ENABLED=${COLOR_ENABLED:-1}

    keys=(
        OPENPROJECT_TAG
        GIT_USERNAME
        GIT_EMAIL
        ENVIRONMENT_TYPE
        OS_FAMILY
        OPENPROJECT_HOST_NAME
        OPENPROJECT_HTTPS
        PROXY_HTTPS_REDIRECT
        DOMAIN_NAME
        DEFAULT_DBADMIN_PASSWORD
        DATABASE_STORAGE_TYPE
        NAMESPACE
    )

    # Critical keys get a '*' marker (same set as intro)
    critical=(ENVIRONMENT_TYPE OS_FAMILY OPENPROJECT_HOST_NAME OPENPROJECT_HTTPS PROXY_HTTPS_REDIRECT DOMAIN_NAME DEFAULT_DBADMIN_PASSWORD DATABASE_STORAGE_TYPE NAMESPACE)

    # Helpers for ANSI-aware padding
    strip_ansi() {
        printf "%s" "$1" | awk '{ gsub(/\033\[[0-9;]*[mK]/, ""); print }'
    }
    visible_length() {
        local v
        v=$(strip_ansi "$1" | wc -m | tr -d ' ')
        if [ -z "$v" ]; then v=0; fi
        printf "%s" "$v"
    }
    pad_to() {
        local s="$1"; local w=$2; local len; len=$(visible_length "$s"); if [ -z "$len" ]; then len=0; fi
        if [ "$len" -lt "$w" ]; then local pad=$((w - len)); printf "%s%*s" "$s" "$pad" ""; else printf "%s" "$s"; fi
    }

    # Print header
    printf "%s\n" "Final configuration:"
    printf "%s\n" "---------------------------------------------"

    for k in "${keys[@]}"; do
        # Marker
        marker=" "
        for c in "${critical[@]}"; do
            if [ "$c" = "$k" ]; then marker="*"; break; fi
        done

        # Determine effective value
        v=$(get_effective "$k" || true)
        if [ -n "$v" ]; then raw_disp="\"$v\""; else raw_disp=""; fi

        # Color logic: critical keys show green marker when valid, red when missing.
        marker_colored="$marker"
        value_colored="$raw_disp"
        valid=0
        if [ "$k" = "NAMESPACE" ]; then
            valid=1
        else
            if [ -n "$v" ]; then valid=1; fi
        fi
        if [ "$marker" = "*" ]; then
            if [ "$valid" -eq 1 ]; then
                if [ "${COLOR_ENABLED:-0}" = "1" ]; then marker_colored="${GREEN}*${RESET}"; value_colored="${GREEN}${raw_disp}${RESET}"; else marker_colored="*"; fi
            else
                if [ "${COLOR_ENABLED:-0}" = "1" ]; then marker_colored="${RED}*${RESET}"; value_colored="${RED}${raw_disp}${RESET}"; else marker_colored="*"; fi
            fi
        fi

        # Special-case OS_FAMILY override: yellow when differs from detected default
        if [ "$k" = "OS_FAMILY" ]; then
            defv=""
            if [ -f "${SCRIPT_DIR}/interactive_config.cfg.defaults" ]; then
                defv=$(grep -E "^${k}=" "${SCRIPT_DIR}/interactive_config.cfg.defaults" 2>/dev/null | head -1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' || true)
            fi
            if [ -n "$v" ] && [ -n "$defv" ] && [ "$v" != "$defv" ]; then
                if [ "${COLOR_ENABLED:-0}" = "1" ]; then marker_colored="${YELLOW}*${RESET}"; value_colored="${YELLOW}${raw_disp}${RESET}"; else marker_colored="*"; fi
            fi
        fi

        col1=$(pad_to "${marker_colored} ${k}" 28)
        col2=$(pad_to "$value_colored" 36)
        printf "%s %s\n" "$col1" "$col2"
    done

    echo
}
