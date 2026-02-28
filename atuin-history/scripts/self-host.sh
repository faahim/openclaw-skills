#!/bin/bash
# Deploy self-hosted Atuin sync server
set -e

MODE="${1:-docker}"

deploy_docker() {
    if ! command -v docker &>/dev/null; then
        echo "❌ Docker not found. Install Docker first or use 'systemd' mode."
        exit 1
    fi

    echo "🐳 Deploying Atuin server with Docker..."

    # Create data directory
    mkdir -p "$HOME/.atuin-server"

    # Generate config
    cat > "$HOME/.atuin-server/server.toml" << 'EOF'
[server]
host = "0.0.0.0"
port = 8888
open_registration = true
db_uri = "postgres://atuin:atuin@localhost/atuin"

[metrics]
enable = false
EOF

    # Docker Compose file
    cat > "$HOME/.atuin-server/docker-compose.yml" << 'EOF'
version: "3"
services:
  atuin:
    image: ghcr.io/atuinsh/atuin:latest
    command: server start
    volumes:
      - ./server.toml:/config/server.toml
    ports:
      - "8888:8888"
    environment:
      ATUIN_DB_URI: postgres://atuin:atuin@db/atuin
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: atuin
      POSTGRES_PASSWORD: atuin
      POSTGRES_DB: atuin
    volumes:
      - atuin-db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U atuin"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  atuin-db:
EOF

    cd "$HOME/.atuin-server"
    docker compose up -d

    echo ""
    echo "✅ Atuin server running at http://localhost:8888"
    echo ""
    echo "To use with your client:"
    echo "  bash scripts/configure.sh sync_address 'http://YOUR_SERVER_IP:8888'"
    echo "  atuin register"
}

deploy_systemd() {
    echo "⚙️ Deploying Atuin server with systemd..."
    echo ""
    echo "Prerequisites:"
    echo "  1. PostgreSQL running locally"
    echo "  2. Database 'atuin' created"
    echo ""
    
    # Install server binary
    if ! command -v atuin &>/dev/null; then
        echo "Installing Atuin..."
        bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)
    fi

    read -p "PostgreSQL connection URI (e.g. postgres://user:pass@localhost/atuin): " DB_URI
    if [[ -z "$DB_URI" ]]; then
        echo "❌ No DB URI provided."
        exit 1
    fi

    # Create server config
    CONFDIR="/etc/atuin"
    sudo mkdir -p "$CONFDIR"
    sudo tee "$CONFDIR/server.toml" > /dev/null << EOF
[server]
host = "0.0.0.0"
port = 8888
open_registration = true
db_uri = "$DB_URI"
EOF

    # Create systemd service
    sudo tee /etc/systemd/system/atuin-server.service > /dev/null << 'EOF'
[Unit]
Description=Atuin Sync Server
After=network.target postgresql.service

[Service]
Type=simple
ExecStart=/usr/bin/env atuin server start
Environment=ATUIN_CONFIG_DIR=/etc/atuin
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now atuin-server

    echo ""
    echo "✅ Atuin server running on port 8888"
    echo "   Check status: sudo systemctl status atuin-server"
    echo "   View logs: sudo journalctl -u atuin-server -f"
}

case "$MODE" in
    docker)  deploy_docker ;;
    systemd) deploy_systemd ;;
    *)
        echo "Usage: $0 [docker|systemd]"
        exit 1
        ;;
esac
