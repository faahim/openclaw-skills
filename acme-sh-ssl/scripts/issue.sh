#!/bin/bash
# ACME.sh SSL Manager — Issue Certificate

set -euo pipefail

ACME="$HOME/.acme.sh/acme.sh"
[[ -f "$ACME" ]] || { echo "❌ acme.sh not installed. Run: bash scripts/install.sh"; exit 1; }

DOMAIN=""
MODE="standalone"
DNS_PROVIDER=""
WEBROOT=""
SANS=()
KEYLENGTH=""
STAGING=false
PRE_HOOK=""
POST_HOOK=""
SERVER=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --domain|-d) DOMAIN="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --dns) DNS_PROVIDER="$2"; MODE="dns"; shift 2 ;;
    --webroot) WEBROOT="$2"; shift 2 ;;
    --san) SANS+=("$2"); shift 2 ;;
    --keylength) KEYLENGTH="$2"; shift 2 ;;
    --staging) STAGING=true; shift ;;
    --pre-hook) PRE_HOOK="$2"; shift 2 ;;
    --post-hook) POST_HOOK="$2"; shift 2 ;;
    --server) SERVER="$2"; shift 2 ;;
    --help) echo "Usage: bash issue.sh --domain example.com [--mode standalone|webroot|nginx|dns] [--dns dns_cf] [--san extra.com] [--keylength ec-256] [--staging]"; exit 0 ;;
    *) shift ;;
  esac
done

[[ -z "$DOMAIN" ]] && { echo "❌ --domain is required"; exit 1; }

echo "🔐 Issuing certificate for $DOMAIN..."
echo ""

# Build command
CMD=("$ACME" --issue -d "$DOMAIN")

# Add SANs
for san in "${SANS[@]}"; do
  CMD+=(-d "$san")
done

# Mode
case "$MODE" in
  standalone)
    CMD+=(--standalone)
    ;;
  webroot)
    [[ -z "$WEBROOT" ]] && WEBROOT="/var/www/html"
    CMD+=(-w "$WEBROOT")
    ;;
  nginx)
    CMD+=(--nginx)
    ;;
  dns)
    [[ -z "$DNS_PROVIDER" ]] && DNS_PROVIDER="dns_manual"
    CMD+=(--dns "$DNS_PROVIDER")
    ;;
  *)
    echo "❌ Unknown mode: $MODE (use: standalone, webroot, nginx, dns)"
    exit 1
    ;;
esac

# Key length
[[ -n "$KEYLENGTH" ]] && CMD+=(--keylength "$KEYLENGTH")

# Staging
[[ "$STAGING" == true ]] && CMD+=(--staging)

# Custom server
[[ -n "$SERVER" ]] && CMD+=(--server "$SERVER")

# Hooks
[[ -n "$PRE_HOOK" ]] && CMD+=(--pre-hook "$PRE_HOOK")
[[ -n "$POST_HOOK" ]] && CMD+=(--post-hook "$POST_HOOK")

# Execute
echo "Running: ${CMD[*]}"
echo ""

if "${CMD[@]}"; then
  echo ""
  echo "═══════════════════════════════════════════"
  echo "  ✅ Certificate issued successfully!"
  echo "═══════════════════════════════════════════"
  echo ""
  
  # Find cert location
  CERT_DIR="$HOME/.acme.sh/${DOMAIN}_ecc"
  [[ -d "$CERT_DIR" ]] || CERT_DIR="$HOME/.acme.sh/$DOMAIN"
  
  if [[ -d "$CERT_DIR" ]]; then
    echo "  Cert:      $CERT_DIR/fullchain.cer"
    echo "  Key:       $CERT_DIR/${DOMAIN}.key"
    
    # Show expiry
    if [[ -f "$CERT_DIR/fullchain.cer" ]]; then
      EXPIRY=$(openssl x509 -in "$CERT_DIR/fullchain.cer" -noout -enddate 2>/dev/null | cut -d= -f2)
      echo "  Expires:   $EXPIRY"
    fi
  fi
  
  echo ""
  echo "  Deploy:    bash scripts/deploy.sh --domain $DOMAIN --server nginx"
  echo "  Auto-renew is already configured via cron"
  echo ""
else
  echo ""
  echo "❌ Certificate issuance failed. Check output above."
  echo ""
  echo "Common fixes:"
  echo "  - Port 80 blocked? Use DNS mode: --dns dns_cf"
  echo "  - Rate limited? Use --staging first"
  echo "  - DNS not propagated? Wait and retry"
  exit 1
fi
