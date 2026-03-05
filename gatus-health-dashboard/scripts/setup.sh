#!/bin/bash
# Set up Gatus configuration
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/gatus}"
mkdir -p "$CONFIG_DIR"

MODE="init"
while [[ $# -gt 0 ]]; do
  case $1 in
    --init) MODE="init"; shift ;;
    --compose) MODE="compose"; shift ;;
    --compose-postgres) MODE="compose-pg"; shift ;;
    -h|--help)
      echo "Usage: setup.sh [--init|--compose|--compose-postgres]"
      exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

generate_config() {
  cat > "$CONFIG_DIR/config.yaml" << 'YAML'
# Gatus Configuration
# Docs: https://gatus.io/docs

storage:
  type: sqlite
  path: /data/gatus.db

ui:
  title: "Service Status"
  description: "Health monitoring dashboard powered by Gatus"

# Uncomment and configure alerting as needed:
# alerting:
#   telegram:
#     token: "${TELEGRAM_BOT_TOKEN}"
#     id: "${TELEGRAM_CHAT_ID}"
#     default-alert:
#       enabled: true
#       failure-threshold: 3
#       success-threshold: 2
#       send-on-resolved: true
#
#   slack:
#     webhook-url: "${SLACK_WEBHOOK_URL}"
#     default-alert:
#       enabled: true
#       failure-threshold: 2
#       send-on-resolved: true
#
#   discord:
#     webhook-url: "${DISCORD_WEBHOOK_URL}"
#     default-alert:
#       enabled: true
#       failure-threshold: 3

endpoints:
  - name: Example Website
    group: websites
    url: "https://example.com"
    interval: 5m
    conditions:
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 1000"

  # - name: Your API
  #   group: apis
  #   url: "https://api.yoursite.com/health"
  #   interval: 1m
  #   conditions:
  #     - "[STATUS] == 200"
  #     - "[BODY].status == UP"
  #     - "[RESPONSE_TIME] < 500"
  #   alerts:
  #     - type: telegram
  #       description: "API is down!"

  # - name: Database
  #   group: infrastructure
  #   url: "tcp://localhost:5432"
  #   interval: 30s
  #   conditions:
  #     - "[CONNECTED] == true"

  # - name: SSL Certificate
  #   group: certificates
  #   url: "https://yoursite.com"
  #   interval: 1h
  #   conditions:
  #     - "[CERTIFICATE_EXPIRATION] > 720h"
YAML
  echo "📝 Config created at $CONFIG_DIR/config.yaml"
}

case $MODE in
  init)
    generate_config
    echo ""
    echo "Edit $CONFIG_DIR/config.yaml to add your endpoints."
    echo "Then start Gatus with Docker or the binary."
    ;;

  compose)
    generate_config
    cat > "$CONFIG_DIR/docker-compose.yaml" << 'YAML'
services:
  gatus:
    image: twinproduction/gatus:latest
    container_name: gatus
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./config.yaml:/config/config.yaml
      - gatus-data:/data
    env_file:
      - .env

volumes:
  gatus-data:
YAML
    touch "$CONFIG_DIR/.env"
    echo "📝 docker-compose.yaml created at $CONFIG_DIR/"
    echo ""
    echo "1. Edit $CONFIG_DIR/config.yaml"
    echo "2. Add alert credentials to $CONFIG_DIR/.env"
    echo "3. Run: cd $CONFIG_DIR && docker compose up -d"
    ;;

  compose-pg)
    generate_config
    # Update storage to postgres
    sed -i 's|type: sqlite|type: postgres|' "$CONFIG_DIR/config.yaml"
    sed -i 's|path: /data/gatus.db|path: "postgres://gatus:gatus@postgres:5432/gatus?sslmode=disable"|' "$CONFIG_DIR/config.yaml"

    cat > "$CONFIG_DIR/docker-compose.yaml" << 'YAML'
services:
  gatus:
    image: twinproduction/gatus:latest
    container_name: gatus
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./config.yaml:/config/config.yaml
    env_file:
      - .env
    depends_on:
      postgres:
        condition: service_healthy

  postgres:
    image: postgres:16-alpine
    container_name: gatus-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: gatus
      POSTGRES_USER: gatus
      POSTGRES_PASSWORD: gatus
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gatus"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres-data:
YAML
    touch "$CONFIG_DIR/.env"
    echo "📝 docker-compose.yaml (with PostgreSQL) created at $CONFIG_DIR/"
    echo ""
    echo "1. Edit $CONFIG_DIR/config.yaml"
    echo "2. Run: cd $CONFIG_DIR && docker compose up -d"
    ;;
esac
