#!/bin/bash
# ACME.sh SSL Manager — Certificate Management

set -euo pipefail

ACME="$HOME/.acme.sh/acme.sh"
[[ -f "$ACME" ]] || { echo "❌ acme.sh not installed."; exit 1; }

ACTION=""
DOMAIN=""
FORCE=false
FORMAT=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --list) ACTION="list"; shift ;;
    --renew) ACTION="renew"; DOMAIN="${2:-}"; shift; [[ -n "$DOMAIN" ]] && shift ;;
    --renew-all) ACTION="renew-all"; shift ;;
    --revoke) ACTION="revoke"; DOMAIN="$2"; shift 2 ;;
    --remove) ACTION="remove"; DOMAIN="$2"; shift 2 ;;
    --check-expiry) ACTION="check-expiry"; shift ;;
    --export) ACTION="export"; DOMAIN="$2"; shift 2 ;;
    --force) FORCE=true; shift ;;
    --format) FORMAT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --help) echo "Usage: bash manage.sh [--list|--renew domain|--renew-all|--revoke domain|--remove domain|--check-expiry|--export domain]"; exit 0 ;;
    *) shift ;;
  esac
done

[[ -z "$ACTION" ]] && { echo "Usage: bash manage.sh [--list|--renew domain|--check-expiry]"; exit 1; }

case "$ACTION" in
  list)
    echo "📜 Issued Certificates:"
    echo ""
    "$ACME" --list 2>/dev/null | while IFS= read -r line; do
      echo "  $line"
    done
    ;;
    
  renew)
    [[ -z "$DOMAIN" ]] && { echo "❌ Specify domain: --renew example.com"; exit 1; }
    echo "🔄 Renewing certificate for $DOMAIN..."
    CMD=("$ACME" --renew -d "$DOMAIN")
    [[ "$FORCE" == true ]] && CMD+=(--force)
    if "${CMD[@]}"; then
      echo "✅ Certificate renewed"
    else
      echo "❌ Renewal failed"
      exit 1
    fi
    ;;
    
  renew-all)
    echo "🔄 Renewing all due certificates..."
    "$ACME" --cron
    echo "✅ Renewal check complete"
    ;;
    
  revoke)
    [[ -z "$DOMAIN" ]] && { echo "❌ Specify domain"; exit 1; }
    echo "⚠️  Revoking certificate for $DOMAIN..."
    "$ACME" --revoke -d "$DOMAIN"
    echo "✅ Certificate revoked"
    ;;
    
  remove)
    [[ -z "$DOMAIN" ]] && { echo "❌ Specify domain"; exit 1; }
    echo "🗑️  Removing certificate for $DOMAIN..."
    "$ACME" --remove -d "$DOMAIN"
    echo "✅ Certificate removed"
    ;;
    
  check-expiry)
    echo "📅 Certificate Expiry Report:"
    echo ""
    for cert_dir in "$HOME/.acme.sh"/*/; do
      domain=$(basename "$cert_dir")
      [[ "$domain" == "ca" ]] && continue
      [[ "$domain" == "http.header" ]] && continue
      
      cert_file="$cert_dir/fullchain.cer"
      [[ -f "$cert_file" ]] || cert_file="$cert_dir/${domain}.cer"
      [[ -f "$cert_file" ]] || continue
      
      expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
      if [[ -n "$expiry_date" ]]; then
        expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || date -jf "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null || echo 0)
        now_epoch=$(date +%s)
        days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
        
        if [[ $days_left -lt 7 ]]; then
          status="🔴 CRITICAL"
        elif [[ $days_left -lt 14 ]]; then
          status="⚠️  WARNING"
        elif [[ $days_left -lt 30 ]]; then
          status="🟡 RENEWING SOON"
        else
          status="✅"
        fi
        
        printf "  %-30s — %3d days remaining %s\n" "$domain" "$days_left" "$status"
      fi
    done
    ;;
    
  export)
    [[ -z "$DOMAIN" ]] && { echo "❌ Specify domain"; exit 1; }
    FORMAT="${FORMAT:-pkcs12}"
    OUTPUT="${OUTPUT:-${DOMAIN}.p12}"
    
    CERT_DIR="$HOME/.acme.sh/${DOMAIN}_ecc"
    [[ -d "$CERT_DIR" ]] || CERT_DIR="$HOME/.acme.sh/$DOMAIN"
    
    case "$FORMAT" in
      pkcs12|p12)
        openssl pkcs12 -export \
          -in "$CERT_DIR/fullchain.cer" \
          -inkey "$CERT_DIR/${DOMAIN}.key" \
          -out "$OUTPUT"
        echo "✅ Exported to $OUTPUT (PKCS12)"
        ;;
      pem)
        cat "$CERT_DIR/fullchain.cer" "$CERT_DIR/${DOMAIN}.key" > "$OUTPUT"
        echo "✅ Exported to $OUTPUT (combined PEM)"
        ;;
      *)
        echo "❌ Unknown format: $FORMAT (use: pkcs12, pem)"
        exit 1
        ;;
    esac
    ;;
esac
