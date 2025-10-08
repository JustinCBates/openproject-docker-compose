#!/bin/bash

# common_ui.sh - UI helpers that build on common.sh
# Location: scripts/installation_scripts/common/common_ui.sh

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$COMMON_DIR/common.sh"
if [ -f "$COMMON_SH" ]; then
    # shellcheck source=/dev/null
    source "$COMMON_SH"
fi

# Color helpers (ANSI escapes) and light UI helpers.
# These used to live in common.sh but belong here with other UI helpers.
RED=$'\e[31m'
# Bronze-ish color using 256-color escape (brown/bronze tone)
BRONZE=$'\e[38;5;136m'
# Keep YELLOW reserved for warnings
YELLOW=$'\e[33m'
RESET=$'\e[0m'
GREEN=$'\e[32m'
DIM=$'\e[2m'
# SUBDUED is a dimmed bronze for body text under headings
SUBDUED="${DIM}${BRONZE}"

# Determine whether colors should be enabled. This allows forcing colors
# by setting INSTALLER_FORCE_COLOR=1 in the environment (useful in some
# terminal wrappers), otherwise only enable when stdout is a TTY.
COLOR_ENABLED=0
# First, honor explicit forcing
if [ "${INSTALLER_FORCE_COLOR:-}" = "1" ]; then
    COLOR_ENABLED=1
fi

# Detect color support when not explicitly forced
if [ "$COLOR_ENABLED" -ne 1 ]; then
    if [ -t 1 ]; then
        # Prefer tput if available
        if command -v tput >/dev/null 2>&1; then
            ncolors=$(tput colors 2>/dev/null || echo 0)
            case "$ncolors" in
                ''|0) COLOR_SUPPORTED=0; COLOR_LEVEL=0 ;;
                [1-9]|1[0-5]) COLOR_SUPPORTED=1; COLOR_LEVEL=8 ;;
                16) COLOR_SUPPORTED=1; COLOR_LEVEL=16 ;;
                *) COLOR_SUPPORTED=1; COLOR_LEVEL=256 ;;
            esac
        else
            # Fallback to TERM heuristics
            if [ -n "${TERM:-}" ] && (echo "$TERM" | grep -Eiq 'color|ansi|xterm|screen|vt100'); then
                COLOR_SUPPORTED=1
                COLOR_LEVEL=8
            else
                COLOR_SUPPORTED=0
                COLOR_LEVEL=0
            fi
        fi
    else
        COLOR_SUPPORTED=0
        COLOR_LEVEL=0
    fi
    # Enable colors only if supported
    if [ "${COLOR_SUPPORTED:-0}" -eq 1 ]; then
        COLOR_ENABLED=1
    else
        COLOR_ENABLED=0
    fi
fi

# Export these so sourced scripts can inspect capabilities
export COLOR_ENABLED COLOR_SUPPORTED COLOR_LEVEL

# Print a red warning prefix followed by message
warn() {
    local msg="$*"
    # Use -e so color escapes are interpreted
    echo -e "${RED}⚠ WARNING:${RESET} ${msg}"
}

# Print a caution message in yellow (less severe than warn)
caution() {
    local msg="$*"
    echo -e "${YELLOW}⚠ Caution:${RESET} ${msg}"
}

# Print a non-fatal notice in bronze
note() {
    local msg="$*"
    echo -e "${BRONZE}NOTE:${RESET} ${msg}"
}

# Return a colored default value when stdout is a TTY
format_default() {
    local val="$1"
    if [ "${COLOR_ENABLED:-0}" = "1" ]; then
        printf "%b" "${GREEN}${val}${RESET}"
    else
        printf "%s" "$val"
    fi
}

