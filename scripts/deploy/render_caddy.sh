#!/usr/bin/env bash
set -euo pipefail

# Render proxy/Caddyfile.template using gomplate and deploy into the running proxy container.
# Requirements: gomplate binary available on host, docker compose running with service name 'proxy'.

TEMPLATE="proxy/Caddyfile.template"
# Use mktemp for safer temp file creation
OUT_TMP=""
CONTAINER_PATH="/etc/caddy/Caddyfile"
DRY_RUN=0
VERBOSE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    -h|--help) echo "Usage: $0 [--dry-run] [--verbose]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

# Cleanup handler
cleanup() {
  if [ -n "${OUT_TMP}" ] && [ -f "${OUT_TMP}" ]; then
    rm -f "${OUT_TMP}"
  fi
}
trap cleanup EXIT

# Load .env if present (export vars)
if [ -f .env ]; then
  # shellcheck disable=SC1090
  set -a; . .env; set +a
fi

# Bridge common naming variants: prefer OPENPROJECT_HOST_NAME but fall back to OPENPROJECT_HOST__NAME
if [ -z "${OPENPROJECT_HOST_NAME:-}" ] && [ -n "${OPENPROJECT_HOST__NAME:-}" ]; then
  export OPENPROJECT_HOST_NAME="$OPENPROJECT_HOST__NAME"
  echo "WARN: setting OPENPROJECT_HOST_NAME from OPENPROJECT_HOST__NAME"
fi

echo "Using OPENPROJECT_HOST_NAME=${OPENPROJECT_HOST_NAME:-<unset>} RAILS_RELATIVE_URL_ROOT=${RAILS_RELATIVE_URL_ROOT:-<unset>}"

# Render using gomplate. If gomplate is not found, instruct how to install.
if ! command -v gomplate >/dev/null 2>&1; then
  echo "gomplate not found. Install it (https://github.com/hairyhenderson/gomplate) or use the deploy toolchain that bundles it." >&2
  exit 2
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "Error: template not found: $TEMPLATE" >&2
  exit 2
fi

OUT_TMP=$(mktemp /tmp/caddyfile.XXXXXX) || { echo "Error: failed to create temp file" >&2; exit 2; }
ERR_TMP="${OUT_TMP}.err"
cleanup() { rm -f "$OUT_TMP" "$ERR_TMP" || true; }
trap cleanup EXIT

if [ "$VERBOSE" -eq 1 ]; then echo "Rendering $TEMPLATE -> $OUT_TMP"; fi
# Render using gomplate with [[ ]] delimiters to avoid conflicts with Caddy braces
if ! gomplate --left-delim='[[' --right-delim=']]' -f "$TEMPLATE" -o "$OUT_TMP" 2>"$ERR_TMP"; then
  echo "ERROR: gomplate rendering failed; see $ERR_TMP" >&2
  sed -n '1,200p' "$ERR_TMP" >&2 || true
  exit 3
fi

# Prefer validating inside the proxy container; if not available, try local caddy adapt
validate_inside_proxy() {
  # check for a running compose proxy service by asking for the container id
  if command -v docker >/dev/null 2>&1; then
    cid=$(docker compose ps -q proxy 2>/dev/null || true)
    if [ -n "$cid" ]; then
      if docker compose exec -T proxy caddy adapt --config - < "$OUT_TMP" >/dev/null 2>&1; then
        return 0
      else
        return 1
      fi
    fi
  fi
  return 2
}

if validate_inside_proxy; then
  echo "caddy adapt OK (inside proxy container)."
else
  rc=$?
  if [ "$rc" -eq 2 ]; then
    echo "Proxy container not running; attempting local caddy adapt if available..."
    if command -v caddy >/dev/null 2>&1; then
      if caddy adapt --config "$OUT_TMP" >/dev/null 2>&1; then
        echo "caddy adapt OK (local)."
      else
        echo "ERROR: local caddy adapt failed." >&2
        caddy adapt --config "$OUT_TMP" 2>&1 | sed -n '1,200p' >&2 || true
        exit 4
      fi
    else
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "Warning: proxy not running and local caddy not available; skipping validation in dry-run mode."
      else
        echo "ERROR: cannot validate: proxy container not running and local 'caddy' binary not available." >&2
        exit 4
      fi
    fi
  else
    echo "ERROR: caddy adapt failed inside proxy container. Dumping validation output..." >&2
    docker compose exec -T proxy sh -c 'caddy adapt --config -' < "$OUT_TMP" 2>&1 | sed -n '1,200p' >&2 || true
    exit 5
  fi
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "Dry-run: validation passed; not deploying to $CONTAINER_PATH."
  exit 0
fi

# Deploy atomically into running proxy container
if command -v docker >/dev/null 2>&1 && docker compose ps -q proxy >/dev/null 2>&1; then
  echo "Deploying Caddyfile into proxy container ($CONTAINER_PATH) atomically..."
  docker compose exec -T proxy sh -c 'cat > $CONTAINER_PATH' < "$OUT_TMP"
  echo "Reloading Caddy..."
  docker compose exec -T proxy caddy reload --config $CONTAINER_PATH
  echo "Caddy reloaded successfully."
  exit 0
else
  echo "ERROR: proxy container not running; cannot deploy Caddyfile into container." >&2
  exit 6
fi
