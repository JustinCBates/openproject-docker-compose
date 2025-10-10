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
WHITE=$'\e[97m'
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

# Interrupt handling: provide a friendly handler for SIGINT (Ctrl-C).
# Modules can call enable_interrupt()/disable_interrupt() if they need
# finer control. By default, enable when running interactively.
on_interrupt() {
    # Move to new line and print a short message; exit with 130 (commonly used for SIGINT)
    printf "\n" >&2
    printf "%s\n" "Interrupted by user (SIGINT). Exiting..." >&2
    exit 130
}

enable_interrupt() {
    trap 'on_interrupt' INT
}

disable_interrupt() {
    trap - INT
}

# Interactive helpers install the SIGINT handler locally using
# push_sigint_trap/pop_sigint_trap. Do not enable a global trap on source.

# Helper: push/pop SIGINT trap so interactive helpers can temporarily
# install the friendly handler and restore the previous trap after.
# We store traps on a stack to support nested calls.
_SIGINT_TRAP_STACK=()

push_sigint_trap() {
    # Save current trap for INT (may be empty)
    local prev
    prev="$(trap -p INT 2>/dev/null || true)"
    _SIGINT_TRAP_STACK+=("$prev")
    enable_interrupt
}

pop_sigint_trap() {
    # Restore last saved trap or clear if none
    local idx
    idx=$((${#_SIGINT_TRAP_STACK[@]} - 1))
    if [ "$idx" -ge 0 ] 2>/dev/null; then
        local prev="${_SIGINT_TRAP_STACK[$idx]}"
        unset '_SIGINT_TRAP_STACK[$idx]'
        if [ -n "$prev" ]; then
            # prev already contains a 'trap ... INT' command string; eval it
            eval "$prev"
        else
            trap - INT
        fi
    else
        trap - INT
    fi
}

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
# The separator is style-agnostic: callers should pass header/footer chars,
# the number of leading newlines (pre_newlines), and any color choices.
separator() {
    # title, body, header_char, foot_char, pre_newlines, header_color, title_color, body_color
    local title="$1"
    local body="${2-}"
    local header_char="${3:-}"
    local foot_char="${4:-_}"
    local pre_newlines="${5:-2}"
    local header_color="${6:-}"
    local title_color="${7:-}"
    local body_color="${8:-}"
    local IFS=$'\n'

    # Helper: strip ANSI escape sequences so we can compute visible width
    strip_ansi() {
        local s="$1"
        # Use awk to remove common ANSI CSI sequences (e.g., \033[31m)
        printf "%s" "$s" | awk '{ gsub(/\033\[[0-9;]*[mK]/, ""); print }'
    }

    # Return visible character length (wc -m handles multibyte reasonably)
    visible_length() {
        local txt
        txt=$(strip_ansi "$1")
        # wc -m prints leading spaces; trim them
        printf "%s" "$txt" | wc -m | tr -d ' '
    }

    # Replace readable color tokens like {YELLOW} with actual ANSI escapes when
    # colors are enabled. When colors are disabled the tokens are removed.
    apply_color_tokens() {
        local s="$1"
        if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
            s="${s//\{RED\}/${RED}}"
            s="${s//\{BRONZE\}/${BRONZE}}"
                s="${s//\{WHITE\}/${WHITE}}"
            s="${s//\{YELLOW\}/${YELLOW}}"
            s="${s//\{RESET\}/${RESET}}"
            s="${s//\{GREEN\}/${GREEN}}"
            s="${s//\{DIM\}/${DIM}}"
            s="${s//\{SUBDUED\}/${SUBDUED}}"
        else
            s="${s//\{RED\}/}"
            s="${s//\{BRONZE\}/}"
                s="${s//\{WHITE\}/}"
            s="${s//\{YELLOW\}/}"
            s="${s//\{RESET\}/}"
            s="${s//\{GREEN\}/}"
            s="${s//\{DIM\}/}"
            s="${s//\{SUBDUED\}/}"
        fi
        printf "%s" "$s"
    }

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

    # Compute content width: max of title and any body lines. Use visible
    # lengths (strip ANSI escapes) so embedded color codes don't affect width.
    local content_w
    content_w=$(visible_length "$title")
    if [ -n "$body" ]; then
        for line in $body; do
            # apply token->ANSI substitution before measuring so tokens count as
            # zero-width escapes when converted.
            local measured_line
            measured_line=$(apply_color_tokens "$line")
            local l
            l=$(visible_length "$measured_line")
            if [ "$l" -gt "$content_w" ]; then
                content_w=$l
            fi
        done
    fi
    # Cap to terminal width
    if [ "$content_w" -gt "$term_w" ]; then
        content_w=$term_w
    fi

    # Determine header char default if not provided
    if [ -z "$header_char" ]; then
        header_char='='
    fi

    # Determine color defaults if not passed in
    if [ -z "$header_color" ]; then
        header_color="${BRONZE}"
    fi
    if [ -z "$title_color" ]; then
        title_color="${BRONZE}"
    fi
    if [ -z "$body_color" ]; then
        body_color="${SUBDUED}"
    fi

    # Render header/title/header with configurable leading newlines
    local header
    header=$(printf '%*s' "$content_w" '' | tr ' ' "$header_char")

    # Print leading newlines
    for ((i=0;i<pre_newlines;i++)); do
        printf "\n"
    done

    if [ "${COLOR_ENABLED:-0}" -eq 1 ]; then
        printf "%s\n" "$(apply_color_tokens "${header_color}${header}${RESET}")"
        printf "%s\n" "$(apply_color_tokens "${title_color}${title}${RESET}")"
        printf "%s\n" "$(apply_color_tokens "${header_color}${header}${RESET}")"
    else
        printf "%s\n" "$header"
        printf "%s\n" "$title"
        printf "%s\n" "$header"
    fi

    # Body and footer
    if [ -n "$body" ]; then
        local maxb=0
            for line in $body; do
            # Apply color tokens and/or ${COLOR} expansions before printing
            local printed
            printed=$(apply_color_tokens "${body_color}${line}${RESET}")
            printf "%s\n" "$printed"
            local measured
            measured=$(visible_length "$printed")
            if [ "$measured" -gt "$maxb" ]; then
                maxb=$measured
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
    # title, body, header_char='=', foot_char='_', pre_newlines=2
    separator "$1" "${2-}" '=' '_' 2 "${BRONZE}" "${BRONZE}" "${SUBDUED}"
}

supersection() {
    # supersections use '#' header and a brighter title color
    separator "$1" "${2-}" '#' '_' 3 "${BRONZE}" "${YELLOW}" "${SUBDUED}"
}

subsection() {
    # subsection uses '-' header and single leading newline
    separator "$1" "${2-}" '-' '_' 1 "${BRONZE}" "${BRONZE}" "${SUBDUED}"
}

# Render a formal preview block for the web endpoint URL.
# Usage: preview_web_endpoint <domain> <namespace>
# If namespace is empty, shows the root URL. Uses color tokens and format_default
# so domain/namespace render in green when colors are enabled.
preview_web_endpoint() {
    # Render a compact one-line preview: label + scheme + colored domain/namespace
    # Usage: preview_web_endpoint <domain> <namespace> <scheme>
    local domain="$1"
    local namespace="$2"
    local scheme="${3:-https}"
    local label
    label="$(apply_color_tokens "{BRONZE}Preview URL:{RESET}")"
    local domain_colored
    domain_colored="$(format_default "$domain")"
    if [ -n "$namespace" ]; then
        local ns_colored
        ns_colored="$(format_default "$namespace")"
        # Print: Preview URL: https://<domain>/<namespace>
        printf "%b %s://%b/%b\n" "$label" "$scheme" "$domain_colored" "$ns_colored"
    else
        # Print: Preview URL: https://<domain>/
        printf "%b %s://%b/\n" "$label" "$scheme" "$domain_colored"
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
        push_sigint_trap
        read input
        pop_sigint_trap
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
            push_sigint_trap
            read yn
            pop_sigint_trap
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
            push_sigint_trap
            read yn
            pop_sigint_trap
            case $yn in
                [Yy]* ) return 0;;
                [Nn]* ) return 1;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

validate_tf() {
    # validate_tf <prompt> <default> [out_var]
    # If out_var is provided, the function will set that variable
    # to the literal strings "true" or "false" depending on the answer.
    local prompt="$1"
    local default="$2"
    local out_var="${3-}"
    local tf
    if [ -n "$default" ]; then
        while true; do
            if [ -t 1 ] && [ -n "$GREEN" ]; then
                def_display="${GREEN}${default}${RESET}"
                printf "%s (true/false) [%b]: " "$prompt" "$def_display"
            else
                printf "%s (true/false) [%s]: " "$prompt" "$default"
            fi
            push_sigint_trap
            read tf
            pop_sigint_trap
            if [ -z "$tf" ]; then
                tf="$default"
            fi
            case $tf in
                [Tt]rue|[Tt] )
                    if [ -n "$out_var" ]; then
                        eval "$out_var='true'"
                    fi
                    return 0;;
                [Ff]alse|[Ff] )
                    if [ -n "$out_var" ]; then
                        eval "$out_var='false'"
                    fi
                    return 1;;
                * ) echo "Please answer true or false.";;
            esac
        done
    else
        while true; do
            printf "%s (true/false): " "$prompt"
            push_sigint_trap
            read tf
            pop_sigint_trap
            case $tf in
                [Tt]rue|[Tt] )
                    if [ -n "$out_var" ]; then
                        eval "$out_var='true'"
                    fi
                    return 0;;
                [Ff]alse|[Ff] )
                    if [ -n "$out_var" ]; then
                        eval "$out_var='false'"
                    fi
                    return 1;;
                * ) echo "Please answer true or false.";;
            esac
        done
    fi
}

