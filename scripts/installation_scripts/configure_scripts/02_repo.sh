#!/bin/bash
# Repository and git configuration section

run_repo() {
    # Central initialization is performed by interactive_config.sh. Ensure
    # minimal safe defaults are present in case this script is sourced stand-alone.
    current_tag="${current_tag:-stable/16}"
    current_git_user="${current_git_user:-}"
    current_git_email="${current_git_email:-}"

    repo_body=$(cat <<EOF
Repository and git configuration for OpenProject.
EOF
)
    section "Repo Settings" "$repo_body"

    git_version_body=$(cat <<EOF
Choose the OpenProject repository tag (release or branch) to deploy. 
If unsure, use the default stable tag. Not currently used for any 
functionality in the build process. So don't sweat it too much.
EOF
)
    subsection "OpenProject Version Configuration" "$git_version_body"
    prompt_with_default "OpenProject version tag" "$current_tag" "op_tag"
    # Persist OpenProject tag immediately after user selection
    if [ -n "${op_tag:-}" ]; then
        save_config "OPENPROJECT_TAG" "$op_tag"
    fi
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
    if [ -n "${git_username:-}" ]; then
        save_config "GIT_USERNAME" "$git_username"
    fi
    prompt_with_default "Git email" "$current_git_email" "git_email"
    if [ -n "${git_email:-}" ]; then
        save_config "GIT_EMAIL" "$git_email"
    fi
}
