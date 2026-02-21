#!/bin/bash
# Let's Encrypt SSL Manager — Main Script
# Usage: bash ssl.sh <command> [options]
# Commands: obtain, renew, revoke, status, monitor, setup-renewal, nginx-config

set -euo pipefail

# ─── Config ───
LETSENCRYPT_DIR="/etc/letsencrypt/live"
LOG_DIR="${LOG_DIR:-./logs}"
ALERT_DAYS="${ALERT_DAYS:-14}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
RENEWAL_HOOK="${RENEWAL_HOOK:-}"

mkdir -p "$LOG_DIR"

# ─── Helpers ───
timestamp() { date -u '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $1" | tee -a "$LOG_DIR/ssl.log"; }

send_telegram() {
  local msg="$1"
  if [[ -n "$TELEGRAM_BOT_TOKEN" && -n "$TELEGRAM_CHAT_ID" ]]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=${msg}" \
      -d "parse_mode=HTML" >/dev/null 2>&1 || true
  fi
}

check_certbot() {
  if ! command -v certbot &>/dev/null; then
    log "❌ certbot not found. Run: bash scripts/install.sh"
    exit 1
  fi
}

get_cert_expiry() {
  local domain="$1"
  local cert_path="$LETSENCRYPT_DIR/$domain/fullchain.pem"
  if [[ -f "$cert_path" ]]; then
    openssl x509 -in "$cert_path" -noout -enddate 2>/dev/null | sed 's/notAfter=//'
  else
    echo "NOT_FOUND"
  fi
}

days_until_expiry() {
  local domain="$1"
  local expiry_str
  expiry_str=$(get_cert_expiry "$domain")
  if [[ "$expiry_str" == "NOT_FOUND" ]]; then
    echo "-1"
    return
  fi
  local expiry_epoch now_epoch
  expiry_epoch=$(date -d "$expiry_str" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry_str" +%s 2>/dev/null || echo "0")
  now_epoch=$(date +%s)
  echo $(( (expiry_epoch - now_epoch) / 86400 ))
}

# ─── Commands ───

cmd_obtain() {
  check_certbot
  local domains=() email="" webroot="" dns=false staging=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain|-d) domains+=("$2"); shift 2 ;;
      --email|-e) email="$2"; shift 2 ;;
      --webroot|-w) webroot="$2"; shift 2 ;;
      --dns) dns=true; shift ;;
      --staging) staging=true; shift ;;
      *) log "Unknown option: $1"; exit 1 ;;
    esac
  done

  email="${email:-$LETSENCRYPT_EMAIL}"

  if [[ ${#domains[@]} -eq 0 ]]; then
    log "❌ At least one --domain is required"
    exit 1
  fi
  if [[ -z "$email" ]]; then
    log "❌ --email or LETSENCRYPT_EMAIL env var is required"
    exit 1
  fi

  local domain_args=""
  for d in "${domains[@]}"; do
    domain_args="$domain_args -d $d"
  done

  local cmd="sudo certbot certonly --non-interactive --agree-tos --email $email"

  if $staging; then
    cmd="$cmd --staging"
  fi

  if $dns; then
    cmd="$cmd --manual --preferred-challenges dns $domain_args"
    log "🔐 Requesting wildcard/DNS certificate for ${domains[*]}..."
    log "⚠️  You will need to create DNS TXT records manually."
  elif [[ -n "$webroot" ]]; then
    cmd="$cmd --webroot --webroot-path $webroot $domain_args"
    log "🔐 Requesting certificate (webroot) for ${domains[*]}..."
  else
    cmd="$cmd --standalone $domain_args"
    log "🔐 Requesting certificate (standalone) for ${domains[*]}..."
  fi

  if eval "$cmd"; then
    local primary="${domains[0]}"
    local expiry
    expiry=$(get_cert_expiry "$primary")
    log "✅ Certificate obtained!"
    log "  Certificate: $LETSENCRYPT_DIR/$primary/fullchain.pem"
    log "  Private Key: $LETSENCRYPT_DIR/$primary/privkey.pem"
    log "  Expires: $expiry"
    send_telegram "✅ SSL certificate obtained for ${domains[*]}. Expires: $expiry"
  else
    log "❌ Certificate request failed. Check errors above."
    send_telegram "❌ SSL certificate request FAILED for ${domains[*]}"
    exit 1
  fi
}

cmd_renew() {
  check_certbot
  local domain="" all=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain|-d) domain="$2"; shift 2 ;;
      --all) all=true; shift ;;
      *) shift ;;
    esac
  done

  local hook_arg=""
  if [[ -n "$RENEWAL_HOOK" ]]; then
    hook_arg="--deploy-hook '$RENEWAL_HOOK'"
  fi

  if $all; then
    log "🔄 Renewing all certificates..."
    if eval "sudo certbot renew --non-interactive $hook_arg"; then
      log "✅ Renewal complete"
    else
      log "⚠️ Some renewals may have failed"
    fi
  elif [[ -n "$domain" ]]; then
    log "🔄 Renewing certificate for $domain..."
    if eval "sudo certbot renew --cert-name $domain --non-interactive --force-renewal $hook_arg"; then
      log "✅ Renewed: $domain"
      send_telegram "✅ SSL certificate renewed for $domain"
    else
      log "❌ Renewal failed for $domain"
      send_telegram "❌ SSL renewal FAILED for $domain"
      exit 1
    fi
  else
    log "❌ Specify --domain or --all"
    exit 1
  fi
}

