#!/usr/bin/env bash

# validate_installation.sh - Validation wrapper for interactive installer
# Runs safe, non-destructive checks: syntax, regenerate defaults, preview and smoke tests.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Repository root: go up to the workspace root (scripts/installation_scripts/tools -> ../../.. -> workspace)
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="$REPO_ROOT/logs"
mkdir -p "$LOG_DIR"
TS=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="$LOG_DIR/validate-$TS.log"

# Export key environment variables so timeout/bashed subshells inherit them
export REPO_ROOT LOG_FILE

# Defaults
GLOBAL_TIMEOUT=600
SYNTAX_TIMEOUT=60
REGEN_TIMEOUT=20
SMOKE_TIMEOUT=30
DRY_RUN=1
APPLY=0

usage() {
    cat <<EOF
Usage: $0 [--apply] [--timeout SECONDS] [--log-file FILE]

Options:
  --apply           Run optional potentially-destructive checks (explicit consent)
  --timeout SECS    Global timeout for the script (default: $GLOBAL_TIMEOUT)
  --log-file FILE   Write log to FILE instead of default $LOG_FILE
  -h, --help        Show this help
EOF
}

# Simple runner with timeout and logging
run_step() {
    # Usage: run_step "Name" timeout_secs "command string"
    local name="$1"; shift
    local tout="$1"; shift
    local cmd_str="$*"

    printf "\n--- STEP: %s (timeout %ss) ---\n" "$name" "$tout" | tee -a "$LOG_FILE"
    # If the command string begins with a local function name, prefix its definition
    local first_word
    first_word=$(printf "%s" "$cmd_str" | awk '{print $1}')
    if declare -f "$first_word" >/dev/null 2>&1; then
        # Export the function definition into the subshell command so it can be invoked
        local fn_def
        fn_def=$(declare -f "$first_word")
        cmd_str="$fn_def; $cmd_str"
    fi

    # Run the command string under bash -lc so shell functions and environment are available
    if timeout --preserve-status "${tout}" bash -lc "$cmd_str" >> "$LOG_FILE" 2>&1; then
        printf "STEP %s: PASS\n" "$name" | tee -a "$LOG_FILE"
        return 0
    else
        local rc=$?
        if [ $rc -eq 124 ]; then
            printf "STEP %s: TIMEOUT (exit %s)\n" "$name" "$rc" | tee -a "$LOG_FILE"
        else
            printf "STEP %s: FAIL (exit %s)\n" "$name" "$rc" | tee -a "$LOG_FILE"
        fi
        return $rc
    fi
}

# Step 1: Syntax check
syntax_check() {
    find "$REPO_ROOT/scripts/installation_scripts" -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
}

# Step 2: regenerate defaults (non-interactive)
regenerate_defaults() {
    # run interactive_config.sh non-interactively answering 'n' to prompts
    printf "n\n" | "$REPO_ROOT/scripts/installation_scripts/interactive_config.sh" || true
}

# Step 3: verify defaults file contains keys
verify_defaults_keys() {
    local f="$REPO_ROOT/scripts/installation_scripts/interactive_config.cfg.defaults"
    if [ ! -f "$f" ]; then
        echo "Defaults file not found: $f" >&2
        return 2
    fi
    local miss=0
    for k in DOMAIN_NAME OPENPROJECT_HOST_NAME OPENPROJECT_HTTPS OPENPROJECT_TAG OS_FAMILY; do
        # allow optional leading whitespace in the defaults file
        if ! grep -Eq "^[[:space:]]*${k}=" "$f"; then
            echo "Missing key in defaults: $k" | tee -a "$LOG_FILE"
            miss=1
        fi
    done
    if [ $miss -ne 0 ]; then return 1; fi
    return 0
}

# Step 4: run preview (interactive_config.sh prints preview)
run_preview() {
    printf "n\n" | "$REPO_ROOT/scripts/installation_scripts/interactive_config.sh" | sed -n '1,160p'
}

# Step 5: smoke tests (non-destructive)
smoke_tests() {
    # setup_git_user.sh will skip if no config; it's safe
    "$REPO_ROOT/scripts/installation_scripts/installation_utilities/setup_git_user.sh" || true
    # build_proxy.sh is non-destructive (builds if proxy service exists)
    "$REPO_ROOT/scripts/installation_scripts/installation_utilities/proxy/build_proxy.sh" || true
    # build_stack.sh supports DRY_RUN via environment variable
    (cd "$REPO_ROOT" && DRY_RUN=1 "$REPO_ROOT/scripts/installation_scripts/installation_utilities/build_stack.sh") || true
}

# Main
main() {
    printf "Validation started at %s\n" "$(date --iso-8601=seconds)" | tee -a "$LOG_FILE"

    run_step "Syntax check" $SYNTAX_TIMEOUT syntax_check || return 1
    run_step "Regenerate defaults" $REGEN_TIMEOUT regenerate_defaults || return 2
    run_step "Verify defaults keys" 10 verify_defaults_keys || return 3
    run_step "Run preview (capture)" $REGEN_TIMEOUT run_preview || true
    # Source generated defaults (export them) so OS-specific scripts don't fail on unbound vars
    local defaults_file="$REPO_ROOT/scripts/installation_scripts/interactive_config.cfg.defaults"
    if [ -f "$defaults_file" ]; then
        # Export variables from defaults file
        set -a
        # shellcheck disable=SC1090
        source "$defaults_file"
        set +a
    fi
    # Provide safe fallbacks for variables some OS scripts assume exist
    export DEFAULT_DBADMIN_PASSWORD="${DEFAULT_DBADMIN_PASSWORD:-}"
    export DATABASE_STORAGE_TYPE="${DATABASE_STORAGE_TYPE:-docker-volumes}"

    # Split smoke tests into independent steps with generous timeouts
    run_step "Smoke: setup_git_user" 20 "$REPO_ROOT/scripts/installation_scripts/installation_utilities/setup_git_user.sh" || return 4
    run_step "Smoke: build_proxy" 120 "$REPO_ROOT/scripts/installation_scripts/installation_utilities/proxy/build_proxy.sh" || return 4
    run_step "Smoke: build_stack (dry-run)" 120 "cd \"$REPO_ROOT\" && DRY_RUN=1 \"$REPO_ROOT/scripts/installation_scripts/installation_utilities/build_stack.sh\"" || return 4

    printf "\nValidation completed: SUCCESS\n" | tee -a "$LOG_FILE"
    return 0
}

main "$@"
