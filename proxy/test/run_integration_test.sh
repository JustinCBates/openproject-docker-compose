#!/usr/bin/env bash
set -euo pipefail

# run_integration_test.sh
# Simple helper to run an isolated docker-compose project for testing the proxy
# behaviour against a minimal hello backend. All files (Caddyfile, compose, Dockerfile)
# are created in a temporary directory and a unique compose project name is used
# so that volumes/images/containers can be removed cleanly.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_DIR="$(cd "$BASE_DIR/.." && pwd)"
STATE_FILE="$BASE_DIR/integration_state"

cmd=${1:-up}
PROXY_HOST_PORT=${PROXY_HOST_PORT:-8082}

create_temp_project() {
        ts=$(date -u +%Y%m%dT%H%M%SZ)
        tmpdir=$(mktemp -d "$BASE_DIR/integration-$ts-XXXX")
        proj_name="openproject_integration_$ts"

        # copy current Caddyfile.template (user edits respected) unless NO_TLS requested
        if [ "${INTEGRATION_NO_TLS:-0}" = "1" ]; then
                cat > "$tmpdir/Caddyfile.template" <<'EOF'
:80 {
    reverse_proxy hello:8080
}
EOF
        else
            if [ -f "$PROXY_DIR/Caddyfile.template" ]; then
                cp "$PROXY_DIR/Caddyfile.template" "$tmpdir/Caddyfile.template"
            else
                echo "⚠ No Caddyfile.template found at $PROXY_DIR/Caddyfile.template" >&2
                exit 2
            fi
        fi

        # create a lightweight proxy Dockerfile that uses caddy:2 and the copied template
        # We avoid runtime substitution by copying the template to Caddy's config path.
        cat > "$tmpdir/Dockerfile" <<'EOF'
    FROM caddy:2
    COPY ./Caddyfile.template /etc/caddy/Caddyfile

ENTRYPOINT ["caddy", "run", "--config", "/etc/caddy/Caddyfile"]
EOF

        # copy hello app Dockerfile and app
        mkdir -p "$tmpdir/hello"
        cp "$PROXY_DIR/test/hello/Dockerfile" "$tmpdir/hello/Dockerfile"
        cp "$PROXY_DIR/test/hello/app.py" "$tmpdir/hello/app.py"

        # create a compose file that builds both proxy and hello in this tempdir
            # If NO_TLS, map host PROXY_HOST_PORT to container 80 (HTTP); otherwise map to 443 (HTTPS)
            target_port=443
            if [ "${INTEGRATION_NO_TLS:-0}" = "1" ]; then
                    target_port=80
            fi

                        cat > "$tmpdir/docker-compose.yml" <<EOF
                version: '3.8'
                services:
                    proxy:
                        build:
                            context: .
                            dockerfile: Dockerfile
                        image: openproject/proxy-integration-test:latest
                        environment:
                            - APP_HOST=hello
                        ports:
                            - "${PROXY_HOST_PORT}:${target_port}"
                        depends_on:
                            - hello

                    hello:
                        build:
                            context: ./hello
                            dockerfile: Dockerfile
                        image: openproject/proxy-hello-integration:latest
                        expose:
                            - "8080"

                networks:
                    default:
                        name: "${proj_name}_net"
EOF

        # record state
        cat > "$STATE_FILE" <<EOF
    TS=$ts
    PROJECT_DIR=$tmpdir
    PROJECT_NAME=$proj_name
PROXY_HOST_PORT=$PROXY_HOST_PORT
EOF
}

case "$cmd" in
    up)
        echo "Creating isolated integration project and starting services..."
        create_temp_project
        (cd "$tmpdir" && docker compose build --pull --no-cache)
        (cd "$tmpdir" && docker compose up -d)
        echo "Started integration proxy on host port ${PROXY_HOST_PORT}. To test: curl -k https://localhost:${PROXY_HOST_PORT}/"
        ;;
    down)
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
        echo "Tearing down project $PROJECT_NAME in $PROJECT_DIR"
        # prompt using /dev/tty when available so prompts are visible in redirected contexts
        if [ -c /dev/tty ]; then
            read -r -p "Press ENTER to confirm teardown (or Ctrl-C to abort)" < /dev/tty || true
        elif [ -t 0 ]; then
            read -r -p "Press ENTER to confirm teardown (or Ctrl-C to abort)" || true
        fi
        (cd "$PROJECT_DIR" && docker compose down)
    else
        echo "No integration state found; nothing to stop"
    fi
        ;;
    clean)
        if [ -f "$STATE_FILE" ]; then
                source "$STATE_FILE"
                echo "Cleaning project $PROJECT_NAME in $PROJECT_DIR"
                (cd "$PROJECT_DIR" && docker compose down -v --rmi local || true)
                rm -rf "$PROJECT_DIR"
                rm -f "$STATE_FILE"
        else
                echo "No integration state found; nothing to clean"
        fi
        ;;
    *)
        echo "Usage: $0 {up|down|clean}"
        exit 2
        ;;
esac
