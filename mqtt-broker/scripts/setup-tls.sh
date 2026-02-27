#!/bin/bash
# Generate TLS certificates and configure Mosquitto for encrypted connections
set -euo pipefail

CERT_DIR="/etc/mosquitto/certs"
DOMAIN=""
FORCE=false
DAYS=365

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    --days) DAYS="$2"; shift 2 ;;
    *) echo "Usage: $0 --domain <your-domain> [--force] [--days N]"; exit 1 ;;
  esac
done

if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 --domain <your-domain> [--force] [--days N]"
  exit 1
fi

if [ -f "$CERT_DIR/server.crt" ] && ! $FORCE; then
  echo "⚠️  Certificates already exist. Use --force to regenerate."
  exit 1
fi

echo "🔐 Generating TLS certificates for $DOMAIN..."

sudo mkdir -p "$CERT_DIR"

# Generate CA key and cert
sudo openssl genrsa -out "$CERT_DIR/ca.key" 2048
sudo openssl req -new -x509 -days $DAYS -key "$CERT_DIR/ca.key" \
  -out "$CERT_DIR/ca.crt" \
  -subj "/CN=MQTT CA/O=MQTT Broker/C=US"

# Generate server key and CSR
sudo openssl genrsa -out "$CERT_DIR/server.key" 2048
sudo openssl req -new -key "$CERT_DIR/server.key" \
  -out "$CERT_DIR/server.csr" \
  -subj "/CN=$DOMAIN/O=MQTT Broker/C=US"

# Create SAN extension file
sudo tee "$CERT_DIR/san.cnf" > /dev/null << EOF
[v3_req]
subjectAltName = @alt_names
[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

# Sign server cert with CA
sudo openssl x509 -req -in "$CERT_DIR/server.csr" \
  -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" \
  -CAcreateserial -out "$CERT_DIR/server.crt" \
  -days $DAYS -extensions v3_req -extfile "$CERT_DIR/san.cnf"

# Set permissions
sudo chmod 600 "$CERT_DIR"/*.key
sudo chmod 644 "$CERT_DIR"/*.crt
sudo chown -R mosquitto:mosquitto "$CERT_DIR" 2>/dev/null || true

# Clean up temp files
sudo rm -f "$CERT_DIR/server.csr" "$CERT_DIR/san.cnf" "$CERT_DIR/ca.srl"

# Add TLS config
CONF_FILE="/etc/mosquitto/conf.d/default.conf"
if ! grep -q "listener 8883" "$CONF_FILE" 2>/dev/null; then
  cat << TLS | sudo tee -a "$CONF_FILE" > /dev/null

# TLS encrypted listener
listener 8883
protocol mqtt
cafile $CERT_DIR/ca.crt
certfile $CERT_DIR/server.crt
keyfile $CERT_DIR/server.key
require_certificate false
TLS
fi

echo "✅ TLS certificates generated for $DOMAIN"
echo "   CA cert:     $CERT_DIR/ca.crt"
echo "   Server cert: $CERT_DIR/server.crt"
echo "   Server key:  $CERT_DIR/server.key"
echo ""
echo "   Broker will listen on port 8883 (MQTTS)"
echo "   Restart: sudo systemctl restart mosquitto"
echo ""
echo "   Test: mosquitto_pub -t test -m hello --cafile $CERT_DIR/ca.crt -p 8883"
