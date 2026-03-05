#!/bin/bash
# Install/remove CA root certificate from system trust store
set -euo pipefail

STEPPATH="${STEPPATH:-$HOME/.step}"
ROOT_CERT="$STEPPATH/certs/root_ca.crt"
ACTION="${1:-help}"

if [ ! -f "$ROOT_CERT" ]; then
  echo "❌ Root CA cert not found at $ROOT_CERT"
  echo "   Run: bash scripts/setup-ca.sh first"
  exit 1
fi

install_trust() {
  local os=$(uname -s)
  
  case "$os" in
    Linux)
      if [ -d /usr/local/share/ca-certificates ]; then
        sudo cp "$ROOT_CERT" /usr/local/share/ca-certificates/step-ca-root.crt
        sudo update-ca-certificates
        echo "✅ Root CA trusted system-wide (Debian/Ubuntu)"
      elif [ -d /etc/pki/ca-trust/source/anchors ]; then
        sudo cp "$ROOT_CERT" /etc/pki/ca-trust/source/anchors/step-ca-root.crt
        sudo update-ca-trust
        echo "✅ Root CA trusted system-wide (RHEL/Fedora)"
      elif [ -d /etc/ca-certificates/trust-source/anchors ]; then
        sudo cp "$ROOT_CERT" /etc/ca-certificates/trust-source/anchors/step-ca-root.crt
        sudo trust extract-compat
        echo "✅ Root CA trusted system-wide (Arch)"
      else
        echo "⚠️  Could not detect trust store location"
        echo "   Manually copy $ROOT_CERT to your system's CA trust directory"
        exit 1
      fi
      ;;
    Darwin)
      sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$ROOT_CERT"
      echo "✅ Root CA trusted system-wide (macOS)"
      ;;
    *)
      echo "❌ Unsupported OS: $os"
      exit 1
      ;;
  esac

  echo ""
  echo "📝 Note: Restart browsers and applications to pick up the new trust."
  echo "   Fingerprint: $(step certificate fingerprint "$ROOT_CERT" 2>/dev/null || openssl x509 -noout -fingerprint -sha256 -in "$ROOT_CERT" 2>/dev/null)"
}

remove_trust() {
  local os=$(uname -s)

  case "$os" in
    Linux)
      if [ -f /usr/local/share/ca-certificates/step-ca-root.crt ]; then
        sudo rm /usr/local/share/ca-certificates/step-ca-root.crt
        sudo update-ca-certificates --fresh
      elif [ -f /etc/pki/ca-trust/source/anchors/step-ca-root.crt ]; then
        sudo rm /etc/pki/ca-trust/source/anchors/step-ca-root.crt
        sudo update-ca-trust
      elif [ -f /etc/ca-certificates/trust-source/anchors/step-ca-root.crt ]; then
        sudo rm /etc/ca-certificates/trust-source/anchors/step-ca-root.crt
        sudo trust extract-compat
      fi
      echo "✅ Root CA removed from system trust"
      ;;
    Darwin)
      sudo security remove-trusted-cert -d "$ROOT_CERT" 2>/dev/null || true
      echo "✅ Root CA removed from macOS Keychain"
      ;;
  esac
}

show_info() {
  echo "📋 Root CA Certificate:"
  step certificate inspect "$ROOT_CERT" --short 2>/dev/null || openssl x509 -noout -subject -issuer -dates -in "$ROOT_CERT"
  echo ""
  echo "Fingerprint: $(step certificate fingerprint "$ROOT_CERT" 2>/dev/null || echo 'step-cli not available')"
}

case "$ACTION" in
  install) install_trust ;;
  remove)  remove_trust ;;
  info)    show_info ;;
  *)
    echo "Usage: bash scripts/trust.sh {install|remove|info}"
    echo ""
    echo "  install  Add root CA to system trust store"
    echo "  remove   Remove root CA from system trust store"
    echo "  info     Show root CA certificate details"
    exit 1
    ;;
esac
