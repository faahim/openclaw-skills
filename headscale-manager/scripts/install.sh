#!/bin/bash
# Headscale Installer — Downloads and installs Headscale server
# Usage: bash install.sh [--update]

set -euo pipefail

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/headscale"
DATA_DIR="/var/lib/headscale"
SERVICE_FILE="/etc/systemd/system/headscale.service"
GITHUB_REPO="juanfont/headscale"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7*) ARCH="armv7" ;;
    *) error "Unsupported architecture: $ARCH" ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$OS" != "linux" ]]; then
    error "Headscale only runs on Linux. Detected: $OS"
fi

info "Detected: ${OS}/${ARCH}"

# Get latest version
info "Fetching latest Headscale release..."
LATEST=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | jq -r '.tag_name')
if [[ -z "$LATEST" || "$LATEST" == "null" ]]; then
    error "Could not determine latest version. Check your internet connection."
fi
VERSION="${LATEST#v}"
info "Latest version: ${VERSION}"

# Check if already installed
if command -v headscale &>/dev/null; then
    CURRENT=$(headscale version 2>/dev/null | head -1 || echo "unknown")
    info "Currently installed: ${CURRENT}"
    if [[ "$1" != "--update" ]] 2>/dev/null; then
        warn "Headscale is already installed. Use --update to upgrade."
        exit 0
    fi
    info "Updating Headscale..."
fi

# Download binary
DL_URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST}/headscale_${VERSION}_${OS}_${ARCH}"
info "Downloading from: ${DL_URL}"

TMP_FILE=$(mktemp)
if ! curl -fSL -o "$TMP_FILE" "$DL_URL"; then
    # Try .deb package instead
    DL_URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST}/headscale_${VERSION}_${OS}_${ARCH}.deb"
    info "Binary not found, trying .deb package: ${DL_URL}"
    if curl -fSL -o "$TMP_FILE" "$DL_URL"; then
        dpkg -i "$TMP_FILE" && rm -f "$TMP_FILE"
        info "Installed via .deb package"
    else
        # Try tar.gz
        DL_URL="https://github.com/${GITHUB_REPO}/releases/download/${LATEST}/headscale_${VERSION}_${OS}_${ARCH}.tar.gz"
        info "Trying tar.gz: ${DL_URL}"
        curl -fSL -o "$TMP_FILE" "$DL_URL" || error "Could not download Headscale. Check the release page: https://github.com/${GITHUB_REPO}/releases"
        tar xzf "$TMP_FILE" -C /tmp headscale
        mv /tmp/headscale "${INSTALL_DIR}/headscale"
        chmod +x "${INSTALL_DIR}/headscale"
        rm -f "$TMP_FILE"
    fi
else
    mv "$TMP_FILE" "${INSTALL_DIR}/headscale"
    chmod +x "${INSTALL_DIR}/headscale"
fi

info "Headscale binary installed to ${INSTALL_DIR}/headscale"

# Create directories
mkdir -p "$CONFIG_DIR" "$DATA_DIR"

# Create headscale user if needed
if ! id headscale &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin headscale
    info "Created headscale system user"
fi

chown -R headscale:headscale "$DATA_DIR"

# Generate default config if not exists
if [[ ! -f "${CONFIG_DIR}/config.yaml" ]]; then
    SERVER_IP=$(hostname -I | awk '{print $1}')
    cat > "${CONFIG_DIR}/config.yaml" << YAML
---
server_url: http://${SERVER_IP}:8080
listen_addr: 0.0.0.0:8080
metrics_listen_addr: 127.0.0.1:9090
grpc_listen_addr: 127.0.0.1:50443
grpc_allow_insecure: false

private_key_path: ${DATA_DIR}/private.key
noise:
  private_key_path: ${DATA_DIR}/noise_private.key

prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48
  allocation: sequential

derp:
  server:
    enabled: true
    region_id: 999
    region_code: headscale
    region_name: "Headscale Embedded DERP"
    stun_listen_addr: 0.0.0.0:3478
  urls:
    - https://controlplane.tailscale.com/derpmap/default
  auto_update_enabled: true
  update_frequency: 24h

disable_check_updates: true
ephemeral_node_inactivity_timeout: 30m

database:
  type: sqlite3
  sqlite:
    path: ${DATA_DIR}/db.sqlite

dns:
  nameservers:
    global:
      - 1.1.1.1
      - 9.9.9.9
  magic_dns: true
  base_domain: ts.local

log:
  level: info
YAML
    chown headscale:headscale "${CONFIG_DIR}/config.yaml"
    info "Default config written to ${CONFIG_DIR}/config.yaml"
    warn "IMPORTANT: Edit server_url in ${CONFIG_DIR}/config.yaml to match your public address!"
else
    info "Config already exists at ${CONFIG_DIR}/config.yaml — skipping"
fi

# Create systemd service
if [[ ! -f "$SERVICE_FILE" ]] || [[ "${1:-}" == "--update" ]]; then
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Headscale - Self-hosted Tailscale control server
After=syslog.target network-online.target
Wants=network-online.target

[Service]
User=headscale
Group=headscale
Type=simple
Restart=always
RestartSec=5
ExecStart=${INSTALL_DIR}/headscale serve
WorkingDirectory=${DATA_DIR}
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    info "Systemd service created"
fi

# Print version
headscale version 2>/dev/null || true

echo ""
info "✅ Headscale installed successfully!"
echo ""
echo "Next steps:"
echo "  1. Edit config:     sudo nano ${CONFIG_DIR}/config.yaml"
echo "  2. Start service:   sudo systemctl enable --now headscale"
echo "  3. Create user:     headscale users create myuser"
echo "  4. Create auth key: headscale preauthkeys create --user myuser --reusable --expiration 24h"
echo "  5. Connect client:  tailscale up --login-server http://${SERVER_IP:-YOUR_IP}:8080 --authkey KEY"
echo ""
