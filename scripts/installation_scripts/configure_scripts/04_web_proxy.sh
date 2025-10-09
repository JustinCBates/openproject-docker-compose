#!/bin/bash
# Web and proxy configuration section

run_web_proxy() {
    if declare -f init_install_defaults >/dev/null 2>&1; then
        init_install_defaults
    fi
    web_host_body=$(cat <<EOF
Provide the public hostname where OpenProject will be served (e.g., example.com). 
Enable HTTPS if you have or will configure TLS certificates.
EOF
)
    subsection "Web Configuration" "$web_host_body"
    prompt_with_default "Enter the hostname for OpenProject" "$current_host" "host_name"
    prompt_with_default "Enable HTTPS? (true/false)" "$current_https" "use_https"

    echo
    proxy_intro_body=$(cat <<EOF
Proxy and TLS redirect settings.
EOF
)
    subsection "Web Configuration" "$proxy_intro_body"

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

    if validate_tf "Redirect HTTP to HTTPS?" "$default_redirect"; then
        proxy_redirect="true"
    else
        proxy_redirect="false"
    fi

    save_config "PROXY_HTTP_TO_HTTPS_REDIRECT" "$proxy_redirect"
    echo "✓ PROXY_HTTP_TO_HTTPS_REDIRECT set to: $proxy_redirect"
}
