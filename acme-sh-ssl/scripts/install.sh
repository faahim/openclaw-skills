#!/bin/bash
# ACME.sh SSL Manager — Installer

set -euo pipefail

EMAIL="${ACME_EMAIL:-}"
CA="${ACME_CA:-letsencrypt}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --email) EMAIL="$2"; shift 2 ;;
    --ca) CA="$2"; shift 2 ;;
    --help) echo "Usage: bash install.sh [--email you@example.com] [--ca letsencrypt|zerossl|buypass|google]"; exit 0 ;;
    *) shift ;;
  esac
done

echo "🔧 Installing acme.sh SSL Certificate Manager..."
echo ""

# Check if already installed
if [[ -f "$HOME/.acme.sh/acme.sh" ]]; then
  echo "ℹ️  acme.sh already installed. Upgrading..."
  "$HOME/.acme.sh/acme.sh" --upgrade
  echo "✅ Upgraded to latest version"
  exit 0
fi

# Install acme.sh
echo "📥 Downloading acme.sh..."
curl -sS https://get.acme.sh | sh -s -- \
  ${EMAIL:+--accountemail "$EMAIL"} \
  2>&1 | grep -v "^$"

# Source the new profile
[[ -f "$HOME/.acme.sh/acme.sh.env" ]] && source "$HOME/.acme.sh/acme.sh.env"

# Set default CA
declare -A CA_SERVERS
CA_SERVERS[letsencrypt]="letsencrypt"
CA_SERVERS[zerossl]="zerossl"
CA_SERVERS[buypass]="buypass"
CA_SERVERS[google]="google"

if [[ -n "${CA_SERVERS[$CA]+x}" ]]; then
  "$HOME/.acme.sh/acme.sh" --set-default-ca --server "$CA" 2>/dev/null || true
  echo "✅ Default CA set to: $CA"
fi

# Verify installation
echo ""
if [[ -f "$HOME/.acme.sh/acme.sh" ]]; then
  VERSION=$("$HOME/.acme.sh/acme.sh" --version 2>/dev/null | head -1 || echo "unknown")
  echo "═══════════════════════════════════════════"
  echo "  ✅ acme.sh installed successfully!"
  echo "═══════════════════════════════════════════"
  echo ""
  echo "  Version:     $VERSION"
  echo "  Location:    $HOME/.acme.sh/"
  echo "  Default CA:  $CA"
  echo "  Auto-renew:  enabled (cron)"
  echo ""
  echo "  Issue cert:  bash scripts/issue.sh --domain example.com --mode standalone"
  echo "  Wildcard:    bash scripts/issue.sh --domain '*.example.com' --dns dns_cf"
  echo ""
else
  echo "❌ Installation failed. Check curl output above."
  exit 1
fi
