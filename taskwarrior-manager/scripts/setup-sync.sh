#!/bin/bash
# Setup Taskwarrior sync with Taskserver (taskd)
set -e

SERVER=""
PORT="53589"
REGEN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --server) SERVER="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    --regenerate-certs) REGEN=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

CERT_DIR="$HOME/.task/certs"

if [[ "$REGEN" == true ]]; then
  echo "🔄 Regenerating certificates..."
  rm -rf "$CERT_DIR"
fi

if [[ -z "$SERVER" && ! -f "$CERT_DIR/ca.cert.pem" ]]; then
  echo "Usage: setup-sync.sh --server <hostname> [--port <port>]"
  echo ""
  echo "Options:"
  echo "  --server <host>       Taskserver hostname or IP"
  echo "  --port <port>         Taskserver port (default: 53589)"
  echo "  --regenerate-certs    Regenerate all certificates"
  exit 1
fi

if [[ -n "$SERVER" ]]; then
  echo "🔧 Configuring Taskserver sync..."
  echo ""

  # Create cert directory
  mkdir -p "$CERT_DIR"

  # Generate client certificate if needed
  if [[ ! -f "$CERT_DIR/client.cert.pem" ]]; then
    echo "📜 Generating client certificate..."

    # Generate private key
    openssl genrsa -out "$CERT_DIR/client.key.pem" 4096 2>/dev/null

    # Generate CSR
    openssl req -new -key "$CERT_DIR/client.key.pem" \
      -out "$CERT_DIR/client.req.pem" \
      -subj "/CN=Taskwarrior Client" 2>/dev/null

    echo "⚠️  You need the CA certificate from your Taskserver."
    echo "   Copy it to: $CERT_DIR/ca.cert.pem"
    echo "   Then have the server sign your client.req.pem"
    echo ""
    echo "   On the server, run:"
    echo "   taskd add user '<org>' '<username>'"
    echo "   Copy the generated UUID."
  fi

  # Configure taskwarrior
  task rc.confirmation=off config taskd.server "$SERVER:$PORT" 2>/dev/null
  task rc.confirmation=off config taskd.certificate "$CERT_DIR/client.cert.pem" 2>/dev/null
  task rc.confirmation=off config taskd.key "$CERT_DIR/client.key.pem" 2>/dev/null
  task rc.confirmation=off config taskd.ca "$CERT_DIR/ca.cert.pem" 2>/dev/null

  echo "✅ Taskserver configured: $SERVER:$PORT"
  echo ""
  echo "Next steps:"
  echo "  1. Copy ca.cert.pem from your server to $CERT_DIR/"
  echo "  2. Get your client cert signed by the server CA"
  echo "  3. Set your credentials: task config taskd.credentials '<org>/<user>/<uuid>'"
  echo "  4. Run: task sync init"
fi
