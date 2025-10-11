#!/usr/bin/env bash
# Quick diagnostics for proxy/HTTPS/relroot routing.
# Produces a timestamped log under ./logs and prints a short summary + advice.

set -euo pipefail
umask 027

TIMESTAMP=$(date -u +%Y%m%dT%H%M%SZ)
LOGDIR="${PWD}/logs"
mkdir -p "$LOGDIR"
LOGFILE="${LOGDIR}/diagnostics-${TIMESTAMP}.log"

# Configurable defaults (override with environment)
PROXY_HOST="${PROXY_HOST:-${OPENPROJECT_HOST_NAME:-${OPENPROJECT_HOST__NAME:-srv1035368.hstgr.cloud}}}"
PROXY_IP="${PROXY_IP:-127.0.0.1}"
RELROOT="${RELROOT:-${RAILS_RELATIVE_URL_ROOT:-/StatesmenProjects}}"
UPSTREAM="${UPSTREAM:-web}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-443}"
COMPOSE_CMD="${COMPOSE_CMD:-docker compose}"

# helpers
log() { printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOGFILE"; }
run_local() { log "\$ $*"; eval "$@" 2>&1 | tee -a "$LOGFILE"; }
run_compose_exec() {
  local svc=$1; shift
  log "exec in $svc: $*"
  # Use -T to avoid allocating a tty
  if ! $COMPOSE_CMD exec -T "$svc" sh -c "$*" >>"$LOGFILE" 2>&1 ; then
    log "COMMAND FAILED: exec $svc -> $*"
    return 1
  fi
}

log "=== diagnostics started ==="
log "PROXY_HOST=$PROXY_HOST PROXY_IP=$PROXY_IP RELROOT=$RELROOT UPSTREAM=$UPSTREAM"

# 0) quick check compose available and containers running
if ! command -v docker >/dev/null 2>&1; then
  log "ERROR: docker not found in PATH"
  echo "ERROR: docker not available; cannot run probes. See $LOGFILE" >&2
  exit 2
fi

log "Checking docker compose status..."
if ! $COMPOSE_CMD ps --quiet >/dev/null 2>&1; then
  log "WARNING: docker compose returned non-zero; ensure you run from repo root with compose files."
fi

# 1) upstream app health from 'web' container (localhost:8080)
log "1) Upstream app health (from web container -> http://localhost:8080${RELROOT}/health_checks/default)"
if ! run_compose_exec "$UPSTREAM" "curl -sS -o /tmp/_probe_upstream_body -w '%{http_code}' http://localhost:8080${RELROOT}/health_checks/default"; then
  UPSTREAM_CODE="ERR"
else
  UPSTREAM_CODE=$( $COMPOSE_CMD exec -T "$UPSTREAM" sh -c "curl -sS -o /tmp/_probe_upstream_body -w '%{http_code}' http://localhost:8080${RELROOT}/health_checks/default" 2>/dev/null || echo "ERR" )
fi
log "Upstream HTTP status: ${UPSTREAM_CODE}"
run_compose_exec "$UPSTREAM" "head -c 200 /tmp/_probe_upstream_body || true"

# 2) proxy -> web network probe (from proxy container to web by service name)
log "2) Proxy container -> web service (http://web:8080${RELROOT}/health_checks/default)"
if ! run_compose_exec proxy "curl -sS -o /tmp/_probe_proxy_web_body -w '%{http_code}' http://web:8080${RELROOT}/health_checks/default"; then
  PROXY_WEB_CODE="ERR"
else
  PROXY_WEB_CODE=$( $COMPOSE_CMD exec -T proxy sh -c "curl -sS -o /tmp/_probe_proxy_web_body -w '%{http_code}' http://web:8080${RELROOT}/health_checks/default" 2>/dev/null || echo "ERR" )
fi
log "proxy->web HTTP status: ${PROXY_WEB_CODE}"
run_compose_exec proxy "head -c 200 /tmp/_probe_proxy_web_body || true"

# 3) Validate active Caddyfile inside proxy
log "3) Caddyfile present in proxy: /etc/caddy/Caddyfile"
if ! $COMPOSE_CMD exec -T proxy sh -c 'cat /etc/caddy/Caddyfile' >>"$LOGFILE" 2>&1; then
  log "ERROR: /etc/caddy/Caddyfile not accessible in proxy container"
  CADDYFILE_PRESENT=0
else
  CADDYFILE_PRESENT=1
fi

log "Running caddy adapt --config /etc/caddy/Caddyfile"
if $COMPOSE_CMD exec -T proxy sh -c 'caddy adapt --config /etc/caddy/Caddyfile >/dev/null' >>"$LOGFILE" 2>&1; then
  CADDY_ADAPT="OK"
else
  CADDY_ADAPT="FAIL"
fi
log "caddy adapt: ${CADDY_ADAPT}"

# 4) External HTTPS probe (SNI + Host) to relroot health endpoint
EXT_URL="https://${PROXY_HOST}${RELROOT}/health_checks/default"
log "4) External HTTPS probe: $EXT_URL (resolve ${PROXY_HOST}:${HTTPS_PORT} -> ${PROXY_IP})"
if curl -sS -k -I --resolve "${PROXY_HOST}:${HTTPS_PORT}:${PROXY_IP}" -H "Host: ${PROXY_HOST}" "$EXT_URL" -m 15 >>"$LOGFILE" 2>&1; then
  EXT_STATUS=$(curl -sS -k -I --resolve "${PROXY_HOST}:${HTTPS_PORT}:${PROXY_IP}" -H "Host: ${PROXY_HOST}" "$EXT_URL" -m 15 | head -n1 | awk '{print $2}')
else
  EXT_STATUS="ERR"
fi
log "External HTTP status: ${EXT_STATUS}"
# capture a sample of response headers
run_local "curl -sS -k -I --resolve '${PROXY_HOST}:${HTTPS_PORT}:${PROXY_IP}' -H 'Host: ${PROXY_HOST}' '${EXT_URL}' | sed -n '1,40p'"

# 5) TLS certificate inspection (openssl s_client)
log "5) TLS certificate inspection (s_client) -> ${PROXY_IP}:${HTTPS_PORT} (SNI=${PROXY_HOST})"
if timeout 10 openssl s_client -connect "${PROXY_IP}:${HTTPS_PORT}" -servername "${PROXY_HOST}" </dev/null 2>>"$LOGFILE" | sed -n '1,120p' >>"$LOGFILE" 2>&1; then
  TLS_OK=1
else
  TLS_OK=0
fi

# extract cert CN/SAN if possible
CERT_SUBJECT=$(timeout 5 openssl s_client -connect "${PROXY_IP}:${HTTPS_PORT}" -servername "${PROXY_HOST}" </dev/null 2>/dev/null | openssl x509 -noout -subject 2>/dev/null || true)
CERT_SANS=$(timeout 5 openssl s_client -connect "${PROXY_IP}:${HTTPS_PORT}" -servername "${PROXY_HOST}" </dev/null 2>/dev/null | openssl x509 -noout -text 2>/dev/null | sed -n '/Subject Alternative Name/,/X509/ p' || true)
log "cert subject: ${CERT_SUBJECT:-<none>}"
log "cert SAN block snippet: $(echo "$CERT_SANS" | head -n 10 | tr '\n' ' ' | sed 's/  */ /g')"

# 6) logs tail
log "6) Tail last 120 lines of proxy and web logs"
run_local "$COMPOSE_CMD logs proxy --tail 120"
run_local "$COMPOSE_CMD logs web --tail 120"

# Summarize and give short advice
log "=== SUMMARY ==="
log "upstream(local) = ${UPSTREAM_CODE}"
log "proxy->web      = ${PROXY_WEB_CODE}"
log "caddy adapt     = ${CADDY_ADAPT}"
log "external status = ${EXT_STATUS}"
log "tls probe ok    = ${TLS_OK}"

echo
echo "Short advice (from diagnostics) — see $LOGFILE for details:"
if [[ "${UPSTREAM_CODE}" != "200" && "${UPSTREAM_CODE}" != "302" && "${UPSTREAM_CODE}" != "401" ]]; then
  echo "- Upstream app did NOT return expected health (200/302/401). Check the 'web' container logs and ensure the Rails app is started and listening on :8080."
fi

if [[ "${PROXY_WEB_CODE}" == "ERR" || ("${PROXY_WEB_CODE}" != "200" && "${PROXY_WEB_CODE}" != "302" && "${PROXY_WEB_CODE}" != "401") ]]; then
  echo "- Proxy container cannot reach the web service at web:8080${RELROOT}. Check Docker network and that the 'web' service is healthy."
fi

if [[ "${CADDY_ADAPT}" != "OK" ]]; then
  echo "- Caddy configuration failed validation. Inspect the rendered /etc/caddy/Caddyfile and fix template rendering (see $LOGFILE)."
fi

if [[ "${EXT_STATUS}" == "404" && "${PROXY_WEB_CODE}" =~ ^(200|302|401)$ ]]; then
  echo "- External request returned 404 while proxy->web succeeded. Likely Caddy path matching/handler issue — ensure the template matches '${RELROOT}*' and preserves the path when proxying."
fi

if [[ "${EXT_STATUS}" == "ERR" ]]; then
  echo "- External HTTPS probe failed. Check that Caddy is listening on ${HTTPS_PORT} and that firewall/DNS/SNI settings are correct."
fi

if [[ "${TLS_OK}" -eq 0 ]]; then
  echo "- TLS handshake failed; inspect certificate presence, PROXY_TLS_MODE, and whether cert files are mounted in the proxy container."
else
  if echo "${CERT_SUBJECT}" | grep -qi "${PROXY_HOST}"; then
    echo "- TLS certificate subject matches host."
  else
    echo "- Certificate subject/SAN did not list ${PROXY_HOST}. For ACME check DNS record and that ACME can validate the host."
  fi
fi

log "=== diagnostics complete ==="
echo "Full log: $LOGFILE"
exit 0
