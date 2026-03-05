#!/bin/bash
# Install Gatus health dashboard
set -euo pipefail

GATUS_VERSION="${GATUS_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/gatus}"
DATA_DIR="${DATA_DIR:-$HOME/.local/share/gatus}"
USE_SYSTEMD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --version) GATUS_VERSION="$2"; shift 2 ;;
    --systemd) USE_SYSTEMD=true; shift ;;
    --dir) INSTALL_DIR="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: install.sh [OPTIONS]"
      echo "  --version VERSION  Gatus version (default: latest)"
      echo "  --systemd          Install as systemd service"
      echo "  --dir PATH         Install directory (default: /usr/local/bin)"
      exit 0 ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7*) ARCH="armv7" ;;
  *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
esac

OS=$(uname -s | tr '[:upper:]' '[:lower:]')

echo "📦 Installing Gatus ($GATUS_VERSION) for $OS/$ARCH..."

# Get latest version if needed
if [[ "$GATUS_VERSION" == "latest" ]]; then
  GATUS_VERSION=$(curl -s https://api.github.com/repos/TwiN/gatus/releases/latest | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')
  echo "   Latest version: v$GATUS_VERSION"
fi

# Download binary
DOWNLOAD_URL="https://github.com/TwiN/gatus/releases/download/v${GATUS_VERSION}/gatus-${OS}-${ARCH}.tar.gz"
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo "⬇️  Downloading from $DOWNLOAD_URL..."
if ! curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/gatus.tar.gz"; then
  echo "❌ Download failed. Trying Docker install instead..."
  echo ""
  echo "Run with Docker:"
  echo "  docker run -d --name gatus -p 8080:8080 \\"
  echo "    -v ~/.config/gatus/config.yaml:/config/config.yaml \\"
  echo "    twinproduction/gatus:latest"
  exit 1
fi

# Extract and install
cd "$TMP_DIR"
tar xzf gatus.tar.gz

if [[ -w "$INSTALL_DIR" ]]; then
  mv gatus "$INSTALL_DIR/gatus"
else
  sudo mv gatus "$INSTALL_DIR/gatus"
fi
chmod +x "$INSTALL_DIR/gatus"

echo "✅ Gatus installed to $INSTALL_DIR/gatus"

# Create directories
mkdir -p "$CONFIG_DIR" "$DATA_DIR"

# Create default config if none exists
if [[ ! -f "$CONFIG_DIR/config.yaml" ]]; then
  cat > "$CONFIG_DIR/config.yaml" << 'YAML'
storage:
  type: sqlite
  path: data/gatus.db

ui:
  title: "Service Status"
  description: "Health monitoring dashboard"

endpoints:
  - name: Example
    group: demo
    url: "https://example.com"
    interval: 5m
    conditions:
      - "[STATUS] == 200"
      - "[RESPONSE_TIME] < 1000"
YAML
  echo "📝 Default config created at $CONFIG_DIR/config.yaml"
fi

# Install systemd service
if [[ "$USE_SYSTEMD" == true ]]; then
  UNIT_FILE="/etc/systemd/system/gatus.service"
  sudo tee "$UNIT_FILE" > /dev/null << EOF
[Unit]
Description=Gatus Health Dashboard
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$DATA_DIR
ExecStart=$INSTALL_DIR/gatus --config $CONFIG_DIR/config.yaml
Restart=always
RestartSec=5
EnvironmentFile=-$CONFIG_DIR/.env

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable gatus
  sudo systemctl start gatus
  echo "✅ Gatus systemd service installed and started"
  echo "   Status: sudo systemctl status gatus"
  echo "   Logs:   sudo journalctl -u gatus -f"
else
  echo ""
  echo "To start Gatus:"
  echo "  cd $DATA_DIR && gatus --config $CONFIG_DIR/config.yaml"
  echo ""
  echo "To install as systemd service:"
  echo "  bash install.sh --systemd"
fi

echo ""
echo "🌐 Dashboard: http://localhost:8080"
