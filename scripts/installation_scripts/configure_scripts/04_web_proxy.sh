#!/bin/bash
# Web and proxy configuration section

run_web_proxy() {
    #----------------------------------------------------------------------------------
    # Web Configuration
    #----------------------------------------------------------------------------------
    web_host_body=$(cat <<'EOF'
Provide the public hostname where OpenProject will be served (e.g., example.com).
Enable HTTPS if you have or will configure TLS certificates.
__________________________________________________________________________________
EOF
)
    section "Web Configuration" "$web_host_body"

    # Subsection: Hostname prompt
    subsection "Hostname" "Provide the public hostname where OpenProject will be served (e.g., example.com)."
    prompt_with_default "Enter the hostname for OpenProject" "$current_host" "host_name"
    # Persist host name immediately so other modules/utilities can use it
    if [ -n "${host_name:-}" ]; then
        save_config "OPENPROJECT_HOST_NAME" "$host_name"
    fi

    # Determine default for HTTPS prompt:
    # - If user already has OPENPROJECT_HTTPS in their persistent .cfg, prefer that.
    # - Else if environment is localdev, default to false to ease local development.
    # - Otherwise fall back to the current effective value.
    cfg_https=$(get_cfg "OPENPROJECT_HTTPS" || true)
    if [ -n "$cfg_https" ]; then
        default_https="$cfg_https"
    else
        cfg_env_type=$(get_cfg "ENVIRONMENT_TYPE" || true)
        if [ -n "$cfg_env_type" ]; then
            env_type="$cfg_env_type"
        else
            env_type=$(get_effective "ENVIRONMENT_TYPE" || true)
        fi
        if [ "$env_type" = "localdev" ]; then
            default_https="false"
        else
            default_https="$current_https"
        fi
    fi

    # Use validate_tf so inputs like 't'/'f' are normalized to literal 'true'/'false'
    # and exported into the caller variable 'use_https'.
    # NOTE: validate_tf returns non-zero when the user answers 'false'.
    # Because the orchestrator (`interactive_config.sh`) sets `set -e`, a
    # bare call here would cause the whole script to exit when the user
    # selects the default 'false'. Wrap the call in an if/then to consume
    # the exit status, matching the pattern used later for proxy_redirect.
    # Subsection: HTTPS
    subsection "Enable HTTPS" "Enable HTTPS if you have or will configure TLS certificates."
    if validate_tf "Enable HTTPS?" "$default_https" use_https; then
        : # use_https set to 'true'
    else
        : # use_https set to 'false'
    fi

    # Persist HTTPS selection immediately (save_config normalizes booleans)
    if [ -n "${use_https:-}" ]; then
        save_config "OPENPROJECT_HTTPS" "$use_https"
    fi

    # Determine default for redirects based on HTTPS selection and environment.
    use_https_lc=$(echo "$use_https" | tr '[:upper:]' '[:lower:]')
    if [ "$use_https_lc" = "true" ]; then
        default_redirect="true"
    else
        default_redirect="false"
    fi

    # Rule: for localdev/remotedev, if the user has NOT explicitly set
    # PROXY_HTTPS_REDIRECT in their .cfg, default the redirect to false so
    # local/staging dev instances don't force HTTPS by default.
    cfg_redirect=$(get_cfg "PROXY_HTTPS_REDIRECT" || true)
    if [ -z "$cfg_redirect" ]; then
        env_type=$(get_effective "ENVIRONMENT_TYPE" || true)
        case "$env_type" in
            localdev|remotedev)
                default_redirect="false"
                ;;
        esac
    fi

    # Proxy HTTPS redirect configuration (moved before bind/port prompts)
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

    save_config "PROXY_HTTPS_REDIRECT" "$proxy_redirect"

    # Prompt for proxy bind address and ports to handle firewall/router setups.
    subsection "Proxy bind and port configuration" "If your host has a firewall or needs a specific bind interface, set the bind IP and port values here."
    # Determine defaults from get_effective or current values
    default_bind=$(get_effective "PROXY_BIND_ADDRESS" || echo "0.0.0.0")
    prompt_with_default "Proxy bind IP (0.0.0.0 to listen on all interfaces)" "$default_bind" "proxy_bind"
    if [ -n "${proxy_bind:-}" ]; then
        save_config "PROXY_BIND_ADDRESS" "$proxy_bind"
    fi

    # Subsection: Ports
    subsection "Proxy ports" "Specify the HTTP and HTTPS ports the proxy should listen on."

    default_http_port=$(get_effective "PROXY_HTTP_PORT" || echo "80")
    prompt_with_default "Proxy HTTP port" "$default_http_port" "proxy_http_port"
    if [ -n "${proxy_http_port:-}" ]; then
        save_config "PROXY_HTTP_PORT" "$proxy_http_port"
    fi

    default_https_port=$(get_effective "PROXY_HTTPS_PORT" || echo "443")
    prompt_with_default "Proxy HTTPS port" "$default_https_port" "proxy_https_port"
    if [ -n "${proxy_https_port:-}" ]; then
        save_config "PROXY_HTTPS_PORT" "$proxy_https_port"
    fi

    # TLS mode selection
    tls_default=$(get_effective "PROXY_TLS_MODE" || echo "internal")
        section "TLS mode selection" "Choose how the proxy should obtain TLS certificates."

        tls_modes_body=$(cat <<'EOF'
Options:
    1) internal
         - Caddy internal CA. Automatically issues certificates signed by Caddy's
             internal CA which is suitable for testing and development only.
         - Certificates will not be trusted by browsers by default; you must
             import Caddy's CA into client trust stores if you need browser trust.
         - This mode is useful when you cannot reach the public Internet or
             when running ephemeral/test environments where real certificates are
             unnecessary.

    2) letsencrypt_staging
         - Use Let's Encrypt's staging environment (ACME) to obtain test
             certificates. The staging CA issues certificates much faster and
             without rate limits, but they are not trusted by browsers.
         - Use this mode to validate ACME automation and DNS/HTTP challenges
             without hitting production limits.

    3) letsencrypt_prod
         - Use Let's Encrypt production (ACME) to obtain valid, browser-trusted
             certificates.
         - Requires your host to be reachable on public ports 80 and 443 and a
             valid DNS name pointing to the host. Automated issuance may fail if
             ports are blocked or DNS is misconfigured.
         - Recommended for production sites that serve real users.

    4) acme_duckdns
         - Use the third-party `acme.sh` client with DuckDNS via DNS-01
             challenges to obtain certificates. This flow is helpful when you
             cannot expose ports 80/443 for HTTP-01 challenges but can create
             DNS records on DuckDNS.
         - You will need a DuckDNS token and subdomain; the installer will
             prompt for those credentials if you choose this mode.