cmd_revoke() {
  check_certbot
  local domain=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain|-d) domain="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$domain" ]]; then
    log "❌ --domain is required"
    exit 1
  fi

  log "🗑️  Revoking certificate for $domain..."
  if sudo certbot revoke --cert-name "$domain" --non-interactive --delete-after-revoke; then
    log "✅ Certificate revoked and deleted: $domain"
  else
    log "❌ Revocation failed for $domain"
    exit 1
  fi
}

cmd_status() {
  check_certbot
  log "📋 Certificate Status"
  echo ""

  # Header
  printf "%-30s %-15s %-10s %-8s\n" "Domain" "Expires" "Days Left" "Status"
  printf "%-30s %-15s %-10s %-8s\n" "------" "-------" "---------" "------"

  if [[ ! -d "$LETSENCRYPT_DIR" ]]; then
    echo "No certificates found in $LETSENCRYPT_DIR"
    return
  fi

  for cert_dir in "$LETSENCRYPT_DIR"/*/; do
    [[ -d "$cert_dir" ]] || continue
    local domain
    domain=$(basename "$cert_dir")
    local days
    days=$(days_until_expiry "$domain")
    local expiry_str
    expiry_str=$(get_cert_expiry "$domain")

    local status="✅ OK"
    if [[ "$days" -lt 0 ]]; then
      status="❌ EXPIRED"
    elif [[ "$days" -lt 7 ]]; then
      status="🔴 CRITICAL"
    elif [[ "$days" -lt 14 ]]; then
      status="⚠️  SOON"
    elif [[ "$days" -lt 30 ]]; then
      status="🟡 RENEW"
    fi

    # Format expiry date
    local expiry_short
    expiry_short=$(date -d "$expiry_str" '+%Y-%m-%d' 2>/dev/null || echo "$expiry_str")

    printf "%-30s %-15s %-10s %-8s\n" "$domain" "$expiry_short" "$days" "$status"
  done
}

cmd_monitor() {
  local alert_days="$ALERT_DAYS"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --alert-days) alert_days="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  log "🔍 Monitoring certificates (alert threshold: ${alert_days} days)..."

  if [[ ! -d "$LETSENCRYPT_DIR" ]]; then
    log "No certificates found."
    return
  fi

  local alerts=0
  for cert_dir in "$LETSENCRYPT_DIR"/*/; do
    [[ -d "$cert_dir" ]] || continue
    local domain
    domain=$(basename "$cert_dir")
    local days
    days=$(days_until_expiry "$domain")

    if [[ "$days" -lt "$alert_days" ]]; then
      alerts=$((alerts + 1))
      local msg="🚨 SSL Certificate Expiring Soon!
Domain: $domain
Days remaining: $days
Run: bash scripts/ssl.sh renew --domain $domain"
      log "$msg"
      send_telegram "$msg"
    fi
  done

  if [[ "$alerts" -eq 0 ]]; then
    log "✅ All certificates valid for at least $alert_days days."
  else
    log "⚠️  $alerts certificate(s) need attention!"
  fi
}

