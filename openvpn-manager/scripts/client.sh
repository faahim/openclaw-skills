#!/bin/bash
# OpenVPN Manager — Client Management Script
# Add, revoke, list, renew, and manage VPN client certificates.
set -euo pipefail

OVPN_DIR="/etc/openvpn"
CONFIG_FILE="$OVPN_DIR/.ovpn-manager.conf"

# ─── Helpers ────────────────────────────────────────────────────────
log() { echo -e "\033[1;32m[OpenVPN]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

check_root() { [[ $EUID -eq 0 ]] || err "Run as root (use sudo)"; }

load_config() {
  [[ -f "$CONFIG_FILE" ]] || err "OpenVPN Manager not installed. Run install.sh first."
  source "$CONFIG_FILE"
}

# ─── Add Client ─────────────────────────────────────────────────────
add_client() {
  local name="$1"
  local force=false
  local custom_dns=""
  shift || true
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --force) force=true; shift ;;
      --dns) custom_dns="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  [[ -n "$name" ]] || err "Usage: client.sh add <name> [--force] [--dns <ip>]"
  [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || err "Invalid name. Use alphanumeric, hyphens, underscores."
  
  cd "$EASYRSA_DIR"
  
  # Check if cert already exists
  if [ -f "pki/issued/${name}.crt" ] && [ "$force" = false ]; then
    err "Client '$name' already exists. Use --force to regenerate."
  elif [ -f "pki/issued/${name}.crt" ] && [ "$force" = true ]; then
    log "Revoking existing cert for $name before regenerating..."
    ./easyrsa --batch revoke "$name" 2>/dev/null || true
    ./easyrsa --batch gen-crl
    cp pki/crl.pem "$OVPN_DIR/"
  fi
  
  # Generate client cert
  ./easyrsa --batch --days="$CERT_DAYS" build-client-full "$name" nopass
  
  # Build .ovpn file
  local dns_to_use="${custom_dns:-$DNS}"
  local client_file="$OVPN_DIR/clients/${name}.ovpn"
  
  cat > "$client_file" << EOF
client
dev tun
proto $PROTO
remote $PUBLIC_IP $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3
key-direction 1

<ca>
$(cat "$OVPN_DIR/ca.crt")
</ca>

<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "pki/issued/${name}.crt")
</cert>

<key>
$(cat "pki/private/${name}.key")
</key>

<tls-crypt>
$(cat "$OVPN_DIR/ta.key")
</tls-crypt>
EOF
  
  chmod 600 "$client_file"
  
  local expiry_date
  expiry_date=$(openssl x509 -in "pki/issued/${name}.crt" -noout -enddate 2>/dev/null | cut -d= -f2)
  
  echo ""
  log "✅ Client certificate generated: $name"
  echo "📄 Config file: $client_file"
  echo "🔑 Valid until: $expiry_date"
  echo ""
  echo "Transfer this .ovpn file to the client device securely."
}

# ─── Revoke Client ──────────────────────────────────────────────────
revoke_client() {
  local name="$1"
  [[ -n "$name" ]] || err "Usage: client.sh revoke <name>"
  
  cd "$EASYRSA_DIR"
  
  [[ -f "pki/issued/${name}.crt" ]] || err "Client '$name' not found"
  
  ./easyrsa --batch revoke "$name"
  ./easyrsa --batch gen-crl
  cp pki/crl.pem "$OVPN_DIR/"
  
  # Remove client config
  rm -f "$OVPN_DIR/clients/${name}.ovpn"
  
  # Reload OpenVPN to apply CRL
  systemctl reload "openvpn@${SERVER_NAME}" 2>/dev/null || \
    systemctl reload "openvpn-server@${SERVER_NAME}" 2>/dev/null || \
    warn "Could not reload OpenVPN. Restart manually."
  
  echo ""
  log "🚫 Certificate revoked: $name"
  echo "📋 CRL updated"
  echo "♻️  OpenVPN service reloaded"
}

