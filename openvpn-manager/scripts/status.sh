#!/bin/bash
# OpenVPN Manager — Server Status
set -euo pipefail

OVPN_DIR="/etc/openvpn"
CONFIG_FILE="$OVPN_DIR/.ovpn-manager.conf"
CHECK_MODE=false

[[ "${1:-}" == "--check" ]] && CHECK_MODE=true
[[ $EUID -eq 0 ]] || { echo "Run as root (use sudo)" >&2; exit 1; }
[[ -f "$CONFIG_FILE" ]] || { echo "OpenVPN Manager not installed." >&2; exit 1; }
source "$CONFIG_FILE"

# Service status
SERVICE_ACTIVE=false
PID=""
if systemctl is-active --quiet "openvpn@${SERVER_NAME}" 2>/dev/null; then
  SERVICE_ACTIVE=true
  PID=$(systemctl show "openvpn@${SERVER_NAME}" -p MainPID --value 2>/dev/null)
elif systemctl is-active --quiet "openvpn-server@${SERVER_NAME}" 2>/dev/null; then
  SERVICE_ACTIVE=true
  PID=$(systemctl show "openvpn-server@${SERVER_NAME}" -p MainPID --value 2>/dev/null)
fi

# Check-only mode (for cron monitoring)
if [ "$CHECK_MODE" = true ]; then
  if [ "$SERVICE_ACTIVE" = true ]; then
    exit 0
  else
    exit 1
  fi
fi

echo ""
echo "OpenVPN Server Status"
echo "═══════════════════════"

if [ "$SERVICE_ACTIVE" = true ]; then
  echo "Service:     ✅ Running (pid $PID)"
else
  echo "Service:     ❌ NOT RUNNING"
fi

echo "Protocol:    ${PROTO^^} $PORT"
echo "Subnet:      $SUBNET/24"
echo "DNS:         $DNS, $DNS2"
echo ""

# Connected clients from status log
STATUS_LOG="/var/log/openvpn/status.log"
if [ -f "$STATUS_LOG" ]; then
  CLIENT_COUNT=0
  echo "Connected Clients:"
  
  IN_CLIENT_LIST=false
  while IFS= read -r line; do
    if [[ "$line" == "Common Name,"* ]]; then
      IN_CLIENT_LIST=true
      continue
    fi
    if [[ "$line" == "ROUTING TABLE"* ]]; then
      break
    fi
    if [ "$IN_CLIENT_LIST" = true ] && [[ -n "$line" ]]; then
      IFS=',' read -r cn real_addr bytes_recv bytes_sent connected_since <<< "$line"
      local_bytes_recv=$(numfmt --to=iec "$bytes_recv" 2>/dev/null || echo "${bytes_recv}B")
      local_bytes_sent=$(numfmt --to=iec "$bytes_sent" 2>/dev/null || echo "${bytes_sent}B")
      printf "  %-16s ↑%s ↓%s  Since: %s\n" "$cn" "$local_bytes_sent" "$local_bytes_recv" "$connected_since"
      ((CLIENT_COUNT++))
    fi
  done < "$STATUS_LOG"
  
  [[ $CLIENT_COUNT -gt 0 ]] || echo "  (none)"
  echo ""
fi

# Certificate summary
cd "${EASYRSA_DIR}" 2>/dev/null || exit 0
ACTIVE=0
REVOKED=0
EXPIRING_SOON=0
NOW=$(date +%s)
THRESHOLD=$((30 * 86400))

for cert in pki/issued/*.crt; do
  [[ -f "$cert" ]] || continue
  cn=$(openssl x509 -in "$cert" -noout -subject 2>/dev/null | sed 's/.*CN *= *//')
  [[ "$cn" == "$SERVER_NAME" ]] && continue
  
  if openssl crl -in pki/crl.pem -noout -text 2>/dev/null | grep -q "$(openssl x509 -in "$cert" -noout -serial 2>/dev/null | cut -d= -f2)"; then
    ((REVOKED++))
  else
    ((ACTIVE++))
    expiry=$(openssl x509 -in "$cert" -noout -enddate 2>/dev/null | cut -d= -f2)
    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
    remaining=$((expiry_epoch - NOW))
    [[ $remaining -lt $THRESHOLD && $remaining -gt 0 ]] && ((EXPIRING_SOON++))
  fi
done

echo "Certificates:"
echo "  Active: $ACTIVE    Revoked: $REVOKED    Expiring <30d: $EXPIRING_SOON"
echo ""
