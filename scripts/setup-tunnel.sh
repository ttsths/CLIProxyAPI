#!/usr/bin/env bash
#
# Setup Cloudflare Tunnel for CLIProxyAPI
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "======================================"
echo "CLIProxyAPI Cloudflare Tunnel Setup"
echo "======================================"
echo

# --- Detect if we can use docker compose ---
if command -v docker-compose &>/dev/null; then
  COMPOSE="docker-compose"
elif docker compose version &>/dev/null; then
  COMPOSE="docker compose"
else
  echo "Error: docker compose not found."
  exit 1
fi

# --- Mode selection ---
echo "Select setup method:"
echo "1) Token mode (recommended) - use Cloudflare Zero Trust Dashboard token"
echo "2) Self-created tunnel mode - generate credentials locally"
echo
read -r -p "Enter choice [1-2]: " choice

case "$choice" in
  1)
    echo
    echo "Token Mode selected."
    echo
    echo "Steps to get your token:"
    echo "  1. Open https://dash.teams.cloudflare.com/"
    echo "     (or https://one.dash.cloudflare.com/)"
    echo "  2. Go to Access > Tunnels"
    echo "  3. Create a tunnel named 'cli-proxy-api'"
    echo "  4. In 'Public Hostname', add:"
    echo "       Subdomain: (your choice, e.g. proxy)"
    echo "       Domain:    (your domain)"
    echo "       Type:      HTTP"
    echo "       URL:       http://cli-proxy-api:8317"
    echo "  5. Save and copy the tunnel token string (starts with eyJ...)"
    echo
    read -r -p "Paste your CF_TUNNEL_TOKEN: " token
    token="${token// /}"
    if [[ -z "$token" ]]; then
      echo "Error: token cannot be empty."
      exit 1
    fi
    echo "CF_TUNNEL_TOKEN=${token}" >> .env
    echo "Token saved to .env"
    echo
    echo "Start with: ${COMPOSE} up -d"
    ;;

  2)
    echo
    echo "Self-created Tunnel Mode selected."
    echo

    # Ensure cloudflared dir exists
    mkdir -p "${ROOT_DIR}/cloudflared"

    echo "Creating tunnel..."
    docker run --rm -v "${ROOT_DIR}/cloudflared:/etc/cloudflared" \
      cloudflare/cloudflared:latest tunnel create cli-proxy-api

    echo
    echo "Tunnel created. Credential file saved to ./cloudflared/"
    echo
    read -r -p "Enter your domain (e.g. example.com): " domain
    read -r -p "Enter subdomain (e.g. proxy): " subdomain
    hostname="${subdomain}.${domain}"

    # Find the credential JSON file (only one should exist now if dir was empty)
    cred_file=$(find "${ROOT_DIR}/cloudflared" -maxdepth 1 -name "*.json" | head -n1)
    if [[ -z "$cred_file" ]]; then
      echo "Error: no tunnel credential JSON found in ./cloudflared/"
      exit 1
    fi
    tunnel_id=$(basename "$cred_file" .json)

    echo "Routing DNS ${hostname} -> tunnel ${tunnel_id} ..."
    docker run --rm -v "${ROOT_DIR}/cloudflared:/etc/cloudflared" \
      cloudflare/cloudflared:latest tunnel route dns "${tunnel_id}" "${hostname}"

    # Write final config.yml
    cat > "${ROOT_DIR}/cloudflared/config.yml" <<EOF
tunnel: ${tunnel_id}
credentials-file: /etc/cloudflared/${tunnel_id}.json

ingress:
  - hostname: ${hostname}
    service: http://cli-proxy-api:8317
  - service: http_status:404
EOF

    echo
    echo "Config written to ./cloudflared/config.yml"
    echo
    echo "IMPORTANT: Uncomment the volume mapping in docker-compose.yml"
    echo "for the cloudflared service, then start with:"
    echo "  ${COMPOSE} up -d"
    ;;

  *)
    echo "Invalid choice."
    exit 1
    ;;
esac