# Section and supersection are UI helpers that render headings and optional
# multi-line bodies. They were previously defined in common.sh but belong
# here with the other UI helpers.
# Generic separator that renders headings and optional multi-line bodies.
# style: one of 'section', 'supersection', 'subsection'
separator() {
    local style="$1"
    local title="$2"
    local body="${3-}"
    local header_char="${4:-}"
    local foot_char="${5:-_}"
    local IFS=$'\n'

    # Terminal width detection
    local term_w=80
    if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
        local tw
        tw=$(tput cols 2>/dev/null || echo 0)
        if [ "$tw" -gt 0 ]; then
            term_w=$tw
        fi
    elif [ -n "${COLUMNS:-}" ] && [ "${COLUMNS:-0}" -gt 0 ]; then
        term_w=${COLUMNS}
    fi

    # Compute content width: max of title and any body lines
    local content_w=${#title}
    if [ -n "$body" ]; then
        for line in $body; do
            local l=${#line}
            if [ "$l" -gt "$content_w" ]; then
                content_w=$l
            fi
        done
    fi
    # Cap to terminal width
    if [ "$content_w" -gt "$term_w" ]; then
        content_w=$term_w
    fi

    # Determine header char defaults per style
    if [ -z "$header_char" ]; then
        case "$style" in
            supersection) header_char='#' ;;
            subsection) header_char='-' ;;
            *) header_char='=' ;;
        esac
    fi

    # Render header according to style (preserve blanks/padding)
    case "$style" in
        supersection)
            printf "\n\n\n"
            local header
            header=$(printf '%*s' "$content_w" '' | tr ' ' "$header_char")
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${header}${RESET}"
                printf "%b\n" "${YELLOW}${title}${RESET}"
                printf "%b\n" "${BRONZE}${header}${RESET}"
            else
                printf "%s\n" "$header"
                printf "%s\n" "$title"
                printf "%s\n" "$header"
            fi
            ;;
        subsection)
            printf "\n"
            local header
            header=$(printf '%*s' "$content_w" '' | tr ' ' "$header_char")
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${header}${RESET}"
                printf "%b\n" "${BRONZE}${title}${RESET}"
                printf "%b\n" "${BRONZE}${header}${RESET}"
            else
                printf "%s\n" "$header"
                printf "%s\n" "$title"
                printf "%s\n" "$header"
            fi
            ;;
        *)
            printf "\n\n"
            local header
            header=$(printf '%*s' "$content_w" '' | tr ' ' "$header_char")
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${header}${RESET}"
            else
                printf "%s\n" "$header"
            fi
            echo -e "${BRONZE}${title}${RESET}"
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${header}${RESET}"
            else
                printf "%s\n" "$header"
            fi
            ;;
    esac

    # Body and footer
    if [ -n "$body" ]; then
        local maxb=0
        for line in $body; do
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%s\n" "${SUBDUED}${line}${RESET}"
            else
                printf "%s\n" "$line"
            fi
            local l=${#line}
            if [ "$l" -gt "$maxb" ]; then
                maxb=$l
            fi
        done

        if [ "$maxb" -gt "$term_w" ]; then
            maxb=$term_w
        fi
        if [ "$maxb" -gt 0 ]; then
            local foot
            foot=$(printf '%*s' "$maxb" '' | tr ' ' "$foot_char")
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${foot}${RESET}"
            else
                printf '%s\n' "$foot"
            fi
        fi
    fi
}

# Backwards-compatible wrappers that preserve the original API and pass
# header/footer characters for each style (footer defaults to '_').
section() {
    separator "section" "$1" "${2-}" '=' '_'
}

supersection() {
    separator "supersection" "$1" "${2-}" '#' '_'
}

subsection() {
    separator "subsection" "$1" "${2-}" '-' '_'
}

# Prompt with default helper: prompt text, default, and variable name to set
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local varname="$3"
    local input

    if [ -n "$default" ]; then
        if [ -t 1 ] && [ -n "$GREEN" ]; then
            def_display="${GREEN}${default}${RESET}"
            printf "%s [%b]: " "$prompt" "$def_display"
        else
            printf "%s [%s]: " "$prompt" "$default"
        fi
        read input
        if [ -z "$input" ]; then
            input="$default"
        fi
    else
        printf "%s: " "$prompt"
        read input
    fi

    # Export into caller by evaluating assignment
    eval "$varname='$input'"
}

# Prompt helpers: validate yes/no and true/false inputs
validate_yn() {
    local prompt="$1"
    local default="$2"
    if [ -n "$default" ]; then
        while true; do
            if [ -t 1 ] && [ -n "$GREEN" ]; then
                def_display="${GREEN}${default}${RESET}"
                printf "%s (y/n) [%b]: " "$prompt" "$def_display"
            else
                printf "%s (y/n) [%s]: " "$prompt" "$default"
            fi
            read yn
            if [ -z "$yn" ]; then
                yn="$default"
            fi
            case $yn in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    else
        while true; do
            printf "%s (y/n): " "$prompt"
            read yn
            case $yn in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

validate_tf() {
    local prompt="$1"
    local default="$2"
    if [ -n "$default" ]; then
        while true; do
            if [ -t 1 ] && [ -n "$GREEN" ]; then
                def_display="${GREEN}${default}${RESET}"
                printf "%s (true/false) [%b]: " "$prompt" "$def_display"
            else
                printf "%s (true/false) [%s]: " "$prompt" "$default"
            fi
            read tf
            if [ -z "$tf" ]; then
                tf="$default"
            fi
            case $tf in
                [Tt]rue|[Tt] ) return 0;;
                [Ff]alse|[Ff] ) return 1;;
                * ) echo "Please answer true or false.";;
            esac
        done
    else
        while true; do
            printf "%s (true/false): " "$prompt"
            read tf
            case $tf in
                [Tt]rue|[Tt] ) return 0;;
                [Ff]alse|[Ff] ) return 1;;
                * ) echo "Please answer true or false.";;
            esac
        done
    fi
}

