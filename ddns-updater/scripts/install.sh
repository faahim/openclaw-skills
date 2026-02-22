#!/usr/bin/env bash
# Install DDNS Updater
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"
CONFIG_DIR="${HOME}/.config/ddns-updater"

echo "📦 Installing DDNS Updater..."

# Check dependencies
for cmd in curl jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Missing dependency: $cmd"
    echo "   Install with: sudo apt-get install -y $cmd"
    exit 1
  fi
done

# Create directories
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR"

# Copy script
cp "${SCRIPT_DIR}/ddns-updater.sh" "${INSTALL_DIR}/ddns-updater"
chmod +x "${INSTALL_DIR}/ddns-updater"

# Copy config template if no config exists
if [[ ! -f "${CONFIG_DIR}/config.yaml" ]]; then
  cp "${SCRIPT_DIR}/config-template.yaml" "${CONFIG_DIR}/config.yaml"
  echo "📝 Config template copied to ${CONFIG_DIR}/config.yaml"
  echo "   Edit it with your provider details."
else
  echo "ℹ️  Config already exists at ${CONFIG_DIR}/config.yaml"
fi

# Check PATH
if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
  echo "⚠️  ${INSTALL_DIR} is not in PATH. Add to ~/.bashrc:"
  echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
echo "✅ DDNS Updater installed!"
echo ""
echo "Quick start:"
echo "  ddns-updater --provider duckdns --domain myhost"
echo "  ddns-updater --provider cloudflare --domain home.example.com"
echo ""
echo "Set up cron (every 5 min):"
echo "  (crontab -l 2>/dev/null; echo '*/5 * * * * ddns-updater --provider cloudflare --domain home.example.com >> /var/log/ddns-updater.log 2>&1') | crontab -"
