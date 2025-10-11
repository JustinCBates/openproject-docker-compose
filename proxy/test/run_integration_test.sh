#!/usr/bin/env bash
set -euo pipefail

# run_integration_test.sh
# Simple helper to run an isolated docker-compose project for testing the proxy
# behaviour against a minimal hello backend. All files (Caddyfile, compose, Dockerfile)
# are created in a temporary directory and a unique compose project name is used
# so that volumes/images/containers can be removed cleanly.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_DIR="$(cd "$BASE_DIR/.." && pwd)"
TMP_ROOT="${TMPDIR:-/tmp}/network_probe"
STATE_FILE="$TMP_ROOT/openproject_integration_state"

# Ensure the fixed temp root exists and is owned by the current user
mkdir -p "$TMP_ROOT"
chown "$(id -u):$(id -g)" "$TMP_ROOT" 2>/dev/null || true

# Project root (repo) so we can locate installer helpers
PROJECT_ROOT="$(cd "$PROXY_DIR/.." && pwd)"

# Compose command to use (discovered at runtime)
COMPOSE_CMD=""

ensure_docker_available() {
    # Ensure docker exists and a compose command is available.
    if ! command -v docker >/dev/null 2>&1; then
        echo "docker not found — attempting to install via repository installer..."
        INSTALLER="$PROJECT_ROOT/scripts/installation_scripts/installation_utilities/install_docker.sh"
        if [ -x "$INSTALLER" ]; then
            # Let the installer decide privilege elevation if needed
            "$INSTALLER" || {
                echo "Automatic Docker installation failed; please install docker manually." >&2
                return 1
            }
        else
            echo "No installer found at $INSTALLER; please install Docker and Docker Compose manually." >&2
            return 2
        fi
    fi

    # Determine a compose command to use
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
    else
        echo "docker-compose support not found; attempting to install via repository installer..."
        INSTALLER="$PROJECT_ROOT/scripts/installation_scripts/installation_utilities/install_docker.sh"
        if [ -x "$INSTALLER" ]; then
            "$INSTALLER" || {
                echo "Automatic Docker Compose installation failed; please install docker-compose manually." >&2
                return 3
            }
            if docker compose version >/dev/null 2>&1; then
                COMPOSE_CMD="docker compose"
            elif command -v docker-compose >/dev/null 2>&1; then
                COMPOSE_CMD="docker-compose"
            else
                echo "Install succeeded but no compose command was detected. Please ensure 'docker compose' or 'docker-compose' is available." >&2
                return 4
            fi
        else
            echo "No installer found at $INSTALLER; please install Docker Compose manually." >&2
            return 5
        fi
    fi

    return 0
}

## CLI flags
FORCE=0
NO_BIND=0
PICK_PORT=0

# parse options until we reach the command (up|down|clean)
while [ "$#" -gt 0 ]; do
    case "$1" in
        --force|-f)
            FORCE=1; shift ;;
        --no-bind)
            NO_BIND=1; shift ;;
        --pick-port)
            PICK_PORT=1; shift ;;
        up|down|clean)
            cmd="$1"; shift; break ;;
        --help|-h)
            echo "Usage: $0 [--force] [--no-bind] [--pick-port] {up|down|clean}"; exit 0 ;;
        *)
            # unknown option - assume it's the command
            cmd="$1"; shift; break ;;
    esac
done

cmd=${cmd:-up}
PROXY_HOST_PORT=${PROXY_HOST_PORT:-8082}

find_free_port() {
    # Try to find a free TCP port on localhost. Prefer ss, fall back to netstat.
    start=18082
    end=18182
    for p in $(seq $start $end); do
        if command -v ss >/dev/null 2>&1; then
            if ! ss -ltn | grep -q ":${p}\b"; then
                echo "$p"; return 0
            fi
        elif command -v netstat >/dev/null 2>&1; then
            if ! netstat -lnt | grep -q ":${p}\b"; then
                echo "$p"; return 0
            fi
        else
            # no reliable checker; try to use nc for ports briefly
            if command -v nc >/dev/null 2>&1; then
                if ! nc -z localhost $p >/dev/null 2>&1; then
                    echo "$p"; return 0
                fi
            else
                # give a random port in high range
                rand=$(( (RANDOM % 40000) + 20000 ))
                echo "$rand"; return 0
            fi
        fi
    done
    # fallback random high port
    rand=$(( (RANDOM % 40000) + 20000 ))
    echo "$rand"
}