# Print a numbered list. Usage: numbered_list <default-number> "item 1" "item 2" ...
# The default-number item will be highlighted in green when colors are enabled.
numbered_list() {
    local default_num="$1"; shift || return 0
    local i=1
    local item
    for item in "$@"; do
        if [ "$i" = "$default_num" ] && [ "${COLOR_ENABLED:-0}" = "1" ]; then
            printf "%b\n" "  ${GREEN}${i}) ${item}${RESET}"
        else
            printf "%s\n" "  ${i}) ${item}"
        fi
        i=$((i+1))
    done
}

# Show a numbered list, prompt for a choice, validate, and return the selected
# Usage:
#   numbered_list_prompt <default_index> <out_var> <out_index_var?> "item 1" "item 2" ...
# Example:
#   numbered_list_prompt 2 CHOICE CHOICE_IDX "dev" "prod" "test"
# After call: CHOICE contains chosen string, CHOICE_IDX contains numeric index
numbered_list_prompt() {
    local default_arg="$1"; shift || return 1
    local out_var="$1"; shift || return 1
    local out_idx_var="${1:-}";
    if [ -n "$out_idx_var" ]; then
        shift || true
    fi

    # Remaining args are the list items
    local items=("$@")
    local count=${#items[@]}

    # If default_arg is not a number, treat it as a token and try to find
    # the index of the matching item. Extract tokens from items using the
    # same logic used later for selected items.
    local default_index=""
    local default_token=""
    if printf "%s" "$default_arg" | grep -Eq '^[0-9]+$'; then
        default_index="$default_arg"
    else
        default_token="$default_arg"
        # Normalize and search items for a matching token
        local i=1
        for it in "${items[@]}"; do
            local it_token
            it_token=$(printf "%s" "$it" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\s*-\s*/ - /')
            if printf "%s" "$it_token" | grep -q " - "; then
                it_token=$(printf "%s" "$it_token" | cut -d'-' -f1 | sed -e 's/[[:space:]]*$//')
            else
                it_token=$(printf "%s" "$it_token" | awk '{print $1}')
            fi
            if [ "$it_token" = "$default_token" ]; then
                default_index="$i"
                break
            fi
            i=$((i+1))
        done
        # If we didn't find the token, fall back to 1
        if [ -z "$default_index" ]; then
            default_index="1"
        fi
    fi

    # Print the list (highlight default)
    numbered_list "$default_index" "${items[@]}"

    # Prepare display default: prefer showing token when provided
    local display_default="$default_index"
    if [ -n "$default_token" ]; then
        display_default="$default_token"
    fi

    # Prompt loop
    local input
    while true; do
        if [ -n "$display_default" ] && [ "${COLOR_ENABLED:-0}" = "1" ]; then
            printf "Select an option [%b]: " "${GREEN}${display_default}${RESET}"
        elif [ -n "$display_default" ]; then
            printf "Select an option [%s]: " "$display_default"
        else
            printf "Select an option: "
        fi
        read -r input
        if [ -z "$input" ]; then
            input="$default_index"
        fi
        # Validate numeric
        if ! printf "%s" "$input" | grep -Eq '^[0-9]+$'; then
            echo "Please enter a number between 1 and $count"
            continue
        fi
        if [ "$input" -lt 1 ] || [ "$input" -gt "$count" ]; then
            echo "Please enter a number between 1 and $count"
            continue
        fi
        break
    done

    local sel_index="$input"
    # Arrays are 0-based in bash
    local sel_item="${items[$((sel_index-1))]}"

    # Extract a short token from the selected item. We expect items to be
    # provided in the form "token  - Human readable description" or
    # "token - description". The token is the first whitespace-delimited
    # field up to any separator like '-' or whitespace alignment.
    # Trim leading/trailing whitespace first.
    local sel_token
    sel_token=$(printf "%s" "$sel_item" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/\s*-\s*/ - /' )
    # Now take the substring before the ' - ' separator if present, otherwise
    # take the first word.
    if printf "%s" "$sel_token" | grep -q " - "; then
        sel_token=$(printf "%s" "$sel_token" | cut -d'-' -f1 | sed -e 's/[[:space:]]*$//')
    else
        sel_token=$(printf "%s" "$sel_token" | awk '{print $1}')
    fi

    # Export into caller variables (use eval)
    eval "$out_var=\"$sel_token\""
    if [ -n "$out_idx_var" ]; then
        eval "$out_idx_var=\"$sel_index\""
    fi

    return 0
}
