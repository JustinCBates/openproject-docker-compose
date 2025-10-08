#!/bin/bash

# common_ui.sh - UI helpers that build on common.sh
# Location: scripts/installation_scripts/common/common_ui.sh

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$COMMON_DIR/common.sh"
if [ -f "$COMMON_SH" ]; then
    # shellcheck source=/dev/null
    source "$COMMON_SH"
fi

# Section and supersection are UI helpers that render headings and optional
# multi-line bodies. They were previously defined in common.sh but belong
# here with the other UI helpers.
section() {
    # Two leading blank lines before a top-level section
    printf "\n\n"
    # Usage: section "Title" ["optional multi-line body"]
    local title="$1"
    local body="${2-}"
    local underline
    # Compute max width between title and any body lines so all decorations
    # share the same width.
    local IFS=$'\n'
    local maxw=${#title}
    if [ -n "$body" ]; then
        for line in $body; do
            local l=${#line}
            if [ "$l" -gt "$maxw" ]; then
                maxw=$l
            fi
        done
    fi

    # Cap the computed width to the terminal width to avoid generating
    # extremely long decoration lines that can make the UI appear hung.
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
    if [ "$maxw" -gt "$term_w" ]; then
        maxw=$term_w
    fi

    # Top '=' rule
    local rule
    rule=$(printf '%*s' "$maxw" '' | tr ' ' '=')
    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%b\n" "${BRONZE}${rule}${RESET}"
    else
        printf "%s\n" "$rule"
    fi

    # Title and underline (same width)
    echo -e "${BRONZE}${title}${RESET}"
    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%b\n" "${BRONZE}${rule}${RESET}"
    else
        printf "%s\n" "$rule"
    fi

    if [ -n "$body" ]; then
        # Subdued color: use BRONZE but dim by reducing brightness if terminal
        # doesn't support dim, fallback to RESET. We'll box the body with a
        # bottom underscore line matching width.
        # Print body lines and compute max width
        local IFS=$'\n'
        local maxw=0
        for line in $body; do
            # Print the body in a less prominent color (use SUBDUED)
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                # Use %s so the body text is printed literally (preserve here-doc content)
                printf "%s\n" "${SUBDUED}${line}${RESET}"
            else
                printf "%s\n" "${line}"
            fi
            local l=${#line}
            if [ "$l" -gt "$maxw" ]; then
                maxw=$l
            fi
        done
        # Print bottom underscore box in BRONZE
        if [ "$maxw" -gt 0 ]; then
            local underscore
            underscore=$(printf '%*s' "$maxw" '' | tr ' ' '_')
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${underscore}${RESET}"
            else
                printf '%s\n' "$underscore"
            fi
        fi
    fi
}

# Print a stronger top-level section (supersection) with bolder decoration.
# This is visually distinct from `section()`: it uses an emphasized title color
# and extra spacing so callers can mark a super-container (e.g. "Interactive
# Configuration").
supersection() {
    # Usage: supersection "Title" ["optional multi-line body"]
    local title="$1"
    local body="${2-}"
    local IFS=$'\n'
    local maxw=${#title}
    if [ -n "$body" ]; then
        for line in $body; do
            local l=${#line}
            if [ "$l" -gt "$maxw" ]; then
                maxw=$l
            fi
        done
    fi

    # Determine terminal width cap
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
    if [ "$maxw" -gt "$term_w" ]; then
        maxw=$term_w
    fi

    # Determine terminal width so the supersection uses the full width
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

    # Top rule: full terminal width using '#' for stronger emphasis
    local rule
    rule=$(printf '%*s' "$term_w" '' | tr ' ' '#')

    # Leading blank lines to make the supersection stand out
    printf "\n\n\n"

    # Print rule, title (in YELLOW to emphasize), and rule again
    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%b\n" "${BRONZE}${rule}${RESET}"
        printf "%b\n" "${YELLOW}${title}${RESET}"
        printf "%b\n" "${BRONZE}${rule}${RESET}"
    else
        printf "%s\n" "$rule"
        printf "%s\n" "$title"
        printf "%s\n" "$rule"
    fi

    if [ -n "$body" ]; then
        local maxb=0
        for line in $body; do
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                # Print literally with %s to preserve here-doc content
                printf "%s\n" "${SUBDUED}${line}${RESET}"
            else
                printf "%s\n" "$line"
            fi
            local l=${#line}
            if [ "$l" -gt "$maxb" ]; then
                maxb=$l
            fi
        done
        if [ "$maxb" -gt 0 ]; then
            # Cap footer width to the terminal width to avoid overflow
            local footw=$maxb
            if [ "$footw" -gt "$term_w" ]; then
                footw=$term_w
            fi
            local foot
            foot=$(printf '%*s' "$footw" '' | tr ' ' '_')
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${foot}${RESET}"
            else
                printf '%s\n' "$foot"
            fi
        fi
    fi
}

# Print a smaller subsection heading (single-line bronze label)
subsection() {
    # Leading blank line before a subsection
    printf "\n"
    # Usage: subsection "Title" ["optional multi-line body"]
    local title="$1"
    local body="${2-}"
    local underline
    # Compute max width between title and body
    local IFS=$'\n'
    local maxw=${#title}
    if [ -n "$body" ]; then
        for line in $body; do
            local l=${#line}
            if [ "$l" -gt "$maxw" ]; then
                maxw=$l
            fi
        done
    fi

    # Determine terminal width and cap decorations to it. For subsections we
    # intentionally use the full terminal width for the top/bottom rule so the
    # dash line spans the screen.
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

    # Top '-' rule stretched to full terminal width
    local rule
    rule=$(printf '%*s' "$term_w" '' | tr ' ' '-')
    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%b\n" "${BRONZE}${rule}${RESET}"
    else
        printf "%s\n" "$rule"
    fi
    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%b\n" "${BRONZE}${title}${RESET}"
    else
        printf "%s\n" "$title"
    fi
    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%b\n" "${BRONZE}${rule}${RESET}"
    else
        printf "%s\n" "$rule"
    fi

    if [ -n "$body" ]; then
        # Compute the max width among body lines (so footer matches content)
        local IFS=$'\n'
        local maxb=0
        for line in $body; do
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                # Print body literally so here-doc content remains unchanged
                printf "%s\n" "${SUBDUED}${line}${RESET}"
            else
                printf "%s\n" "$line"
            fi
            local l=${#line}
            if [ "$l" -gt "$maxb" ]; then
                maxb=$l
            fi
        done

        # Cap footer width to terminal width
        local footw=$maxb
        if [ "$footw" -gt "$term_w" ]; then
            footw=$term_w
        fi
        if [ "$footw" -gt 0 ]; then
            local foot
            foot=$(printf '%*s' "$footw" '' | tr ' ' '_')
            if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
                printf "%b\n" "${BRONZE}${foot}${RESET}"
            else
                printf '%s\n' "$foot"
            fi
        fi
    fi
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