# Check whether the repository's compose stack (containers named like 'openproject*')
# is running and optionally prompt the user to take it down before starting the
# isolated integration project. Returns 0 when OK to proceed, non-zero to abort.
check_repo_stack_running() {
    # Require docker to be present
    if ! command -v docker >/dev/null 2>&1; then
        echo "docker not found; cannot check for running repository stack." >&2
        return 0
    fi

    # Determine a probable project name (default to repo dir name); compose usually
    # uses the directory name as project name unless overridden.
    repo_project_name=$(basename "$PROJECT_ROOT")

    # First, look specifically for containers with the compose project label.
    label_matches=$(docker ps --filter "label=com.docker.compose.project=${repo_project_name}" --format '{{.ID}} {{.Names}} {{.Labels}} {{.Ports}}' || true)

    # Next, detect containers binding any monitored host ports (these could be from any service)
    ports_to_check="${PROXY_HOST_PORT} 80 443"
    port_matches=""
    for p in $ports_to_check; do
        # docker ps Ports output can be like "0.0.0.0:8082->443/tcp, :::8082->443/tcp" or ":8082->443/tcp"
        m=$(docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' | grep -E "(:|0.0.0.0:|::):${p}(-|->|,|$)" || true)
        if [ -n "$m" ]; then
            # append unique lines
            port_matches="$port_matches\n$m"
        fi
    done

    # If neither label nor port matches found, nothing to do
    if [ -z "$label_matches" ] && [ -z "$port_matches" ]; then
        return 0
    fi

    echo "Detected potential conflicts:"
    if [ -n "$label_matches" ]; then
        echo "- Containers from a compose project named '${repo_project_name}':"
        echo "$label_matches"
    fi
    if [ -n "$port_matches" ]; then
        echo "- Containers binding monitored host ports (${ports_to_check}):"
        # cleanup leading newline for printing
        echo -e "${port_matches#\n}"
    fi

    # If we found compose-labeled containers, they are likely the repo stack — prefer
    # to run 'docker compose down -v' (safer/cleaner) when the user agrees.
    if [ -n "$label_matches" ]; then
        if [ "${FORCE:-0}" = "1" ]; then
            echo "Force mode: taking down repository compose stack via compose down -v"
            (cd "$PROJECT_ROOT" && $COMPOSE_CMD down -v) || {
                echo "Failed to take down the repository compose stack." >&2
                return 1
            }
            return 0
        fi

        if [ -c /dev/tty ]; then
            read -r -p "Take down the repository compose stack and continue? [y/N]: " ans </dev/tty || true
        elif [ -t 0 ]; then
            read -r -p "Take down the repository compose stack and continue? [y/N]: " ans || true
        else
            echo "Non-interactive session and compose-labeled containers found. Re-run with --force to take it down automatically." >&2
            return 2
        fi

        case "${ans:-}" in
            y|Y|yes)
                echo "Taking down repository compose stack..."
                (cd "$PROJECT_ROOT" && $COMPOSE_CMD down -v) || {
                    echo "Failed to take down the repository compose stack." >&2
                    return 1
                }
                ;;
            *)
                echo "Aborting per user choice." >&2
                return 3
                ;;
        esac

        return 0
    fi

    # If we get here, only port-based conflicts were found (no compose labels). Be
    # conservative: list the containers and ask whether to stop those specific
    # containers instead of running a repo-wide compose down.
    # Build a unique list of container IDs from port_matches
    ids=$(echo -e "${port_matches#\n}" | awk '{print $1}' | sort -u | tr '\n' ' ')

    if [ -z "$ids" ]; then
        return 0
    fi

    echo "The following containers appear to bind ports used by the integration test:"
    docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Ports}}' | grep -E "($(echo $ids | tr ' ' '|'))" || true

    if [ "${FORCE:-0}" = "1" ]; then
        echo "Force mode: stopping these containers: $ids"
        docker stop $ids || true
        docker rm -f $ids || true
        return 0
    fi

    if [ -c /dev/tty ]; then
        read -r -p "Stop these containers and continue? [y/N]: " ans </dev/tty || true
    elif [ -t 0 ]; then
        read -r -p "Stop these containers and continue? [y/N]: " ans || true
    else
        echo "Non-interactive session and port conflicts found. Re-run with --force to stop conflicting containers." >&2
        return 2
    fi

    case "${ans:-}" in
        y|Y|yes)
            echo "Stopping containers: $ids"
            docker stop $ids || true
            docker rm -f $ids || true
            ;;
        *)
            echo "Aborting per user choice." >&2
            return 3
            ;;
    esac

    return 0
}

