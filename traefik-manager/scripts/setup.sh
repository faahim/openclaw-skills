#!/bin/bash
# Traefik Manager — Setup Script
# Generates docker-compose.yml and traefik.yml for production deployment

set -euo pipefail

# Defaults
TRAEFIK_DIR="/opt/traefik"
ACME_EMAIL="${TRAEFIK_ACME_EMAIL:-}"
DASHBOARD=false
DASHBOARD_DOMAIN=""
DASHBOARD_USER=""
DASHBOARD_PASS=""
FORCE_HTTPS=true
DNS_CHALLENGE=""
WILDCARD_DOMAIN=""
LOG_LEVEL="${TRAEFIK_LOG_LEVEL:-INFO}"
HTTP_PORT="${TRAEFIK_ENTRYPOINT_HTTP:-80}"
HTTPS_PORT="${TRAEFIK_ENTRYPOINT_HTTPS:-443}"

usage() {
  cat <<EOF
Usage: $0 --email <email> [options]

Required:
  --email <email>          Let's Encrypt email for certificate registration

Options:
  --dir <path>             Traefik install directory (default: /opt/traefik)
  --dashboard              Enable Traefik dashboard
  --dashboard-domain <d>   Domain for dashboard (required if --dashboard)
  --dashboard-user <u>     Dashboard basic auth username
  --dashboard-password <p> Dashboard basic auth password
  --force-https            Redirect HTTP to HTTPS (default: true)
  --no-force-https         Don't redirect HTTP to HTTPS
  --dns-challenge <prov>   Use DNS challenge (cloudflare, route53, digitalocean)
  --wildcard <domain>      Wildcard domain (e.g., *.example.com)
  --log-level <level>      Log level: DEBUG, INFO, WARN, ERROR (default: INFO)
  -h, --help               Show this help
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --email) ACME_EMAIL="$2"; shift 2 ;;
    --dir) TRAEFIK_DIR="$2"; shift 2 ;;
    --dashboard) DASHBOARD=true; shift ;;
    --dashboard-domain) DASHBOARD_DOMAIN="$2"; shift 2 ;;
    --dashboard-user) DASHBOARD_USER="$2"; shift 2 ;;
    --dashboard-password) DASHBOARD_PASS="$2"; shift 2 ;;
    --force-https) FORCE_HTTPS=true; shift ;;
    --no-force-https) FORCE_HTTPS=false; shift ;;
    --dns-challenge) DNS_CHALLENGE="$2"; shift 2 ;;
    --wildcard) WILDCARD_DOMAIN="$2"; shift 2 ;;
    --log-level) LOG_LEVEL="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$ACME_EMAIL" ]]; then
  echo "❌ --email is required"
  exit 1
fi

echo "🚀 Setting up Traefik in ${TRAEFIK_DIR}..."

# Create directories
sudo mkdir -p "${TRAEFIK_DIR}/config" "${TRAEFIK_DIR}/acme" "${TRAEFIK_DIR}/logs"
sudo touch "${TRAEFIK_DIR}/acme/acme.json"
sudo chmod 600 "${TRAEFIK_DIR}/acme/acme.json"

# Create Docker network
docker network create traefik-public 2>/dev/null && echo "✅ Created traefik-public network" || echo "ℹ️  traefik-public network already exists"

# --- Generate traefik.yml ---
REDIRECT_BLOCK=""
if $FORCE_HTTPS; then
  REDIRECT_BLOCK="
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https"
fi

CERT_RESOLVER_BLOCK=""
if [[ -n "$DNS_CHALLENGE" ]]; then
  CERT_RESOLVER_BLOCK="
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /acme/acme.json
      dnsChallenge:
        provider: ${DNS_CHALLENGE}
        resolvers:
          - \"1.1.1.1:53\"
          - \"8.8.8.8:53\""
else
  CERT_RESOLVER_BLOCK="
certificatesResolvers:
  letsencrypt:
    acme:
      email: ${ACME_EMAIL}
      storage: /acme/acme.json
      httpChallenge:
        entryPoint: web"
