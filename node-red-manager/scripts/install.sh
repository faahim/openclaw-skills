#!/bin/bash
# Node-RED Manager — Installation Script
set -euo pipefail

DOCKER_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --docker) DOCKER_MODE=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🔧 Node-RED Manager — Installation"
echo "==================================="

# Check prerequisites
check_prereqs() {
  if $DOCKER_MODE; then
    if ! command -v docker &>/dev/null; then
      echo "❌ Docker not found. Install Docker first."
      echo "   curl -fsSL https://get.docker.com | sh"
      exit 1
    fi
    return 0
  fi

  if ! command -v node &>/dev/null; then
    echo "⚠️  Node.js not found."
    echo ""
    # Check if we're on Debian/Ubuntu/Raspberry Pi
    if [ -f /etc/debian_version ]; then
      echo "📦 Detected Debian/Ubuntu — using official Node-RED install script"
      echo "   This will install Node.js + Node-RED together."
      echo ""
      read -p "Proceed? [Y/n] " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Aborted."
        exit 1
      fi
      bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered) --confirm-install --confirm-pi
      echo "✅ Node-RED installed via official script"
      setup_service
      echo ""
      echo "🎉 Installation complete!"
      echo "   Start: bash scripts/manage.sh start"
      echo "   URL:   http://localhost:1880"
      exit 0
    else
      echo "Install Node.js first:"
      echo "  • https://nodejs.org"
      echo "  • Or: curl -fsSL https://fnm.vercel.app/install | bash && fnm install --lts"
      exit 1
    fi
  fi

  NODE_VER=$(node -v | sed 's/v//' | cut -d. -f1)
  if [ "$NODE_VER" -lt 18 ]; then
    echo "❌ Node.js v18+ required (found v${NODE_VER})"
    exit 1
  fi
  echo "✅ Node.js $(node -v)"
}

# Install Node-RED via npm
install_npm() {
  echo ""
  echo "📦 Installing Node-RED globally via npm..."
  npm install -g --unsafe-perm node-red

  # Verify
  if command -v node-red &>/dev/null; then
    NR_VER=$(node-red --help 2>&1 | head -1 | grep -oP 'v[\d.]+' || echo "unknown")
    echo "✅ Node-RED installed: $NR_VER"
  else
    echo "✅ Node-RED installed"
  fi
}

# Install via Docker
install_docker() {
  echo ""
  echo "🐳 Setting up Node-RED in Docker..."

  NR_DIR="${NODE_RED_DIR:-$HOME/.node-red}"
  NR_PORT="${NODE_RED_PORT:-1880}"

  mkdir -p "$NR_DIR"

  # Create docker-compose.yml
  cat > "$NR_DIR/docker-compose.yml" <<EOF
version: "3"
services:
  nodered:
    image: nodered/node-red:latest
    container_name: node-red
    restart: unless-stopped
    ports:
      - "${NR_PORT}:1880"
    volumes:
      - ${NR_DIR}:/data
    environment:
      - TZ=${TZ:-UTC}
EOF

  echo "✅ Docker Compose config written to $NR_DIR/docker-compose.yml"
  echo ""
  echo "Start with:"
  echo "  cd $NR_DIR && docker compose up -d"
  echo ""
  echo "🎉 Docker setup complete!"
  echo "   URL: http://localhost:${NR_PORT}"
}

# Create systemd service
setup_service() {
  if [ "$(id -u)" -eq 0 ]; then
    NR_USER="${SUDO_USER:-root}"
  else
    NR_USER="$(whoami)"
  fi

  NR_DIR="${NODE_RED_DIR:-/home/${NR_USER}/.node-red}"
  NR_PORT="${NODE_RED_PORT:-1880}"
  NR_BIN=$(which node-red 2>/dev/null || echo "/usr/bin/node-red")

  SERVICE_FILE="/etc/systemd/system/nodered.service"

  # Only create if we have permission
  if [ -w /etc/systemd/system/ ] || [ "$(id -u)" -eq 0 ]; then
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Node-RED
After=syslog.target network.target

[Service]
ExecStart=${NR_BIN} --port ${NR_PORT} --userDir ${NR_DIR}
Restart=on-failure
KillSignal=SIGINT
SyslogIdentifier=node-red
StandardOutput=syslog
WorkingDirectory=${NR_DIR}
User=${NR_USER}
Group=${NR_USER}
Environment="NODE_OPTIONS=--max_old_space_size=256"

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable nodered.service
    echo "✅ Systemd service created and enabled"
  else
    echo "⚠️  Cannot create systemd service (need root)."
    echo "   Run with sudo for service setup, or start manually:"
    echo "   node-red --port ${NR_PORT} --userDir ${NR_DIR}"
  fi
}

# Initialize user directory
init_user_dir() {
  NR_DIR="${NODE_RED_DIR:-$HOME/.node-red}"
  mkdir -p "$NR_DIR"
  
  # Create initial package.json if missing
  if [ ! -f "$NR_DIR/package.json" ]; then
    cat > "$NR_DIR/package.json" <<EOF
{
  "name": "node-red-project",
  "description": "Node-RED user directory",
  "version": "0.0.1",
  "private": true,
  "dependencies": {}
}
EOF
    echo "✅ User directory initialized: $NR_DIR"
  fi
}

# Main
check_prereqs

if $DOCKER_MODE; then
  install_docker
else
  install_npm
  init_user_dir
  setup_service

  echo ""
  echo "🎉 Installation complete!"
  echo "   Start:  bash scripts/manage.sh start"
  echo "   URL:    http://localhost:${NODE_RED_PORT:-1880}"
  echo "   Secure: bash scripts/secure.sh --user admin --pass 'YourPassword'"
fi
