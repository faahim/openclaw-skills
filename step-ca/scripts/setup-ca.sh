#!/bin/bash
# Initialize a Smallstep Certificate Authority
set -euo pipefail

CA_NAME="My Private CA"
CA_DNS="localhost"
CA_ADDRESS=":8443"
ENABLE_ACME=false
ENABLE_SSH=false
DB_TYPE=""
DB_URL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --name) CA_NAME="$2"; shift 2 ;;
    --dns) CA_DNS="$2"; shift 2 ;;
    --address) CA_ADDRESS="$2"; shift 2 ;;
    --enable-acme) ENABLE_ACME=true; shift ;;
    --enable-ssh) ENABLE_SSH=true; shift ;;
    --db-type) DB_TYPE="$2"; shift 2 ;;
    --db-url) DB_URL="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

STEPPATH="${STEPPATH:-$HOME/.step}"

echo "🔐 Initializing Certificate Authority..."
echo "   Name:    $CA_NAME"
echo "   DNS:     $CA_DNS"
echo "   Address: $CA_ADDRESS"
echo ""

# Check if already initialized
if [ -f "$STEPPATH/config/ca.json" ]; then
  echo "⚠️  CA already initialized at $STEPPATH"
  read -p "   Reinitialize? This will DESTROY existing CA. (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi
  rm -rf "$STEPPATH"
fi

# Build init command
INIT_CMD="step ca init --name \"$CA_NAME\" --dns \"$CA_DNS\" --address \"$CA_ADDRESS\" --provisioner admin"

# Add SSH if requested
if [ "$ENABLE_SSH" = true ]; then
  INIT_CMD="$INIT_CMD --ssh"
fi

# Run init (interactive — asks for password)
echo "📝 You'll be asked to set a CA password. Choose a strong one!"
echo ""
eval $INIT_CMD

echo ""
echo "✅ CA initialized at $STEPPATH"

# Enable ACME provisioner if requested
if [ "$ENABLE_ACME" = true ]; then
  echo ""
  echo "🔧 Adding ACME provisioner..."
  step ca provisioner add acme --type ACME
  echo "✅ ACME enabled. ACME directory: https://${CA_DNS}${CA_ADDRESS}/acme/acme/directory"
fi

# Configure database backend if specified
if [ -n "$DB_TYPE" ] && [ "$DB_TYPE" = "postgres" ] && [ -n "$DB_URL" ]; then
  echo ""
  echo "🔧 Configuring PostgreSQL database..."
  # Update ca.json with postgres config
  tmpfile=$(mktemp)
  jq --arg url "$DB_URL" '.db = {"type": "postgresql", "dataSource": $url}' "$STEPPATH/config/ca.json" > "$tmpfile"
  mv "$tmpfile" "$STEPPATH/config/ca.json"
  echo "✅ PostgreSQL database configured"
fi

echo ""
echo "📋 Summary:"
echo "   Root cert:         $STEPPATH/certs/root_ca.crt"
echo "   Intermediate cert: $STEPPATH/certs/intermediate_ca.crt"
echo "   CA config:         $STEPPATH/config/ca.json"
echo ""
echo "🔒 IMPORTANT: Back up $STEPPATH/secrets/ — losing these keys means recreating your entire CA!"
echo ""
echo "Next steps:"
echo "  1. Start CA:       bash scripts/manage.sh start"
echo "  2. Trust CA:       bash scripts/trust.sh install"
echo "  3. Issue cert:     bash scripts/cert.sh issue myapp.internal.lan"
