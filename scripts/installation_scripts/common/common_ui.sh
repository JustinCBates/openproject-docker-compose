#!/bin/bash

# common_ui.sh - UI helpers that build on common.sh
# Location: scripts/installation_scripts/common/common_ui.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SH="$SCRIPT_DIR/common.sh"
if [ -f "$COMMON_SH" ]; then
    # shellcheck source=/dev/null
    source "$COMMON_SH"
fi

# Print a smaller subsection heading (single-line bronze label)
subsection() {
    local title="$*"
    local underline
    underline=$(printf '%*s' "${#title}" '' | tr ' ' '-')
    echo -e "${BRONZE}${title}${RESET}"
    echo -e "${BRONZE}${underline}${RESET}"
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
