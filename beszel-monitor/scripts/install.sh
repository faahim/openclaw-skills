#!/bin/bash
# Beszel Server Monitor — Install Script
# Installs hub and/or agent via Docker or binary

set -e

BESZEL_VERSION="latest"
BESZEL_DATA_DIR="/opt/beszel/data"
BESZEL_PORT=8090
AGENT_PORT=45876

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --hub              Install Beszel hub"
  echo "  --agent            Install Beszel agent"
  echo "  --both             Install both hub and agent"
  echo "  --key KEY          SSH key for agent (required for --agent)"
  echo "  --hub-port PORT    Hub port (default: 8090)"
  echo "  --agent-port PORT  Agent port (default: 45876)"
  echo "  --data-dir DIR     Hub data directory (default: /opt/beszel/data)"
  echo "  --binary           Use binary install instead of Docker"
  echo "  --uninstall        Remove Beszel containers/services"
  echo "  --status           Check Beszel status"
  echo ""
  echo "Examples:"
  echo "  $0 --hub                          # Install hub via Docker"
  echo "  $0 --agent --key 'ssh-ed25519...' # Install agent via Docker"
  echo "  $0 --both --key 'ssh-ed25519...'  # Install both"
  echo "  $0 --hub --binary                 # Install hub as binary"
  echo "  $0 --status                       # Check status"
  echo "  $0 --uninstall                    # Remove everything"
}

log() { echo -e "${GREEN}[beszel]${NC} $1"; }
warn() { echo -e "${YELLOW}[beszel]${NC} $1"; }
err() { echo -e "${RED}[beszel]${NC} $1" >&2; }

check_docker() {
  if ! command -v docker &>/dev/null; then
    err "Docker not found. Install Docker first or use --binary flag."
    exit 1
  fi
}

get_arch() {
  local arch=$(uname -m)
  case $arch in
    x86_64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l) echo "arm" ;;
    *) err "Unsupported architecture: $arch"; exit 1 ;;
  esac
}

install_hub_docker() {
  check_docker
  log "Installing Beszel hub via Docker..."
  mkdir -p "$BESZEL_DATA_DIR"

  docker run -d \
    --name beszel-hub \
    --restart unless-stopped \
    -p "${BESZEL_PORT}:8090" \
    -v "${BESZEL_DATA_DIR}:/beszel_data" \
    "henrygd/beszel:${BESZEL_VERSION}"

  local ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
  log "✅ Hub running at http://${ip}:${BESZEL_PORT}"
  log "Open the URL to create your admin account."
}

install_agent_docker() {
  check_docker
  if [ -z "$AGENT_KEY" ]; then
    err "Agent requires --key <ssh-key>. Get it from hub dashboard → Add System."
    exit 1
  fi

  log "Installing Beszel agent via Docker..."
  docker run -d \
    --name beszel-agent \
    --restart unless-stopped \
    --network host \
    --pid host \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -e "KEY=${AGENT_KEY}" \
    -e "PORT=${AGENT_PORT}" \
    "henrygd/beszel-agent:${BESZEL_VERSION}"

  log "✅ Agent running on port ${AGENT_PORT}"
}

install_hub_binary() {
  local arch=$(get_arch)
  log "Installing Beszel hub binary (${arch})..."
  mkdir -p "$BESZEL_DATA_DIR"

  curl -sL "https://github.com/henrygd/beszel/releases/latest/download/beszel_linux_${arch}" \
    -o /usr/local/bin/beszel
  chmod +x /usr/local/bin/beszel

  # Create systemd service
  cat > /etc/systemd/system/beszel-hub.service << EOF
[Unit]
Description=Beszel Hub
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/beszel serve --http 0.0.0.0:${BESZEL_PORT} --dir ${BESZEL_DATA_DIR}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now beszel-hub

  local ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
  log "✅ Hub running at http://${ip}:${BESZEL_PORT}"
}