create_temp_project() {
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    tmpdir=$(mktemp -d "$TMP_ROOT/openproject_integration_${ts}_XXXX")
        proj_name="openproject_integration_$ts"

        # Always create a simple, valid Caddyfile for the integration project.
        # This keeps the integration test deterministic and avoids template parsing
        # issues inside the temporary image. If INTEGRATION_NO_TLS=0 we still
        # provide a minimal TLS listener, but skip ACME for speed.
        if [ "${INTEGRATION_NO_TLS:-0}" = "1" ]; then
            cat > "$tmpdir/Caddyfile" <<'EOF'
:80 {
    reverse_proxy hello:8080
}
EOF
        else
            # Simple HTTPS listener on 443 that uses internal TLS to avoid ACME in tests
            cat > "$tmpdir/Caddyfile" <<'EOF'
:443 {
    tls internal
    reverse_proxy hello:8080
}
EOF
        fi

        # create a lightweight proxy Dockerfile that uses caddy:2 and the copied template
        # We avoid runtime substitution by copying the template to Caddy's config path.
    cat > "$tmpdir/Dockerfile" <<'EOF'
FROM caddy:2
# Install curl for runtime diagnostics in the integration-test proxy container.
# caddy:2 is based on alpine, so use apk. Keep the image small by cleaning apk cache.
RUN apk add --no-cache curl
COPY ./Caddyfile /etc/caddy/Caddyfile

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
        echo "Preparing to create isolated integration project..."
        ensure_docker_available || exit 1

        # If user asked to pick a port, find one now
        if [ "${PICK_PORT:-0}" = "1" ]; then
            found_port=$(find_free_port)
            echo "Auto-picked free host port: $found_port"
            PROXY_HOST_PORT=$found_port
        fi

        # Check for conflicts and offer alternatives (stop containers / no-bind / pick-port)
        check_repo_stack_running || {
            # If check_repo_stack_running returned non-zero, it indicates the user aborted
            # or non-interactive session without --force. Exit with error.
            echo "Cannot proceed due to running containers or user aborted." >&2
            exit 1
        }

        echo "Creating isolated integration project and starting services..."
        create_temp_project
        (cd "$tmpdir" && $COMPOSE_CMD build --pull --no-cache)
        (cd "$tmpdir" && $COMPOSE_CMD up -d)
        if [ "${NO_BIND:-0}" = "1" ]; then
            echo "Started integration proxy WITHOUT host port binding (in-network only)."
            echo "To test from the host, you can exec into the proxy container and curl the backend."
        else
            echo "Started integration proxy on host port ${PROXY_HOST_PORT}. To test: curl -k https://localhost:${PROXY_HOST_PORT}/"
        fi
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
        ensure_docker_available || true
        (cd "$PROJECT_DIR" && $COMPOSE_CMD down)
    else
        echo "No integration state found; nothing to stop"
    fi
        ;;
    clean)
        if [ -f "$STATE_FILE" ]; then
            source "$STATE_FILE"
        echo "Cleaning project $PROJECT_NAME in $PROJECT_DIR"
        ensure_docker_available || true
        (cd "$PROJECT_DIR" && $COMPOSE_CMD down -v --rmi local || true)
            rm -rf "$PROJECT_DIR"
            rm -f "$STATE_FILE"
            # If using the fixed TMP_ROOT directory, remove it when empty
            if [ -d "$TMP_ROOT" ]; then
                # remove leftover network_probe dirs older than 1 hour as a safe cleanup
                find "$TMP_ROOT" -maxdepth 1 -type d -name 'openproject_integration_*' -mmin +60 -exec rm -rf {} + || true
            fi
        else
                echo "No integration state found; nothing to clean"
        fi
        ;;
    *)
        echo "Usage: $0 {up|down|clean}"
        exit 2
        ;;
esac