fi

DASHBOARD_BLOCK="false"
if $DASHBOARD; then
  DASHBOARD_BLOCK="true"
fi

cat > "${TRAEFIK_DIR}/traefik.yml" <<EOF
api:
  dashboard: ${DASHBOARD_BLOCK}
  insecure: false

entryPoints:
  web:
    address: ":${HTTP_PORT}"${REDIRECT_BLOCK}
  websecure:
    address: ":${HTTPS_PORT}"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik-public
  file:
    directory: /etc/traefik/config
    watch: true
${CERT_RESOLVER_BLOCK}

log:
  level: ${LOG_LEVEL}

accessLog:
  filePath: /var/log/traefik/access.log
  bufferingSize: 100
EOF

echo "✅ Generated traefik.yml"

# --- Generate docker-compose.yml ---
DASHBOARD_LABELS=""
if $DASHBOARD && [[ -n "$DASHBOARD_DOMAIN" ]]; then
  AUTH_LABEL=""
  if [[ -n "$DASHBOARD_USER" && -n "$DASHBOARD_PASS" ]]; then
    HTPASSWD=$(docker run --rm httpd:2-alpine htpasswd -nbB "${DASHBOARD_USER}" "${DASHBOARD_PASS}" 2>/dev/null | head -1 | sed 's/\$/\$\$/g')
    AUTH_LABEL="
      - \"traefik.http.middlewares.dashboard-auth.basicauth.users=${HTPASSWD}\"
      - \"traefik.http.routers.dashboard.middlewares=dashboard-auth\""
  fi
  DASHBOARD_LABELS="
      - \"traefik.enable=true\"
      - \"traefik.http.routers.dashboard.rule=Host(\\\`${DASHBOARD_DOMAIN}\\\`)\"
      - \"traefik.http.routers.dashboard.tls.certresolver=letsencrypt\"
      - \"traefik.http.routers.dashboard.service=api@internal\"${AUTH_LABEL}"
fi

ENV_BLOCK=""
if [[ -n "$DNS_CHALLENGE" ]]; then
  case "$DNS_CHALLENGE" in
    cloudflare)
      ENV_BLOCK="
    environment:
      - CF_API_EMAIL=\${CF_API_EMAIL}
      - CF_DNS_API_TOKEN=\${CF_DNS_API_TOKEN}" ;;
    route53)
      ENV_BLOCK="
    environment:
      - AWS_ACCESS_KEY_ID=\${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_ACCESS_KEY=\${AWS_SECRET_ACCESS_KEY}
      - AWS_REGION=\${AWS_REGION:-us-east-1}" ;;
    digitalocean)
      ENV_BLOCK="
    environment:
      - DO_AUTH_TOKEN=\${DO_AUTH_TOKEN}" ;;
  esac
fi

cat > "${TRAEFIK_DIR}/docker-compose.yml" <<EOF
services:
  traefik:
    image: traefik:v3.3
    container_name: traefik
    restart: unless-stopped
    ports:
      - "${HTTP_PORT}:${HTTP_PORT}"
      - "${HTTPS_PORT}:${HTTPS_PORT}"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./config:/etc/traefik/config:ro
      - ./acme:/acme
      - ./logs:/var/log/traefik${ENV_BLOCK}
    networks:
      - traefik-public
    labels:
      - "traefik.enable=false"${DASHBOARD_LABELS}

networks:
  traefik-public:
    external: true
EOF

echo "✅ Generated docker-compose.yml"
echo ""
echo "🎉 Traefik setup complete!"
echo ""
echo "Next steps:"
echo "  cd ${TRAEFIK_DIR}"
echo "  docker compose up -d"
echo "  docker compose logs -f"
echo ""
echo "Add services by putting Docker labels on containers:"
echo "  traefik.enable=true"
echo "  traefik.http.routers.<name>.rule=Host(\`domain.com\`)"
echo "  traefik.http.routers.<name>.tls.certresolver=letsencrypt"
echo "  traefik.http.services.<name>.loadbalancer.server.port=<port>"