# Wait for a single keypress (interactive only). Non-blocking in non-TTY contexts.
anykey() {
    # anykey [prompt_text] [default]
    # Mirror validate_yn-style prompt formatting. Show an optional
    # default value (highlighted when colors enabled) and wait for
    # a single keypress from the controlling TTY. If no TTY is
    # available, print the prompt and do not block.
    local tty="/dev/tty"
    local prompt_text="${1-}"
    local default="${2-}"
    local display_default=""

    # sensible default when no prompt_text supplied
    if [ -z "$prompt_text" ]; then
        prompt_text="Press any key to continue"
    fi

    if [ -n "$default" ]; then
        display_default="$default"
    fi

    # Build the prompt string similar to validate_yn
    local prompt_line
    if [ -n "$display_default" ] && [ "${COLOR_ENABLED:-0}" = "1" ]; then
        # Use printf later to avoid accidental % sequences in prompt_text
        prompt_line="%s [%b]: "
    elif [ -n "$display_default" ]; then
        prompt_line="%s [%s]: "
    else
        prompt_line="%s: "
    fi

    if [ -c "$tty" ] && [ -r "$tty" ] && [ -w "$tty" ]; then
        # Print prompt to controlling tty without trailing newline and
        # ensure the SIGINT handler is active while we block for input.
        if [ -n "$display_default" ] && [ "${COLOR_ENABLED:-0}" = "1" ]; then
            printf "$prompt_line" "$prompt_text" "${GREEN}${display_default}${RESET}" > "$tty"
            if [ ! -t 1 ]; then
                printf "$prompt_line" "$prompt_text" "${GREEN}${display_default}${RESET}" >&2
            fi
        elif [ -n "$display_default" ]; then
            printf "$prompt_line" "$prompt_text" "$display_default" > "$tty"
            if [ ! -t 1 ]; then
                printf "$prompt_line" "$prompt_text" "$display_default" >&2
            fi
        else
            printf "$prompt_line" "$prompt_text" > "$tty"
            if [ ! -t 1 ]; then
                printf "%s" "$prompt_text: " >&2
            fi
        fi
        # Wait for any single keypress silently while SIGINT handler is active
        push_sigint_trap
        IFS= read -rsn1 _ < "$tty"
        pop_sigint_trap
        # Echo a newline so the terminal looks normal
        printf "\n" > "$tty"
        return 0
    fi

    # No TTY: print the prompt to stdout but don't block
    if [ -n "$display_default" ] && [ "${COLOR_ENABLED:-0}" = "1" ]; then
        printf "$prompt_line\n" "$prompt_text" "${GREEN}${display_default}${RESET}"
    elif [ -n "$display_default" ]; then
        printf "$prompt_line\n" "$prompt_text" "$display_default"
    else
        printf "%s\n" "$prompt_text"
    fi
    return 0
}

