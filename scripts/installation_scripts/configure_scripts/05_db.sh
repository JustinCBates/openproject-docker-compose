#!/bin/bash
# Database configuration section

run_db() {

    echo
    db_section_body=$(cat <<EOF
Database and storage configuration for PostgreSQL. Choose passwords and storage options.
EOF
)
    section "Database Configuration:" "$db_section_body"
    dbpw_body=$(cat <<EOF
PostgreSQL administrator password used for DB initialization and maintenance.

This password will be used for:
• PostgreSQL database administrator access
• Database initialization and maintenance
• NOT the OpenProject web application login

Password Security Recommendations:
• Use at least 12 characters
• Include uppercase, lowercase, numbers, and symbols
• Avoid dictionary words or personal information
• Consider using a password manager
EOF
)
    subsection "Database Password" "$dbpw_body"

    current_default_admin_password=$(get_cfg "DEFAULT_DBADMIN_PASSWORD")

    if [ -n "$current_default_admin_password" ]; then
        echo "Current PostgreSQL database admin password: $current_default_admin_password"
        if validate_yn "Keep current database admin password?" "y"; then
            default_admin_password="$current_default_admin_password"
            echo "✓ Using existing database admin password"
        else
            echo -n "Enter new PostgreSQL database admin password: "
            read -s default_admin_password
            echo
            echo "✓ Database admin password updated"
        fi
    else
        echo -n "Enter PostgreSQL database admin password: "
        read -s default_admin_password
        echo
        if [ -z "$default_admin_password" ]; then
            echo "⚠ No password entered. Using default 'admin123' (CHANGE THIS AFTER INSTALLATION!)"
            default_admin_password="admin123"
        else
            echo "✓ Database admin password set"
        fi
    fi

    echo
    db_storage_body=$(cat <<EOF
Choose how to store database data and where it will reside on the host.
EOF
)
    subsection "Database Storage" "$db_storage_body"
    current_db_storage=$(get_cfg "DATABASE_STORAGE_TYPE")
    if [ -z "$current_db_storage" ]; then current_db_storage="docker-volumes"; fi
    case "$current_db_storage" in
        docker-volumes) current_storage_num="1" ;;
        bind-mounts) current_storage_num="2" ;;
        *) current_storage_num="1" ;;
    esac

    numbered_list_prompt "$current_db_storage" storage_token storage_idx \
        "docker-volumes  - Use Docker managed volumes (recommended for most cases)" \
        "bind-mounts     - Use host filesystem paths (easier for backups)"

    db_storage_type="$storage_token"
    if [ "$db_storage_type" = "docker-volumes" ]; then
        echo "✓ Using Docker managed volumes for database storage"
    elif [ "$db_storage_type" = "bind-mounts" ]; then
        echo "✓ Using host filesystem bind mounts for database storage"
    current_db_path=$(get_cfg "DATABASE_HOST_PATH")
    if [ -z "$current_db_path" ]; then current_db_path="/opt/openproject/data"; fi
        prompt_with_default "Host path for database data" "$current_db_path" "db_host_path"
    else
        echo "⚠ Invalid selection '$storage_idx'. Using default: docker-volumes"
        db_storage_type="docker-volumes"
    fi

    save_config "OPENPROJECT_HOST_NAME" "$host_name"
    save_config "OPENPROJECT_HTTPS" "$use_https"
    save_config "OPENPROJECT_TAG" "$op_tag"
    save_config "DEFAULT_DBADMIN_PASSWORD" "$default_admin_password"
    save_config "DATABASE_STORAGE_TYPE" "$db_storage_type"
    if [ "$db_storage_type" = "bind-mounts" ] && [ -n "$db_host_path" ]; then
        save_config "DATABASE_HOST_PATH" "$db_host_path"
    fi
    save_config "GIT_USERNAME" "$git_username"
    save_config "GIT_EMAIL" "$git_email"
    save_config "DOMAIN_NAME" "$domain_name"
    save_config "NAMESPACE" "$namespace"
    save_config "ENVIRONMENT_TYPE" "$environment_type"
    save_config "OS_FAMILY" "$os_family"

    if [ -n "$git_username" ]; then
        git config --global user.name "$git_username"
        echo "Git username set to: $git_username"
    fi
    if [ -n "$git_email" ]; then
        git config --global user.email "$git_email"
        echo "Git email set to: $git_email"
    fi
}
