#!/bin/bash
# OpenVPN Manager — Certificate Rotation
set -euo pipefail

OVPN_DIR="/etc/openvpn"
CONFIG_FILE="$OVPN_DIR/.ovpn-manager.conf"

[[ $EUID -eq 0 ]] || { echo "Run as root (use sudo)" >&2; exit 1; }
[[ -f "$CONFIG_FILE" ]] || { echo "OpenVPN Manager not installed." >&2; exit 1; }
source "$CONFIG_FILE"

TARGET="${1:-}"
[[ "$TARGET" == "server" ]] || { echo "Usage: rotate.sh server"; exit 1; }

echo "⚠️  Rotating server certificate. All clients will need to reconnect."
echo "Press Ctrl+C to cancel, or wait 5 seconds..."
sleep 5

cd "$EASYRSA_DIR"

# Revoke old server cert
./easyrsa --batch revoke "$SERVER_NAME" 2>/dev/null || true
./easyrsa --batch gen-crl

# Generate new server cert
./easyrsa --batch --days="$CERT_DAYS" build-server-full "$SERVER_NAME" nopass

# Copy new certs
cp "pki/issued/${SERVER_NAME}.crt" "$OVPN_DIR/"
cp "pki/private/${SERVER_NAME}.key" "$OVPN_DIR/"
cp pki/crl.pem "$OVPN_DIR/"
chmod 600 "$OVPN_DIR/${SERVER_NAME}.key"

# Restart service
systemctl restart "openvpn@${SERVER_NAME}" 2>/dev/null || \
  systemctl restart "openvpn-server@${SERVER_NAME}" 2>/dev/null

echo ""
echo "✅ Server certificate rotated"
echo "⚠️  Regenerate client configs: sudo bash scripts/client.sh regenerate-all"