# Progress bar UI helpers
# Usage:
#   progress_bar_init "Message before bar" <total_ticks> [width]
#     - If total_ticks is a positive integer the bar is rendered as a
#       fixed-width bar with '[' and ']' and fills as ticks arrive.
#     - If total_ticks is empty or 0 the bar runs in indeterminate mode
#       (appends dots on each tick). Width may be provided; otherwise a
#       sensible default based on terminal width is chosen.
#
#   progress_bar_tick
#     - Advance the bar by one tick and redraw.
#
#   progress_bar_finish [message]
#     - Complete the bar and print an optional final message on the next line.
progress_bar_init() {
    local msg="${1-}"
    local total="${2-}"
    local req_width="${3-}"

    # reset internal state
    _PB_MSG="${msg}"
    _PB_TOTAL=0
    _PB_WIDTH=0
    _PB_TICKS=0
    _PB_TTY=0
    _PB_MODE="indeterminate"

    # detect TTY
    if [ -t 1 ]; then
        _PB_TTY=1
    else
        _PB_TTY=0
    fi

    # helper to get terminal width
    _get_term_width() {
        local tw=80
        if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
            tw=$(tput cols 2>/dev/null || echo 80)
        elif [ -n "${COLUMNS:-}" ] && [ "${COLUMNS:-0}" -gt 0 ]; then
            tw=${COLUMNS}
        fi
        printf "%d" "$tw"
    }

    # compute width
    local term_w
    term_w=$(_get_term_width)

    if printf "%s" "$total" | grep -Eq '^[0-9]+$' && [ "$total" -gt 0 ]; then
        _PB_MODE="known"
        _PB_TOTAL=$total
        if printf "%s" "$req_width" | grep -Eq '^[0-9]+$' && [ "$req_width" -gt 0 ]; then
            _PB_WIDTH=$req_width
        else
            # choose a width that fits the terminal: leave room for message and brackets
            local reserve=10
            local avail=$(( term_w - reserve ))
            if [ "$avail" -gt 10 ]; then
                _PB_WIDTH=$(( avail < 60 ? avail : 60 ))
            else
                _PB_WIDTH=40
            fi
        fi
    else
        _PB_MODE="indeterminate"
        # for indeterminate use a modest width for alignment if requested
        if printf "%s" "$req_width" | grep -Eq '^[0-9]+$' && [ "$req_width" -gt 0 ]; then
            _PB_WIDTH=$req_width
        else
            _PB_WIDTH=0
        fi
    fi

    # Initialize display
    if [ "$_PB_TTY" -eq 1 ]; then
        if [ -n "$_PB_MSG" ]; then
            # Print the message and prepare to draw the bar on the same line
            printf "%s " "$_PB_MSG"
        fi
        if [ "$_PB_MODE" = "known" ]; then
            # draw empty brackets
            printf "[";
            for ((i=0;i<_PB_WIDTH;i++)); do printf " "; done
            printf "]";
            # move cursor back to start of bar content
            local back=$(( _PB_WIDTH + 1 ))
            # carriage return to beginning of line, then reprint message to position cursor
            printf "\r"
            if [ -n "$_PB_MSG" ]; then
                printf "%s " "$_PB_MSG"
            fi
            printf "[";
            for ((i=0;i<_PB_WIDTH;i++)); do printf " "; done
            printf "]";
            # position cursor at first fill location
            printf "\r"
            if [ -n "$_PB_MSG" ]; then
                # move past message and space
                printf "%s " "$_PB_MSG"
            fi
            printf "["
        else
            # indeterminate: start with message and no newline; ticks will append
            # nothing else needed
            true
        fi
        # flush
        printf "";
    else
        # not a TTY: print a one-line header so logs include context
        if [ -n "$_PB_MSG" ]; then
            printf "%s\n" "$_PB_MSG"
        fi
    fi
}

