#!/bin/bash
# Finalize and save configuration

run_finalize() {
    # Clear the terminal for interactive runs (only when stdout is a TTY)
    if [ -t 1 ]; then
        clear
    fi

    echo
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

    # Persist remaining keys only if the user applied defaults explicitly.
    if [ "${SHOULD_PERSIST_DEFAULTS:-0}" != "1" ]; then
        echo "(Skipping persistence of defaults into ${DEPLOY_CONFIG:-interactive_config.cfg}; user did not accept applying defaults)"
    else
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
            current_val=$(get_cfg "$key" || true)
            if [ -n "$current_val" ]; then
                continue
            fi
            # Use the shell variable named by the key if present (fall back safely)
            val=""
            if [ "${!key+set}" = "set" ]; then
                val="${!key}"
            else
                val=""
            fi
            if [ -n "$val" ]; then
                save_config "$key" "$val" >/dev/null 2>&1 || true
            fi
        done
    fi

    # Print final canonical configuration
    echo
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

    critical=(ENVIRONMENT_TYPE OS_FAMILY OPENPROJECT_HOST_NAME OPENPROJECT_HTTPS PROXY_HTTPS_REDIRECT DOMAIN_NAME DEFAULT_DBADMIN_PASSWORD DATABASE_STORAGE_TYPE NAMESPACE)

    strip_ansi() { printf "%s" "$1" | awk '{ gsub(/\033\[[0-9;]*[mK]/, ""); print }'; }
    visible_length() { local v; v=$(strip_ansi "$1" | wc -m | tr -d ' '); if [ -z "$v" ]; then v=0; fi; printf "%s" "$v"; }
    pad_to() { local s="$1"; local w=$2; local len; len=$(visible_length "$s"); if [ -z "$len" ]; then len=0; fi; if [ "$len" -lt "$w" ]; then local pad=$((w - len)); printf "%s%*s" "$s" "$pad" ""; else printf "%s" "$s"; fi; }

    printf "%s\n" "Final configuration:"
    printf "%s\n" "---------------------------------------------"

    PERSIST_ALLOWED=0
    if [ "${DEPLOY_CONFIG_EXISTS_AT_START:-0}" = "1" ] || [ "${SHOULD_PERSIST_DEFAULTS:-0}" = "1" ]; then
        PERSIST_ALLOWED=1
    fi

    for k in "${keys[@]}"; do
        marker=" "
        for c in "${critical[@]}"; do
            if [ "$c" = "$k" ]; then marker="*"; break; fi
        done

        if [ "$PERSIST_ALLOWED" -eq 1 ]; then
            v=$(get_effective "$k" 2>/dev/null || true)
        else
            v=$(get_cfg "$k" 2>/dev/null || true)
        fi

        if [ -n "$v" ]; then
            raw_disp="\"$v\""
        else
            raw_disp=""
        fi

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

        # OS_FAMILY special case: mark if configured OS differs from detected default
        if [ "$k" = "OS_FAMILY" ]; then
            defv=""
            if [ -f "${SCRIPT_DIR:-.}/interactive_config.cfg.defaults" ]; then
                defv=$(grep -E "^${k}=" "${SCRIPT_DIR:-.}/interactive_config.cfg.defaults" 2>/dev/null | head -1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' || true)
            fi
            if [ "$PERSIST_ALLOWED" -eq 1 ]; then
                cfg_compare="$v"
            else
                cfg_compare=$(get_cfg "$k" 2>/dev/null || true)
            fi
            if [ -n "$cfg_compare" ] && [ -n "$defv" ] && [ "$cfg_compare" != "$defv" ]; then
                if [ "${COLOR_ENABLED:-0}" = "1" ]; then marker_colored="${YELLOW}*${RESET}"; value_colored="${YELLOW}${raw_disp}${RESET}"; else marker_colored="*"; fi
            fi
        fi

        col1=$(pad_to "${marker_colored} ${k}" 28)
        col2=$(pad_to "$value_colored" 36)
        printf "%s %s\n" "$col1" "$col2"
    done

    echo

    # Validate required keys
    missing=()
    invalid=()
    for k in OPENPROJECT_HOST_NAME DOMAIN_NAME OPENPROJECT_HTTPS OPENPROJECT_TAG; do
        if [ "$PERSIST_ALLOWED" -eq 1 ]; then
            v=$(get_effective "$k" 2>/dev/null || true)
        else
            v=$(get_cfg "$k" 2>/dev/null || true)
        fi
        if [ -z "$v" ]; then missing+=("$k"); fi
    done

    def_os=""
    if [ -f "${SCRIPT_DIR:-.}/interactive_config.cfg.defaults" ]; then
        def_os=$(grep -E "^OS_FAMILY=" "${SCRIPT_DIR:-.}/interactive_config.cfg.defaults" 2>/dev/null | head -1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' || true)
    fi
    if [ "$PERSIST_ALLOWED" -eq 1 ]; then
        cfg_os=$(get_effective "OS_FAMILY" 2>/dev/null || true)
    else
        cfg_os=$(get_cfg "OS_FAMILY" 2>/dev/null || true)
    fi
    if [ -n "$cfg_os" ] && [ -n "$def_os" ] && [ "$cfg_os" != "$def_os" ]; then
        invalid+=("OS_FAMILY")
    fi

    if [ "${#missing[@]}" -ne 0 ]; then
        if [ "${COLOR_ENABLED:-0}" = "1" ]; then
            printf "%b\n" "${RED}✗ Configuration missing required keys: ${missing[*]}${RESET}"
        else
            printf "%s\n" "✗ Configuration missing required keys: ${missing[*]}"
        fi
    fi

    if [ "${#invalid[@]}" -ne 0 ]; then
        details=()
        for ik in "${invalid[@]}"; do
            if [ "$ik" = "OS_FAMILY" ]; then
                details+=("OS_FAMILY (configured=${cfg_os}, detected=${def_os})")
            else
                details+=("$ik")
            fi
        done
        if [ "${COLOR_ENABLED:-0}" = "1" ]; then
            printf "%b\n" "${YELLOW}⚠ Configuration has invalid values: ${details[*]}${RESET}"
        else
            printf "%s\n" "⚠ Configuration has invalid values: ${details[*]}"
        fi
    fi

    if [ "${#missing[@]}" -eq 0 ] && [ "${#invalid[@]}" -eq 0 ]; then
        if [ "${COLOR_ENABLED:-0}" = "1" ]; then
            printf "%b\n" "${GREEN}✓ Configuration appears valid: required keys present.${RESET}"
        else
            printf "%s\n" "✓ Configuration appears valid: required keys present."
        fi
    fi
}
