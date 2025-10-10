#!/bin/bash

# acme_duckdns_helper.sh
# Helper to obtain certificates for DuckDNS via acme.sh DNS-01
# Usage:
#   DUCKDNS_TOKEN=xxxx ./acme_duckdns_helper.sh myname.duckdns.org

set -euo pipefail

DOM="$1"
if [ -z "$DOM" ]; then
  echo "Usage: $0 <duckdns-domain>"
  exit 2
fi

if [ -z "${DUCKDNS_TOKEN:-}" ]; then
  echo "Please export DUCKDNS_TOKEN in your environment before running this helper."
  exit 2
fi

# Install acme.sh if not present
if ! command -v acme.sh >/dev/null 2>&1; then
  echo "acme.sh not found; installing..."
  curl https://get.acme.sh | sh
  export PATH="$HOME/.acme.sh:$PATH"
fi

# Use acme.sh with DuckDNS provider. acme.sh supports duckdns via 'dns_duckdns'
export DUCKDNS_TOKEN

# Issue certificate using DNS mode
~/.acme.sh/acme.sh --issue --dns dns_duckdns -d "$DOM"

# Install to the caddy certs dir
mkdir -p /etc/caddy/certs
~/.acme.sh/acme.sh --install-cert -d "$DOM" \
  --key-file /etc/caddy/certs/${DOM}.key \
  --fullchain-file /etc/caddy/certs/${DOM}.fullchain.pem

chown root:root /etc/caddy/certs/${DOM}.key /etc/caddy/certs/${DOM}.fullchain.pem
chmod 640 /etc/caddy/certs/${DOM}.key

echo "Installed certs to /etc/caddy/certs/${DOM}.*"