progress_bar_tick() {
    _PB_TICKS=$(( _PB_TICKS + 1 ))
    if [ "${_PB_TTY:-0}" -ne 1 ]; then
        # non-tty fallback: print a dot per tick
        printf "."
        return 0
    fi

    if [ "${_PB_MODE:-indeterminate}" = "known" ]; then
        # compute filled count
        local filled=0
        if [ "${_PB_TOTAL:-0}" -gt 0 ]; then
            filled=$(( (_PB_TICKS * _PB_WIDTH) / _PB_TOTAL ))
            if [ "$filled" -gt "$_PB_WIDTH" ]; then
                filled=$_PB_WIDTH
            fi
        fi
        # redraw the bar: carriage return, print message, print [<filled><spaces>]
        printf "\r"
        if [ -n "${_PB_MSG:-}" ]; then
            printf "%s " "${_PB_MSG}"
        fi
        printf "["
        local i
        for ((i=0;i<filled;i++)); do printf "#"; done
        for ((i=filled;i<_PB_WIDTH;i++)); do printf " "; done
        printf "]"
    else
        # indeterminate: append a dot (no bracketed bar)
        printf "."
    fi
    # flush
    printf "";
}

progress_bar_finish() {
    local final_msg="${1-}"
    if [ "${_PB_TTY:-0}" -ne 1 ]; then
        # non-tty: finish line
        printf "\n"
        if [ -n "$final_msg" ]; then
            printf "%s\n" "$final_msg"
        fi
        return 0
    fi

    if [ "${_PB_MODE:-indeterminate}" = "known" ]; then
        # draw fully filled bar
        printf "\r"
        if [ -n "${_PB_MSG:-}" ]; then
            printf "%s " "${_PB_MSG}"
        fi
        printf "["
        local i
        for ((i=0;i<_PB_WIDTH;i++)); do printf "#"; done
        printf "]\n"
    else
        # indeterminate: just finish the line
        printf "\n"
    fi
    if [ -n "$final_msg" ]; then
        printf "%s\n" "$final_msg"
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

    # If the first remaining arg doesn't look like an item (no ' - '), treat
    # it as an optional header to print above the list. This keeps the
    # function backward-compatible: callers that don't pass a header still work.
    local header=""
    if [ "${#items[@]}" -gt 0 ]; then
        # Check first item candidate
        if ! printf "%s" "${items[0]}" | grep -q " - "; then
            header="${items[0]}"
            # Remove header from items
            items=("${items[@]:1}")
        fi
    fi

    # Print optional header with a leading blank line and an underline
    if [ -n "$header" ]; then
        # Leading blank line for visual separation
        printf "\n%s\n" "$header"
        # Compute visible length (strip any ANSI) and print an underline of underscores
        header_len=$(printf "%s" "$header" | awk '{ gsub(/\033\[[0-9;]*[mK]/, ""); print length }')
        if [ -z "$header_len" ] || [ "$header_len" -lt 1 ]; then header_len=12; fi
        # Print underline
        printf "%s\n" "$(printf '%*s' "$header_len" '' | tr ' ' '_')"
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
