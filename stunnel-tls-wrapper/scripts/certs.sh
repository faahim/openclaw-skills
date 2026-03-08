#!/bin/bash
# Stunnel TLS Wrapper — Certificate Manager
set -euo pipefail

CERT_DIR="${STUNNEL_CERT_DIR:-/etc/stunnel/certs}"

usage() {
  cat << 'EOF'
Usage: certs.sh <command> [options]

Commands:
  generate      Generate a self-signed certificate
  check-expiry  Check expiry of all managed certificates
  renew         Renew expiring self-signed certificates
  install-cron  Install automatic renewal cron job
  info          Show certificate details

Generate Options:
  --name <name>     Certificate name (required)
  --cn <hostname>   Common Name / hostname (required)
  --days <days>     Validity period (default: 365)
  --san <domains>   Subject Alternative Names (comma-separated)
EOF
}

generate_cert() {
  local name="" cn="" days=365 san=""
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --cn) cn="$2"; shift 2 ;;
      --days) days="$2"; shift 2 ;;
      --san) san="$2"; shift 2 ;;
      *) echo "❌ Unknown option: $1"; exit 1 ;;
    esac
  done
  
  if [ -z "$name" ] || [ -z "$cn" ]; then
    echo "❌ --name and --cn are required"
    exit 1
  fi
  
  sudo mkdir -p "$CERT_DIR"
  
  local cert_file="$CERT_DIR/$name.pem"
  local ca_file="$CERT_DIR/$name-ca.pem"
  
  # Build SAN config
  local san_conf=""
  if [ -n "$san" ]; then
    san_conf="[SAN]\nsubjectAltName="
    local i=1
    IFS=',' read -ra DOMAINS <<< "$san"
    for domain in "${DOMAINS[@]}"; do
      [ $i -gt 1 ] && san_conf+=","
      san_conf+="DNS:$(echo "$domain" | tr -d ' ')"
      ((i++))
    done
  fi
  
  # Generate combined cert+key file (stunnel format)
  if [ -n "$san_conf" ]; then
    sudo openssl req -new -x509 -days "$days" -nodes \
      -out "$cert_file" \
      -keyout "$cert_file" \
      -subj "/CN=$cn" \
      -extensions SAN \
      -config <(cat /etc/ssl/openssl.cnf 2>/dev/null || echo "[req]"; echo -e "\n$san_conf") \
      2>/dev/null
  else
    sudo openssl req -new -x509 -days "$days" -nodes \
      -out "$cert_file" \
      -keyout "$cert_file" \
      -subj "/CN=$cn" \
      2>/dev/null
  fi
  
  # Extract CA cert (public only) for clients
  sudo openssl x509 -in "$cert_file" -out "$ca_file" 2>/dev/null
  
  # Secure permissions
  sudo chmod 600 "$cert_file"
  sudo chmod 644 "$ca_file"
  
  local expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
  
  echo "✅ Generated: $cert_file (cert+key)"
  echo "✅ CA cert:   $ca_file"
  echo "   Expires:  $expiry"
}

check_expiry() {
  echo "CERTIFICATE                          EXPIRES                    DAYS LEFT  STATUS"
  echo "--------------------------------------------------------------------------------"
  
  for cert_file in "$CERT_DIR"/*.pem; do
    [ -f "$cert_file" ] || continue
    
    # Skip CA-only certs
    local name=$(basename "$cert_file")
    [[ "$name" == *"-ca.pem" ]] && continue
    
    local expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    if [ -z "$expiry" ]; then
      printf "%-36s %-26s %-10s %s\n" "$name" "INVALID" "-" "❌ ERROR"
      continue
    fi
    
    local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
    local now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    
    local status="✅ OK"
    if [ $days_left -lt 0 ]; then
      status="❌ EXPIRED"
    elif [ $days_left -lt 7 ]; then
      status="🔴 CRITICAL"
    elif [ $days_left -lt 30 ]; then
      status="⚠️  EXPIRING SOON"
    fi
    
    printf "%-36s %-26s %-10s %s\n" "$name" "$expiry" "${days_left}d" "$status"
  done
}

renew_certs() {
  local threshold=30
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --threshold) threshold="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local renewed=0
  
  for cert_file in "$CERT_DIR"/*.pem; do
    [ -f "$cert_file" ] || continue
    local name=$(basename "$cert_file" .pem)
    [[ "$name" == *"-ca" ]] && continue
    
    # Check if self-signed (issuer == subject)
    local issuer=$(openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null)
    local subject=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null)
    
    if [ "$issuer" != "$subject" ]; then
      continue  # Not self-signed, skip
    fi
    
    local expiry_epoch=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry_epoch" +%s 2>/dev/null || echo 0)
    local now_epoch=$(date +%s)
    local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
    
    if [ $days_left -lt $threshold ]; then
      local cn=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/.*CN *= *//')
      echo "🔄 Renewing $name (${days_left}d remaining)..."
      generate_cert --name "$name" --cn "$cn" --days 365
      ((renewed++))
    fi
  done
  
  if [ $renewed -eq 0 ]; then
    echo "✅ No certificates need renewal (threshold: ${threshold} days)"
  else
    echo ""
    echo "✅ Renewed $renewed certificate(s). Restart stunnel to apply."
  fi
}

install_cron() {
  local threshold=30
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --threshold) threshold="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  local script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/certs.sh"
  local cron_line="0 3 * * * bash $script_path renew --threshold $threshold >> /var/log/stunnel/cert-renewal.log 2>&1"
  
  (crontab -l 2>/dev/null | grep -v "stunnel.*certs.sh"; echo "$cron_line") | crontab -
  echo "✅ Cron job installed: daily at 3am, renew certs expiring within ${threshold} days"
}

cert_info() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    echo "Usage: certs.sh info <cert-name>"
    exit 1
  fi
  
  local cert_file="$CERT_DIR/$name.pem"
  [ -f "$cert_file" ] || cert_file="$CERT_DIR/$name"
  
  if [ ! -f "$cert_file" ]; then
    echo "❌ Certificate not found: $name"
    exit 1
  fi
  
  openssl x509 -in "$cert_file" -noout -text 2>/dev/null | head -30
}

# Main command dispatch
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  generate)      generate_cert "$@" ;;
  check-expiry)  check_expiry ;;
  renew)         renew_certs "$@" ;;
  install-cron)  install_cron "$@" ;;
  info)          cert_info "$@" ;;
  *)             usage ;;
esac
