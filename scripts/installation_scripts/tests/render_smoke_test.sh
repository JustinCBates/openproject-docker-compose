#!/usr/bin/env bash
set -euo pipefail

# Simple smoke tests for config_render.sh behavior
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/common/config_render.sh"

run_case() {
    local desc="$1"
    shift
    echo "--- $desc ---"
    # create a temporary defaults and config file
    local tmpd
    tmpd=$(mktemp -d)
    trap 'rm -rf "$tmpd"' RETURN

    # write defaults file (we'll vary inputs by environment)
    cat > "$tmpd/interactive_config.cfg.defaults" <<EOF
DOMAIN_NAME="example.com"
URI_NAMESPACE="myproj"
EOF

    # optional override via passed env variables
    if [ "$#" -gt 0 ]; then
        env -i PATH="$PATH" "$@" \
            bash -c "source $ROOT/common/config_render.sh && detect_deployment_values \"$ROOT\" \"$tmpd/interactive_config.cfg.defaults\" \"$tmpd/interactive_config.cfg\" && render_env"
    else
        env -i PATH="$PATH" \
            bash -c "source $ROOT/common/config_render.sh && detect_deployment_values \"$ROOT\" \"$tmpd/interactive_config.cfg.defaults\" \"$tmpd/interactive_config.cfg\" && render_env"
    fi
}


# Case A: default behavior (no explicit relative root)
run_case "default (no explicit relative root)"

echo "Smoke tests completed"