# ─── List Clients ───────────────────────────────────────────────────
list_clients() {
  cd "$EASYRSA_DIR"
  
  echo ""
  echo "ACTIVE CLIENTS:"
  
  local found_active=false
  for cert in pki/issued/*.crt; do
    [[ -f "$cert" ]] || continue
    local cn
    cn=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/.*CN *= *//')
    
    # Skip server cert
    [[ "$cn" == "$SERVER_NAME" ]] && continue
    
    # Check if revoked
    if openssl crl -in pki/crl.pem -noout -text 2>/dev/null | grep -q "$(openssl x509 -in "$cert" -noout -serial 2>/dev/null | cut -d= -f2)"; then
      continue
    fi
    
    local created expiry
    created=$(openssl x509 -in "$cert" -noout -startdate 2>/dev/null | cut -d= -f2 | cut -d' ' -f1-4)
    expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2 | cut -d' ' -f1-4)
    
    printf "  %-16s Created: %-12s Expires: %s\n" "$cn" "$created" "$expiry"
    found_active=true
  done
  
  [[ "$found_active" = true ]] || echo "  (none)"
  
  echo ""
  echo "REVOKED CLIENTS:"
  
  local found_revoked=false
  if [ -f pki/index.txt ]; then
    while IFS= read -r line; do
      if [[ "$line" == R* ]]; then
        local cn
        cn=$(echo "$line" | sed 's/.*CN=\([^/]*\).*/\1/')
        [[ "$cn" == "$SERVER_NAME" ]] && continue
        local revoke_date
        revoke_date=$(echo "$line" | awk '{print $3}' | head -c8)
        printf "  %-16s Revoked: %s\n" "$cn" "$revoke_date"
        found_revoked=true
      fi
    done < pki/index.txt
  fi
  
  [[ "$found_revoked" = true ]] || echo "  (none)"
  echo ""
}

# ─── Expiring Certificates ─────────────────────────────────────────
check_expiring() {
  local days="${1:-30}"
  local threshold=$((days * 86400))
  local now
  now=$(date +%s)
  local found=false
  
  cd "$EASYRSA_DIR"
  
  echo ""
  echo "⚠️  Certificates expiring within $days days:"
  
  for cert in pki/issued/*.crt; do
    [[ -f "$cert" ]] || continue
    local cn
    cn=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/.*CN *= *//')
    [[ "$cn" == "$SERVER_NAME" ]] && continue
    
    local expiry_epoch
    expiry_epoch=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry_epoch" +%s 2>/dev/null || echo "0")
    
    local remaining=$((expiry_epoch - now))
    if [[ $remaining -lt $threshold && $remaining -gt 0 ]]; then
      local days_left=$((remaining / 86400))
      local expiry_human
      expiry_human=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2 | cut -d' ' -f1-4)
      printf "  %-16s Expires: %s (%d days)\n" "$cn" "$expiry_human" "$days_left"
      found=true
    fi
  done
  
  [[ "$found" = true ]] || echo "  ✅ No certificates expiring within $days days"
  echo ""
  echo "Renew with: sudo bash scripts/client.sh add <name> --force"
}

# ─── Regenerate All Client Configs ──────────────────────────────────
regenerate_all() {
  cd "$EASYRSA_DIR"
  local count=0
  
  for cert in pki/issued/*.crt; do
    [[ -f "$cert" ]] || continue
    local cn
    cn=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/.*CN *= *//')
    [[ "$cn" == "$SERVER_NAME" ]] && continue
    
    # Skip revoked
    if openssl crl -in pki/crl.pem -noout -text 2>/dev/null | grep -q "$(openssl x509 -in "$cert" -noout -serial 2>/dev/null | cut -d= -f2)"; then
      continue
    fi
    
    # Rebuild .ovpn (reuse existing cert)
    local client_file="$OVPN_DIR/clients/${cn}.ovpn"
    cat > "$client_file" << EOF
client
dev tun
proto $PROTO
remote $PUBLIC_IP $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
verb 3
key-direction 1

<ca>
$(cat "$OVPN_DIR/ca.crt")
</ca>

<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' "pki/issued/${cn}.crt")
</cert>

<key>
$(cat "pki/private/${cn}.key")
</key>

<tls-crypt>
$(cat "$OVPN_DIR/ta.key")
</tls-crypt>
EOF
    chmod 600 "$client_file"
    ((count++))
    log "Regenerated: $cn"
  done
  
  log "✅ Regenerated $count client config(s)"
}

# ─── Main ───────────────────────────────────────────────────────────
main() {
  check_root
  load_config
  
  local action="${1:-help}"
  shift || true
  
  case "$action" in
    add)
      add_client "$@"
      ;;
    revoke)
      revoke_client "$@"
      ;;
    list)
      list_clients
      ;;
    expiring)
      check_expiring "$@"
      ;;
    regenerate-all)
      regenerate_all
      ;;
    *)
      echo "Usage: client.sh <action> [args]"
      echo ""
      echo "Actions:"
      echo "  add <name> [--force] [--dns <ip>]  Create client certificate & .ovpn"
      echo "  revoke <name>                       Revoke client access"
      echo "  list                                List all clients"
      echo "  expiring [days]                     Show certs expiring within N days"
      echo "  regenerate-all                      Rebuild all .ovpn files (after config change)"
      exit 1
      ;;
  esac
}

main "$@"
