#!/bin/bash
# Repository and git configuration section

run_repo() {
    # If a central initializer is available, call it to populate current_* defaults
    if declare -f init_install_defaults >/dev/null 2>&1; then
        init_install_defaults
    else
        # Provide safe defaults when variables are not exported by the caller.
        current_tag="${current_tag:-16}"
        current_git_user="${current_git_user:-}"
        current_git_email="${current_git_email:-}"
    fi

    repo_body=$(cat <<EOF
Repository and git configuration for OpenProject.
EOF
)
    section "Repo Settings" "$repo_body"

    git_version_body=$(cat <<EOF
Choose the OpenProject repository tag (release or branch) to deploy. 
If unsure, use the default stable tag.
EOF
)
    subsection "OpenProject Version Configuration" "$git_version_body"
    prompt_with_default "OpenProject version tag" "$current_tag" "op_tag"
    echo " "

    git_cfg_body=$(cat <<EOF
Enter the Git user.name and user.email used by installer scripts when creating 
or patching local artifacts (commits, config templates). 
These values become global git config if provided.
EOF
)
    subsection "Git Configuration" "$git_cfg_body"
    
    # Get Git configuration from config file first, then fall back to global git config
    current_git_user_cfg=$(get_cfg "GIT_USERNAME")
    current_git_email_cfg=$(get_cfg "GIT_EMAIL")

    if [ -n "$current_git_user_cfg" ]; then
        current_git_user="$current_git_user_cfg"
    fi
    if [ -n "$current_git_email_cfg" ]; then
        current_git_email="$current_git_email_cfg"
    fi

    if [ -z "$current_git_user" ]; then
        current_git_user="$(whoami)"
    fi
    if [ -z "$current_git_email" ]; then
        current_git_email="$(whoami)@$(hostname -f)"
    fi
    
    prompt_with_default "Git username" "$current_git_user" "git_username"
    prompt_with_default "Git email" "$current_git_email" "git_email"
}
