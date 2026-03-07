#!/bin/bash
# Dagu Workflow Engine — Installer
# Installs Dagu binary, creates config dirs, optionally sets up systemd service

set -euo pipefail

DAGU_VERSION="${DAGU_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/dagu}"
DAGS_DIR="${DAGS_DIR:-$CONFIG_DIR/dags}"
LOG_DIR="${LOG_DIR:-$CONFIG_DIR/logs}"

echo "🔧 Dagu Workflow Engine Installer"
echo "=================================="

# Detect architecture
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case "$ARCH" in
  x86_64)  ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l)  ARCH="armv7" ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

echo "📦 Detected: $OS/$ARCH"

# Create directories
echo "📁 Creating directories..."
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$DAGS_DIR" "$LOG_DIR"

# Download Dagu
echo "⬇️  Downloading Dagu ($DAGU_VERSION)..."

if [ "$DAGU_VERSION" = "latest" ]; then
  DOWNLOAD_URL=$(curl -sL https://api.github.com/repos/dagu-org/dagu/releases/latest \
    | grep "browser_download_url" \
    | grep "${OS}_${ARCH}" \
    | head -1 \
    | cut -d '"' -f 4)
else
  DOWNLOAD_URL="https://github.com/dagu-org/dagu/releases/download/v${DAGU_VERSION}/dagu_${DAGU_VERSION}_${OS}_${ARCH}.tar.gz"
fi

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌ Could not find download URL for $OS/$ARCH"
  echo "   Check releases at: https://github.com/dagu-org/dagu/releases"
  exit 1
fi

echo "   URL: $DOWNLOAD_URL"

TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

curl -sL "$DOWNLOAD_URL" -o "$TMPDIR/dagu.tar.gz"
tar xzf "$TMPDIR/dagu.tar.gz" -C "$TMPDIR"

# Install binary
if [ -f "$TMPDIR/dagu" ]; then
  mv "$TMPDIR/dagu" "$INSTALL_DIR/dagu"
  chmod +x "$INSTALL_DIR/dagu"
elif ls "$TMPDIR"/dagu_*/dagu 2>/dev/null; then
  mv "$TMPDIR"/dagu_*/dagu "$INSTALL_DIR/dagu"
  chmod +x "$INSTALL_DIR/dagu"
else
  echo "❌ Could not find dagu binary in archive"
  ls -la "$TMPDIR"
  exit 1
fi

echo "✅ Dagu installed to $INSTALL_DIR/dagu"

# Ensure PATH includes install dir
if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
  echo ""
  echo "⚠️  Add to your PATH:"
  echo "   export PATH=\"$INSTALL_DIR:\$PATH\""
  echo ""
  
  # Auto-add to shell rc files
  for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ] && ! grep -q "$INSTALL_DIR" "$RC"; then
      echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$RC"
      echo "   Added to $RC"
    fi
  done
fi

# Create default admin config
if [ ! -f "$CONFIG_DIR/admin.yaml" ]; then
  cat > "$CONFIG_DIR/admin.yaml" << 'YAML'
# Dagu Configuration
# Docs: https://dagu.readthedocs.io/

host: 127.0.0.1
port: 8080
debug: false
logDir: logs
dagsDir: dags

# Uncomment to enable basic auth:
# isBasicAuth: true
# basicAuthUsername: admin
# basicAuthPassword: change-me-to-a-secure-password

# Uncomment for global env vars:
# env:
#   - SLACK_WEBHOOK: https://hooks.slack.com/...
#   - TELEGRAM_BOT_TOKEN: your-token
YAML
  echo "📝 Default config created at $CONFIG_DIR/admin.yaml"
fi

# Create example DAG
if [ ! -f "$DAGS_DIR/hello-world.yaml" ]; then
  cat > "$DAGS_DIR/hello-world.yaml" << 'YAML'
# Hello World — Your first Dagu DAG
# Run: dagu start ~/.config/dagu/dags/hello-world.yaml

steps:
  - name: greet
    command: echo "👋 Hello from Dagu!"
    
  - name: system-info
    command: |
      echo "Host: $(hostname)"
      echo "Time: $(date)"
      echo "User: $(whoami)"
    depends:
      - greet

  - name: done
    command: echo "✅ Pipeline complete!"
    depends:
      - system-info
YAML
  echo "📝 Example DAG created at $DAGS_DIR/hello-world.yaml"
fi

# Optionally set up systemd service
if command -v systemctl &>/dev/null && [ -d /etc/systemd/system ] || [ -d "$HOME/.config/systemd/user" ]; then
  echo ""
  read -p "🔄 Set up Dagu as a systemd user service? (y/N) " -n 1 -r REPLY
  echo ""
  
  if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/dagu.service" << EOF
[Unit]
Description=Dagu Workflow Engine
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/dagu server --config=$CONFIG_DIR/admin.yaml
Restart=on-failure
RestartSec=5
WorkingDirectory=$CONFIG_DIR

[Install]
WantedBy=default.target
EOF
    
    systemctl --user daemon-reload
    echo "✅ Systemd user service created"
    echo "   Start: systemctl --user start dagu"
    echo "   Enable on boot: systemctl --user enable dagu"
  fi
fi

# Verify installation
echo ""
echo "=================================="
export PATH="$INSTALL_DIR:$PATH"
if command -v dagu &>/dev/null; then
  echo "✅ Dagu $(dagu version 2>/dev/null || echo 'installed') is ready!"
else
  echo "✅ Dagu installed at $INSTALL_DIR/dagu"
fi

echo ""
echo "🚀 Next steps:"
echo "   1. Start dashboard: dagu server --config=$CONFIG_DIR/admin.yaml"
echo "   2. Open: http://localhost:8080"
echo "   3. Run hello-world: dagu start $DAGS_DIR/hello-world.yaml"
echo "   4. Create DAGs in: $DAGS_DIR/"
