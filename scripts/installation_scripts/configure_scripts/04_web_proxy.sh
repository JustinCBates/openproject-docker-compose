#!/bin/bash
# Web and proxy configuration section

run_web_proxy() {
    web_host_body=$(cat <<EOF
Provide the public hostname where OpenProject will be served (e.g., example.com). 
Enable HTTPS if you have or will configure TLS certificates.
EOF
)
    subsection "Web Configuration" "$web_host_body"
    prompt_with_default "Enter the hostname for OpenProject" "$current_host" "host_name"
    # Persist host name immediately so other modules/utilities can use it
    if [ -n "${host_name:-}" ]; then
        save_config "OPENPROJECT_HOST_NAME" "$host_name"
    fi
    # Use validate_tf so inputs like 't'/'f' are normalized to literal 'true'/'false'
    # and exported into the caller variable 'use_https'.
    validate_tf "Enable HTTPS?" "$current_https" use_https
    # Persist HTTPS selection immediately (save_config normalizes booleans)
    if [ -n "${use_https:-}" ]; then
        save_config "OPENPROJECT_HTTPS" "$use_https"
    fi

    echo

    use_https_lc=$(echo "$use_https" | tr '[:upper:]' '[:lower:]')
    if [ "$use_https_lc" = "true" ]; then
        default_redirect="true"
    else
        default_redirect="false"
    fi

    echo
    proxy_body=$(cat <<EOF
Security note: If you disable HTTP->HTTPS redirects, users can access the site over plaintext HTTP. 
This exposes credentials, cookies, and session tokens to on-path attackers (MITM), 
and prevents automatic TLS enforcement by browsers. 
Only disable redirects if you understand and accept these risks.
EOF
)
    subsection "Proxy HTTPS redirect configuration" "$proxy_body"

    # Ask user and persist 'true'/'false' into proxy_redirect
    proxy_redirect=""
    if validate_tf "Redirect HTTP to HTTPS?" "$default_redirect" proxy_redirect; then
        : # proxy_redirect set to 'true' by validate_tf
    else
        : # proxy_redirect set to 'false' by validate_tf
    fi

    save_config "PROXY_HTTP_TO_HTTPS_REDIRECT" "$proxy_redirect"
 

        web_endpoint_body=$(cat <<'EOF'
Where the OpenProject web application will be served.

Important: this installer expects the app to be reachable using the pattern:
    https://<DOMAIN>/<NAMESPACE>
    If you use no namespace, leave the Namespace prompt empty and serve at:
    https://<DOMAIN>/
EOF
)
    section "Web Endpoint URL Configuration" "$web_endpoint_body"

    domain_body=$(cat <<EOF
    https://{RESET}<DOMAIN>{BRONZE}{DIM}/<NAMESPACE>
EOF
)
    subsection "Domain Configuration:" "$domain_body"
    # Use centralized current_domain (populated by init_install_defaults) so a blank
    # value in the user's config file doesn't override the sensible default.
    # init_install_defaults is called earlier by interactive_config.sh.
    current_domain="${current_domain:-$(get_effective "DOMAIN_NAME" || true)}"
    prompt_with_default "Domain name (e.g., Statesmen.com)" "$current_domain" "domain_name"

    # Persist the selected domain immediately so subsequent steps/readers can use it.
    # Only save if the user provided a non-empty value; if they accepted the default
    # by pressing Enter we avoid writing an empty DOMAIN_NAME that would shadow the fallback.
    if [ -n "${domain_name:-}" ]; then
        save_config "DOMAIN_NAME" "$domain_name"
    fi

    # Show a live preview block of the resulting web endpoint using the provided domain and namespace
    # domain_name is set by prompt_with_default; fall back to current_domain
    preview_domain="${domain_name:-$current_domain}"
    preview_namespace="${current_namespace:-$(get_cfg "NAMESPACE")}" 
    # Determine scheme for preview based on HTTPS choice
    scheme="https"
    use_https_lc=$(echo "$use_https" | tr '[:upper:]' '[:lower:]')
    if [ "$use_https_lc" != "true" ]; then
        scheme="http"
    fi

    # Use shared UI helper to render a compact preview line
    if declare -f preview_web_endpoint >/dev/null 2>&1; then
        preview_web_endpoint "$preview_domain" "$preview_namespace" "$scheme"
    else
        # Fallback plain one-line preview
        if [ -n "$preview_namespace" ]; then
            echo "Preview URL: $scheme://$preview_domain/$preview_namespace"
        else
            echo "Preview URL: $scheme://$preview_domain/"
        fi
    fi

    namespace_body=$(cat <<EOF
Optional namespace used to namespace projects (leave empty for none).
https://${domain_name:-$current_domain}/{RESET}<NAMESPACE>{BRONZE}{DIM}
To keep an existing namespace you must retype it below.
EOF
)
    subsection "Namespace Configuration" "$namespace_body"
    current_namespace=$(get_cfg "NAMESPACE")

    if [ -n "$current_namespace" ]; then
        caution "To keep the current namespace [$current_namespace] you must retype it below; leaving the prompt empty will remove the namespace."
        prompt_with_default "Namespace (leave empty to remove current namespace, or enter new value)" "" "namespace"
    else
        echo "No namespace currently set"
        prompt_with_default "Namespace (e.g., StatesmenProjects, leave empty for none)" "" "namespace"
    fi

    # Persist namespace: if user provided a value, save it; if user left it empty
    # and a previous value exists in the config file, remove that line so the
    # generated default (if any) takes effect.
    if [ -n "${namespace:-}" ]; then
        save_config "NAMESPACE" "$namespace"
    else
        # Remove existing NAMESPACE entry from DEPLOY_CONFIG so the default applies
        if [ -f "${DEPLOY_CONFIG:-$SCRIPT_DIR/interactive_config.cfg}" ]; then
            if grep -q '^NAMESPACE=' "${DEPLOY_CONFIG:-$SCRIPT_DIR/interactive_config.cfg}" 2>/dev/null; then
                # Use sed to delete the line
                sed -i '/^NAMESPACE=/d' "${DEPLOY_CONFIG:-$SCRIPT_DIR/interactive_config.cfg}" 2>/dev/null || true
            fi
        fi
    fi

    

    # Reprint the preview after the namespace prompt so users see the final URL
    final_domain="${domain_name:-$current_domain}"
    final_namespace="${namespace:-$(get_cfg "NAMESPACE")}" 
    # Determine scheme again for the final preview
    final_scheme="https"
    if [ "${use_https_lc:-}" != "true" ]; then
        final_scheme="http"
    fi
    if declare -f preview_web_endpoint >/dev/null 2>&1; then
        preview_web_endpoint "$final_domain" "$final_namespace" "$final_scheme"
    else
        if [ -n "$final_namespace" ]; then
            echo "Preview URL: $final_scheme://$final_domain/$final_namespace"
        else
            echo "Preview URL: $final_scheme://$final_domain/"
        fi
    fi
}