Notes:
    - When using production issuance (`letsencrypt_prod`) ensure your
        firewall/NAT forwards ports 80 and 443 to the proxy and that DNS
        resolves to this host. Failure to meet these requirements will prevent
        certificate issuance.
    - For testing and development prefer `internal` or `letsencrypt_staging`.
EOF
)
        subsection "TLS mode details" "$tls_modes_body"

    # Print a dedicated header and then a separate numbered list so the UI
    # appears as two distinct prompt blocks to the user.
    # Provide an explicit header so numbered_list_prompt treats the following
    # args as selectable items instead of accidentally interpreting the first
    # token as a header when items do not include a ' - ' separator.
    echo
    numbered_list_prompt "${tls_default}" tls_choice tls_choice_idx "Available TLS modes:" "internal" "letsencrypt_staging" "letsencrypt_prod" "acme_duckdns"
    # Map numeric selection to canonical value
    case "$tls_choice" in
        internal) tls_mode="internal" ;;
        letsencrypt_staging) tls_mode="letsencrypt_staging" ;;
        letsencrypt_prod) tls_mode="letsencrypt_prod" ;;
        acme_duckdns) tls_mode="acme_duckdns" ;;
        *) tls_mode="$tls_default" ;;
    esac
    save_config "PROXY_TLS_MODE" "$tls_mode"

    # If user selected DuckDNS/DNS-01 flow, ask for DuckDNS subdomain and token
    if [ "$tls_mode" = "acme_duckdns" ]; then
        subsection "DuckDNS settings" "Provide DuckDNS credentials for DNS-01 issuance via acme.sh"
        prompt_with_default "DuckDNS subdomain (example: myname.duckdns.org)" "$(get_effective "DOMAIN_NAME" || true)" "duckdns_domain"
        prompt_with_default "DuckDNS token (kept in config file)" "" "duckdns_token"
        if [ -n "${duckdns_domain:-}" ]; then save_config "DOMAIN_NAME" "$duckdns_domain"; fi
        if [ -n "${duckdns_token:-}" ]; then save_config "DUCKDNS_TOKEN" "$duckdns_token"; fi
    fi

    echo

    use_https_lc=$(echo "$use_https" | tr '[:upper:]' '[:lower:]')
    if [ "$use_https_lc" = "true" ]; then
        default_redirect="true"
    else
        default_redirect="false"
    fi

    # Rule: for localdev/remotedev, if the user has NOT explicitly set
    # PROXY_HTTPS_REDIRECT in their .cfg, default the redirect to false so
    # local/staging dev instances don't force HTTPS by default.
    cfg_redirect=$(get_cfg "PROXY_HTTPS_REDIRECT" || true)
    if [ -z "$cfg_redirect" ]; then
        env_type=$(get_effective "ENVIRONMENT_TYPE" || true)
        case "$env_type" in
            localdev|remotedev)
                default_redirect="false"
                ;;
        esac
    fi

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
    # New flow: ask whether to enable namespace; prefer value from .cfg and fall back to defaults
    current_namespace=$(get_cfg "NAMESPACE" || true)
    default_namespace_enabled=$(get_effective "NAMESPACE_ENABLED" || echo "false")
    # validate_tf will normalize to true/false into namespace_enabled variable
    if validate_tf "Enable namespace support? (true/false)" "$default_namespace_enabled" namespace_enabled; then
        :
    else
        :
    fi
    save_config "NAMESPACE_ENABLED" "$namespace_enabled"

    # If namespace support is enabled, ask for the namespace value. Default to
    # the value found in the user's .cfg (so we don't overwrite with blank).
    if [ "${namespace_enabled:-false}" = "true" ]; then
        if [ -n "$current_namespace" ]; then
            caution "To keep the current namespace [$current_namespace] you must retype it below; leaving the prompt empty will remove the namespace."
            prompt_with_default "Namespace (leave empty to remove current namespace, or enter new value)" "" "namespace"
        else
            echo "No namespace currently set"
            # Use the default from get_effective (which reads .cfg then defaults)
            prompt_with_default "Namespace (e.g., StatesmenProjects, leave empty for none)" "$(get_effective "NAMESPACE" || true)" "namespace"
        fi
        if [ -n "${namespace:-}" ]; then
            save_config "NAMESPACE" "$namespace"
        else
            # If user left it empty, remove any existing NAMESPACE entry so defaults apply
            if [ -f "${DEPLOY_CONFIG:-$SCRIPT_DIR/interactive_config.cfg}" ]; then
                if grep -q '^NAMESPACE=' "${DEPLOY_CONFIG:-$SCRIPT_DIR/interactive_config.cfg}" 2>/dev/null; then
                    sed -i '/^NAMESPACE=/d' "${DEPLOY_CONFIG:-$SCRIPT_DIR/interactive_config.cfg}" 2>/dev/null || true
                fi
            fi
        fi
    else
        # Namespace disabled: ensure NAMESPACE is removed from persistent config
        if [ -f "${DEPLOY_CONFIG:-$SCRIPT_DIR/interactive_config.cfg}" ]; then
            sed -i '/^NAMESPACE=/d' "${DEPLOY_CONFIG:-$SCRIPT_DIR/interactive_config.cfg}" 2>/dev/null || true
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
