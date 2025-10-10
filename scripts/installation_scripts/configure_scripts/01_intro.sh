#!/bin/bash
# Interactive intro + preview merged

run_intro() {
    interactive_body=$(cat <<'EOF'
Follow a guided prompt sequence to gather deployment settings.
Press {RESET}<Enter>{BRONZE}{DIM} to accept any default shown.
Changes are saved to {RESET}interactive_config.cfg{BRONZE}{DIM}.
EOF
)
    supersection "Interactive Configuration:" "$interactive_body"

    # The preview is shown by run_preview() prior to prompting; keep run_intro
    # focused on the interactive intro content only.
}

# Print a concise summary of effective configuration and a simple validity check
print_config_summary() {
    # Prints a 3-column table: Variable | .cfg value | .cfg.defaults value
    echo
    echo "Configuration comparison:"
    echo
    # Columns: Variable (marked * if critical), .cfg, .cfg.defaults
    printf "%-28s %-36s %-36s\n" "Variable" ".cfg" ".cfg.defaults"
    printf "%s\n" "$(printf '%0.1s' "-"{1..100})"

    # Ordered canonical key list (matches previous outputs)
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
        PROXY_BIND_ADDRESS
        PROXY_HTTP_PORT
        PROXY_HTTPS_PORT
        PROXY_TLS_MODE
        RAILS_URL_ROOT
        DUCKDNS_TOKEN
    )

    # Mark critical keys (prepend '*' to the Variable column)
    # OpenProject tag and Git settings are explicitly NOT critical per request
    critical=(ENVIRONMENT_TYPE OS_FAMILY OPENPROJECT_HOST_NAME OPENPROJECT_HTTPS PROXY_HTTPS_REDIRECT DOMAIN_NAME DEFAULT_DBADMIN_PASSWORD DATABASE_STORAGE_TYPE NAMESPACE)

    defaults_file="${SCRIPT_DIR}/interactive_config.cfg.defaults"

    for k in "${keys[@]}"; do
        # Determine marker
        marker=" "
        for c in "${critical[@]}"; do
            if [ "$c" = "$k" ]; then marker="*"; break; fi
        done
        # Read .cfg value (unquoted)
        cfgv=$(get_cfg "$k" || true)
        if [ -n "$cfgv" ]; then raw_cfg_disp="\"$cfgv\""; else raw_cfg_disp=""; fi
        # Read defaults file raw value (strip surrounding quotes)
        defv=""
        if [ -f "$defaults_file" ]; then
            defv=$(grep -E "^${k}=" "$defaults_file" 2>/dev/null | head -1 | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' || true)
        fi
        if [ -n "$defv" ]; then raw_def_disp="\"$defv\""; else raw_def_disp=""; fi

        # Truncate plain-text values to keep table readable, then colorize
        truncate_plain() {
            local s="$1"; local n=$2
            if [ -z "$s" ]; then
                printf ""
            elif [ "${#s}" -le "$n" ]; then
                printf "%s" "$s"
            else
                printf "%s..." "${s:0:$((n-3))}"
            fi
        }

        cfg_trunc=$(truncate_plain "$raw_cfg_disp" 36)
        def_trunc=$(truncate_plain "$raw_def_disp" 36)

        # Color the .cfg value green when present
        if [ -n "$cfg_trunc" ]; then
            if [ "${COLOR_ENABLED:-0}" = "1" ]; then
                cfg_colored="${GREEN}${cfg_trunc}${RESET}"
            else
                cfg_colored="$cfg_trunc"
            fi
        else
            cfg_colored=""
        fi

        # Color the defaults green only when they match the .cfg value (and both non-empty)
        if [ -n "$def_trunc" ] && [ "$raw_def_disp" = "$raw_cfg_disp" ] && [ -n "$raw_cfg_disp" ]; then
            if [ "${COLOR_ENABLED:-0}" = "1" ]; then
                def_colored="${GREEN}${def_trunc}${RESET}"
            else
                def_colored="$def_trunc"
            fi
        else
            def_colored="$def_trunc"
        fi

        # Color the marker and cfg value depending on validity
        # Special case: if OS_FAMILY is set in .cfg and differs from the defaults
        # value that was detected, mark it yellow and color the .cfg value yellow.
        if [ "$marker" = "*" ]; then
            # OS_FAMILY override: highlight in yellow when cfg != default
            if [ "$k" = "OS_FAMILY" ] && [ -n "$cfgv" ] && [ -n "$defv" ] && [ "$cfgv" != "$defv" ]; then
                if [ "${COLOR_ENABLED:-0}" = "1" ]; then
                    marker_colored="${YELLOW}*${RESET}"
                    cfg_colored="${YELLOW}${cfg_trunc}${RESET}"
                else
                    marker_colored="*"
                    cfg_colored="$cfg_trunc"
                fi
            else
                valid=0
                if [ "$k" = "NAMESPACE" ]; then
                    valid=1
                else
                    # Valid if there's a value in the user's config
                    # or (a default exists AND the user has a persistent .cfg file)
                    if [ -n "$cfgv" ]; then
                        valid=1
                    elif [ -n "$defv" ]; then
                        # Determine if a persistent .cfg exists (DEPLOY_CONFIG may be set by the caller)
                        cfg_file="${DEPLOY_CONFIG:-${SCRIPT_DIR}/interactive_config.cfg}"
                        if [ -f "$cfg_file" ]; then
                            # If the key is absent from the .cfg file (empty), treat as invalid
                            # unless the user has explicitly set it. So only consider the default
                            # as valid when a persistent .cfg file is present to accept it.
                            valid=1
                        else
                            valid=0
                        fi
                    fi
                fi
                if [ "$valid" -eq 1 ]; then
                    if [ "${COLOR_ENABLED:-0}" = "1" ]; then
                        marker_colored="${GREEN}*${RESET}"
                    else
                        marker_colored="*"
                    fi
                else
                    if [ "${COLOR_ENABLED:-0}" = "1" ]; then
                        marker_colored="${RED}*${RESET}"
                    else
                        marker_colored="*"
                    fi
                fi
            fi
        else
            marker_colored=" "
        fi

        # Helpers to handle ANSI escape sequences so visible widths align
        strip_ansi() {
            # Remove common CSI ANSI sequences (e.g., \033[31m)
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

        col1=$(pad_to "${marker_colored} ${k}" 28)
        col2=$(pad_to "$cfg_colored" 36)
        col3=$(pad_to "$def_colored" 36)
        printf "%s %s %s\n" "$col1" "$col2" "$col3"
    done

    echo
    # Simple validity checks: required keys present and non-empty
    local missing=()
    for k in OPENPROJECT_HOST_NAME DOMAIN_NAME OPENPROJECT_HTTPS OPENPROJECT_TAG; do
        v=$(get_effective "$k" || true)
        if [ -z "$v" ]; then
            missing+=("$k")
        fi
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        echo "Config appears valid: required keys present."
        return 0
    else
        echo "Config missing or empty keys: ${missing[*]}"
        return 1
    fi
}

# Overwrite values in interactive_config.cfg with values from the defaults file
apply_defaults_to_cfg() {
    local defaults_file="${SCRIPT_DIR}/interactive_config.cfg.defaults"
    if [ ! -f "$defaults_file" ]; then
        echo "No defaults file found at $defaults_file"
        return 1
    fi
    # For each key in defaults, write into DEPLOY_CONFIG using save_config
    while IFS= read -r line; do
        # skip comments and blank lines
        case "$line" in
            ''|\#*) continue ;;
        esac
        key=$(printf "%s" "$line" | cut -d'=' -f1)
        val=$(printf "%s" "$line" | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//')
        # Use save_config to write (it will avoid empty writes)
        save_config "$key" "$val" >/dev/null 2>&1 || true
    done < "$defaults_file"
    return 0
}