cmd_setup_renewal() {
  local hook=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hook) hook="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local cron_cmd="0 0,12 * * * certbot renew --non-interactive --quiet"
  if [[ -n "$hook" ]]; then
    cron_cmd="$cron_cmd --deploy-hook '$hook'"
    log "📌 Post-renewal hook: $hook"
  fi

  # Add to crontab (avoid duplicates)
  local existing
  existing=$(sudo crontab -l 2>/dev/null || true)
  if echo "$existing" | grep -q "certbot renew"; then
    log "⚠️  Renewal cron already exists. Replacing..."
    existing=$(echo "$existing" | grep -v "certbot renew")
  fi

  echo "$existing
# Let's Encrypt auto-renewal (added by ssl.sh)
$cron_cmd" | sudo crontab -

  log "✅ Auto-renewal cron installed (runs at 00:00 and 12:00 daily)"
  log "   View with: sudo crontab -l"
}

cmd_nginx_config() {
  local domain=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain|-d) domain="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$domain" ]]; then
    log "❌ --domain is required"
    exit 1
  fi

  cat <<NGINX
# Nginx SSL Configuration for $domain
# Generated by Let's Encrypt SSL Manager

server {
    listen 80;
    server_name $domain www.$domain;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain www.$domain;

    # SSL Certificate
    ssl_certificate     $LETSENCRYPT_DIR/$domain/fullchain.pem;
    ssl_certificate_key $LETSENCRYPT_DIR/$domain/privkey.pem;

    # SSL Settings (Mozilla Modern)
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # HSTS (1 year)
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate $LETSENCRYPT_DIR/$domain/chain.pem;
    resolver 1.1.1.1 8.8.8.8 valid=300s;
    resolver_timeout 5s;

    # Your application
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

  log "📄 Nginx config generated for $domain"
  log "   Save to: /etc/nginx/sites-available/$domain"
  log "   Enable:  sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/"
  log "   Test:    sudo nginx -t && sudo systemctl reload nginx"
}

# ─── Main ───
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  obtain)        cmd_obtain "$@" ;;
  renew)         cmd_renew "$@" ;;
  revoke)        cmd_revoke "$@" ;;
  status)        cmd_status ;;
  monitor)       cmd_monitor "$@" ;;
  setup-renewal) cmd_setup_renewal "$@" ;;
  nginx-config)  cmd_nginx_config "$@" ;;
  *)
    echo "Let's Encrypt SSL Manager"
    echo ""
    echo "Usage: bash ssl.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  obtain        Request a new SSL certificate"
    echo "  renew         Renew existing certificate(s)"
    echo "  revoke        Revoke and delete a certificate"
    echo "  status        Show all certificates and expiry"
    echo "  monitor       Check expiry and send alerts"
    echo "  setup-renewal Install auto-renewal cron job"
    echo "  nginx-config  Generate Nginx SSL config block"
    echo ""
    echo "Options:"
    echo "  --domain, -d   Domain name (repeatable)"
    echo "  --email, -e    Email for Let's Encrypt account"
    echo "  --webroot, -w  Webroot path (for webroot challenge)"
    echo "  --dns          Use DNS challenge (for wildcards)"
    echo "  --staging      Use staging server (testing)"
    echo "  --all          Renew all certs"
    echo "  --alert-days   Days before expiry to alert (default: 14)"
    echo "  --hook         Post-renewal command"
    ;;
esac