install_agent_binary() {
  if [ -z "$AGENT_KEY" ]; then
    err "Agent requires --key <ssh-key>"
    exit 1
  fi

  local arch=$(get_arch)
  log "Installing Beszel agent binary (${arch})..."

  curl -sL "https://github.com/henrygd/beszel/releases/latest/download/beszel-agent_linux_${arch}" \
    -o /usr/local/bin/beszel-agent
  chmod +x /usr/local/bin/beszel-agent

  cat > /etc/systemd/system/beszel-agent.service << EOF
[Unit]
Description=Beszel Agent
After=network.target

[Service]
Type=simple
Environment="KEY=${AGENT_KEY}"
Environment="PORT=${AGENT_PORT}"
ExecStart=/usr/local/bin/beszel-agent
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now beszel-agent

  log "✅ Agent running on port ${AGENT_PORT}"
}

uninstall() {
  log "Removing Beszel..."

  # Docker
  docker stop beszel-hub beszel-agent 2>/dev/null || true
  docker rm beszel-hub beszel-agent 2>/dev/null || true

  # Systemd
  systemctl stop beszel-hub beszel-agent 2>/dev/null || true
  systemctl disable beszel-hub beszel-agent 2>/dev/null || true
  rm -f /etc/systemd/system/beszel-hub.service /etc/systemd/system/beszel-agent.service
  systemctl daemon-reload 2>/dev/null || true

  # Binaries
  rm -f /usr/local/bin/beszel /usr/local/bin/beszel-agent

  warn "Data directory ${BESZEL_DATA_DIR} NOT removed. Delete manually if needed."
  log "✅ Beszel removed."
}

status() {
  echo "=== Beszel Status ==="
  echo ""

  # Hub
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q beszel-hub; then
    echo -e "${GREEN}✅ Hub: Running (Docker)${NC}"
  elif systemctl is-active --quiet beszel-hub 2>/dev/null; then
    echo -e "${GREEN}✅ Hub: Running (systemd)${NC}"
  else
    echo -e "${RED}❌ Hub: Not running${NC}"
  fi

  # Agent
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q beszel-agent; then
    echo -e "${GREEN}✅ Agent: Running (Docker)${NC}"
  elif systemctl is-active --quiet beszel-agent 2>/dev/null; then
    echo -e "${GREEN}✅ Agent: Running (systemd)${NC}"
  else
    echo -e "${RED}❌ Agent: Not running${NC}"
  fi

  # API health
  local code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${BESZEL_PORT}/api/health 2>/dev/null)
  if [ "$code" = "200" ]; then
    echo -e "${GREEN}✅ Hub API: Healthy${NC}"
  else
    echo -e "${RED}❌ Hub API: Unreachable${NC}"
  fi

  # Data directory
  if [ -d "$BESZEL_DATA_DIR" ]; then
    local size=$(du -sh "$BESZEL_DATA_DIR" 2>/dev/null | awk '{print $1}')
    echo "📁 Data: ${BESZEL_DATA_DIR} (${size})"
  fi
}

# Parse arguments
INSTALL_HUB=false
INSTALL_AGENT=false
USE_BINARY=false
AGENT_KEY=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --hub) INSTALL_HUB=true; shift ;;
    --agent) INSTALL_AGENT=true; shift ;;
    --both) INSTALL_HUB=true; INSTALL_AGENT=true; shift ;;
    --key) AGENT_KEY="$2"; shift 2 ;;
    --hub-port) BESZEL_PORT="$2"; shift 2 ;;
    --agent-port) AGENT_PORT="$2"; shift 2 ;;
    --data-dir) BESZEL_DATA_DIR="$2"; shift 2 ;;
    --binary) USE_BINARY=true; shift ;;
    --uninstall) uninstall; exit 0 ;;
    --status) status; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) err "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if ! $INSTALL_HUB && ! $INSTALL_AGENT; then
  usage
  exit 1
fi

if $INSTALL_HUB; then
  if $USE_BINARY; then install_hub_binary; else install_hub_docker; fi
fi

if $INSTALL_AGENT; then
  if $USE_BINARY; then install_agent_binary; else install_agent_docker; fi
fi

log "Done! Visit https://beszel.dev for full documentation."
