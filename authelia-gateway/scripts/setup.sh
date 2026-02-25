#!/bin/bash
set -euo pipefail

# Authelia Gateway Setup Script
# Generates configuration, secrets, and docker-compose.yml

DOMAIN=""
EMAIL=""
STORAGE="sqlite"
POSTGRES_HOST=""
REDIS_HOST=""
OUTPUT_DIR="authelia-data"

usage() {
  cat <<EOF
Usage: bash scripts/setup.sh --domain <domain> --email <email> [options]

Required:
  --domain <domain>       Authelia portal domain (e.g., auth.example.com)
  --email <email>         Admin email address

Options:
  --output <dir>          Output directory (default: authelia-data)
  --storage <type>        Storage backend: sqlite|postgres (default: sqlite)
  --postgres-host <host>  PostgreSQL host (if --storage postgres)
  --redis-host <host>     External Redis host (default: bundled Redis)
  -h, --help              Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    --output) OUTPUT_DIR="$2"; shift 2 ;;
    --storage) STORAGE="$2"; shift 2 ;;
    --postgres-host) POSTGRES_HOST="$2"; shift 2 ;;
    --redis-host) REDIS_HOST="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
  echo "Error: --domain and --email are required"
  usage
fi

# Extract parent domain for cookies
PARENT_DOMAIN=$(echo "$DOMAIN" | sed 's/^[^.]*\.//')

echo "🔧 Setting up Authelia Gateway..."
echo "   Domain: $DOMAIN"
echo "   Email: $EMAIL"
echo "   Parent domain: $PARENT_DOMAIN"
echo "   Storage: $STORAGE"
echo "   Output: $OUTPUT_DIR"

# Create directories
mkdir -p "$OUTPUT_DIR/secrets"

# Generate secrets
echo "🔑 Generating secrets..."
openssl rand -hex 32 > "$OUTPUT_DIR/secrets/jwt_secret"
openssl rand -hex 32 > "$OUTPUT_DIR/secrets/session_secret"
openssl rand -hex 32 > "$OUTPUT_DIR/secrets/storage_encryption_key"
echo "change-me" > "$OUTPUT_DIR/secrets/smtp_password"

JWT_SECRET=$(cat "$OUTPUT_DIR/secrets/jwt_secret")
SESSION_SECRET=$(cat "$OUTPUT_DIR/secrets/session_secret")
STORAGE_KEY=$(cat "$OUTPUT_DIR/secrets/storage_encryption_key")

# Determine Redis host
REDIS_URL="redis://redis:6379"
if [[ -n "$REDIS_HOST" ]]; then
  REDIS_URL="redis://$REDIS_HOST:6379"
fi

# Generate configuration.yml
echo "📝 Generating configuration..."
cat > "$OUTPUT_DIR/configuration.yml" <<YAML
---
theme: dark
jwt_secret: '$JWT_SECRET'

server:
  host: 0.0.0.0
  port: 9091
  path: ""

log:
  level: info
  format: text
  file_path: /config/authelia.log

totp:
  issuer: $PARENT_DOMAIN
  period: 30
  skew: 1

webauthn:
  disable: false
  display_name: Authelia
  attestation_conveyance_preference: indirect
  user_verification: preferred
  timeout: 60s

authentication_backend:
  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id
      iterations: 3
      memory: 65536
      parallelism: 4
      key_length: 32
      salt_length: 16

access_control:
  default_policy: deny
  rules:
    # Example: bypass for health check
    - domain: $DOMAIN
      resources:
        - "^/api/health\$"
      policy: bypass

    # Example: one_factor for internal services
    # - domain: "*.${PARENT_DOMAIN}"
    #   policy: one_factor

    # Example: two_factor for admin
    # - domain: "admin.${PARENT_DOMAIN}"
    #   subject:
    #     - "group:admins"
    #   policy: two_factor

session:
  name: authelia_session
  secret: '$SESSION_SECRET'
  expiration: 3600
  inactivity: 300
  remember_me_duration: 1M
  domain: $PARENT_DOMAIN

regulation:
  max_retries: 5
  find_time: 120
  ban_time: 300

storage:
  encryption_key: '$STORAGE_KEY'
YAML

if [[ "$STORAGE" == "postgres" ]]; then
  cat >> "$OUTPUT_DIR/configuration.yml" <<YAML
  postgres:
    host: ${POSTGRES_HOST:-postgres}
    port: 5432
    database: authelia
    username: authelia
    password: authelia-db-password
YAML
else
  cat >> "$OUTPUT_DIR/configuration.yml" <<YAML
  local:
    path: /config/db.sqlite3
YAML
fi

cat >> "$OUTPUT_DIR/configuration.yml" <<YAML

redis:
  host: ${REDIS_HOST:-redis}
  port: 6379

notifier:
  # For testing: use filesystem notifier
  filesystem:
    filename: /config/notification.txt
  # For production: uncomment SMTP below and remove filesystem above
  # smtp:
  #   host: smtp.gmail.com
  #   port: 587
  #   username: $EMAIL
  #   sender: "Authelia <auth@${PARENT_DOMAIN}>"
  #   password: change-me
YAML

# Generate empty users database
cat > "$OUTPUT_DIR/users_database.yml" <<YAML
---
# Authelia Users Database
# Use scripts/manage-users.sh to add/remove users
# Passwords are hashed with argon2id
users: {}
YAML

# Generate docker-compose.yml
echo "🐳 Generating docker-compose.yml..."
cat > "$OUTPUT_DIR/docker-compose.yml" <<YAML
version: "3.8"

services:
  authelia:
    image: authelia/authelia:latest
    container_name: authelia
    restart: unless-stopped
    ports:
      - "9091:9091"
    volumes:
      - ./configuration.yml:/config/configuration.yml:ro
      - ./users_database.yml:/config/users_database.yml
      - ./data:/config
    environment:
      - TZ=UTC
    depends_on:
      - redis
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9091/api/health"]
      interval: 30s
      timeout: 3s
      retries: 3

  redis:
    image: redis:7-alpine
    container_name: authelia-redis
    restart: unless-stopped
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

volumes:
  redis-data:
YAML

# Create data directory for SQLite
mkdir -p "$OUTPUT_DIR/data"

echo ""
echo "✅ Authelia Gateway setup complete!"
echo ""
echo "Next steps:"
echo "  1. Add a user:    bash scripts/manage-users.sh add --username admin --email $EMAIL"
echo "  2. Start:         cd $OUTPUT_DIR && docker compose up -d"
echo "  3. Access portal:  https://$DOMAIN"
echo "  4. Configure your reverse proxy (see SKILL.md)"
echo ""
echo "⚠️  For production: Edit configuration.yml to enable SMTP notifier (disable filesystem)."
