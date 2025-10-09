#!/bin/bash
# Environment and OS configuration section

run_env_os() {
    env_section_body=$(cat <<EOF
Select the environment type that best matches your deployment goals. Defaults are provided when possible.
EOF
)
    section "Environment Configuration:" "$env_section_body"

    env_body=$(cat <<EOF
Available environment types:

localdev    - Local development: single-machine setup for developers. Runs
    services in a way that optimizes for quick iteration and debugging, may
    enable extra development-only features, and is NOT tuned for production
    reliability or security. Use this for local testing, feature work, and when
    you don't need high availability.

remotedev   - Remote development server: suitable for remote development teams
    or staging where multiple developers need access. This configuration is
    closer to production in security and networking but still intended for
    iterative feature testing rather than live production traffic. Backups and
    snapshots are recommended.

remotetest  - Remote testing/staging: an environment that mirrors production as
    closely as possible for automated testing, QA and pre-release verification.
    Use this for load testing and acceptance testing before promoting images to
    production. Expect stricter access controls and possibly separate data
    stores.

production  - Production server: configured for security, reliability, and
    maintainability. Enables TLS, appropriate persistence, backups, and
    monitoring. Only use this configuration when hosting real user data and
    traffic.
EOF
)
    subsection "Environment Configuration" "$env_body"
    numbered_list_prompt "$current_env_type" env_token env_idx \
        "localdev    - Local development environment" \
        "remotedev   - Remote development server" \
        "remotetest  - Remote testing/staging server" \
        "production  - Production server"

    environment_type="$env_token"
    save_config "ENVIRONMENT_TYPE" "$environment_type"

    os_sub_body=$(cat <<EOF
Select the OS family (Debian, RedHat, SUSE, Arch, Slackware). 
Installer steps and package commands will be tailored to this choice. 
Use the detected OS when possible.
EOF
)
    subsection "Operating System Configuration" "$os_sub_body"

    # Source OS detection helper from common/
    if [ -f "$SCRIPT_DIR/common/common_os.sh" ]; then
        source "$SCRIPT_DIR/common/common_os.sh"
    fi

    detected_os_family=$(detect_os_family)
    if [ -n "$detected_os_family" ] && [ "$detected_os_family" != "unknown" ]; then
        current_os_family="$detected_os_family"
        current_os_family_raw=$(get_cfg "OS_FAMILY")
        if [ -n "$current_os_family_raw" ]; then
            current_os_family=$(echo "$current_os_family_raw" | sed -e "s/^['\"]//" -e "s/['\"]$//" -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        else
            current_os_family="$detected_os_family"
        fi
    fi

    if [ "$current_os_family" != "unknown" ]; then
        echo "Detected OS family: $current_os_family"
        echo
        warn "Changing from the detected OS family may cause errors"
        echo "   in the configure and build process. The installation utilities"
        echo "   are optimized for the detected OS family."
        echo
    fi

    echo "Available OS families:"

    case "$current_os_family" in
        debian) current_os_num="1" ;;
        redhat) current_os_num="2" ;;
        suse) current_os_num="3" ;;
        arch) current_os_num="4" ;;
        slackware) current_os_num="5" ;;
        *) current_os_num="1" ;;
    esac

    numbered_list_prompt "$current_os_family" os_token os_idx \
        "debian     - Debian, Ubuntu, Mint, Raspbian" \
        "redhat     - RHEL, CentOS, Fedora, Rocky, AlmaLinux" \
        "suse       - openSUSE, SLES" \
        "arch       - Arch Linux, Manjaro, EndeavourOS" \
        "slackware  - Slackware"

    selected_os_family="$os_token"

    lc_current_os=$(echo "$current_os_family" | tr '[:upper:]' '[:lower:]')
    lc_selected_os=$(echo "$selected_os_family" | tr '[:upper:]' '[:lower:]')

    if [ "$lc_current_os" != "unknown" ] && [ "$lc_selected_os" != "$lc_current_os" ]; then
        echo
        warn "You selected '$selected_os_family' but detected OS is '$current_os_family'"
        echo "   This may cause compatibility issues with:"
        echo "   • Package installation commands"
        echo "   • Service management"
        echo "   • File paths and configurations"
        echo "   • Docker setup procedures"
        echo
        if validate_yn "Are you sure you want to use '$selected_os_family' instead of '$current_os_family'?" "n"; then
            os_family="$selected_os_family"
        else
            os_family="$current_os_family"
        fi
        save_config "OS_FAMILY" "$os_family"
    else
        os_family="$selected_os_family"
        save_config "OS_FAMILY" "$os_family"
    fi
}
