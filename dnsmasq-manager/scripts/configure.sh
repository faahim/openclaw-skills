#!/bin/bash
# Dnsmasq Manager — Configuration Script
# Sets up dnsmasq for DNS forwarding, DHCP, and/or ad blocking

set -euo pipefail

MODE="dns"
UPSTREAM="${DNSMASQ_UPSTREAM:-1.1.1.1,8.8.8.8}"
CACHE_SIZE="${DNSMASQ_CACHE_SIZE:-5000}"
LOG_QUERIES=false
DHCP_RANGE=""
DHCP_GATEWAY=""
DHCP_DNS=""
ENABLE_TFTP=false
TFTP_ROOT=""
PXE_FILE=""
DOH=false
CONFIG_FILE="/etc/dnsmasq.d/openclaw.conf"

while [[ $# -gt 0 ]]; do
  case $1 in
    --mode) MODE="$2"; shift 2 ;;
    --upstream) UPSTREAM="$2"; shift 2 ;;
    --cache-size) CACHE_SIZE="$2"; shift 2 ;;
    --log-queries) LOG_QUERIES=true; shift ;;
    --range) DHCP_RANGE="$2"; shift 2 ;;
    --gateway) DHCP_GATEWAY="$2"; shift 2 ;;
    --dns-server) DHCP_DNS="$2"; shift 2 ;;
    --enable-tftp) ENABLE_TFTP=true; shift ;;
    --tftp-root) TFTP_ROOT="$2"; shift 2 ;;
    --pxe-file) PXE_FILE="$2"; shift 2 ;;
    --doh) DOH=true; shift ;;
    -h|--help)
      echo "Usage: bash configure.sh --mode <dns|dhcp|both> [options]"
      echo ""
      echo "DNS Options:"
      echo "  --upstream <servers>   Comma-separated upstream DNS (default: 1.1.1.1,8.8.8.8)"
      echo "  --cache-size <N>       DNS cache entries (default: 5000)"
      echo "  --log-queries          Enable query logging"
      echo "  --doh                  Use DNS-over-HTTPS (requires cloudflared)"
      echo ""
      echo "DHCP Options:"
      echo "  --range <start,end,lease>  DHCP range (e.g., 192.168.1.100,192.168.1.200,24h)"
      echo "  --gateway <ip>             Default gateway IP"
      echo "  --dns-server <ip>          DNS server to advertise to DHCP clients"
      echo ""
      echo "TFTP/PXE Options:"
      echo "  --enable-tftp          Enable TFTP server"
      echo "  --tftp-root <path>     TFTP root directory"
      echo "  --pxe-file <file>      PXE boot filename"
      exit 0 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Backup existing config
if [[ -f "$CONFIG_FILE" ]]; then
  sudo cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%s)"
  echo "📋 Backed up existing config"
fi

# Build config
CONFIG="# Dnsmasq configuration — managed by OpenClaw Dnsmasq Manager
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)

# Don't read /etc/resolv.conf for upstream servers
no-resolv

# Don't poll resolv.conf for changes
no-poll

# Never forward plain names (without a dot)
domain-needed

# Never forward reverse lookups for private ranges
bogus-priv
"

# DNS upstream servers
IFS=',' read -ra SERVERS <<< "$UPSTREAM"
for server in "${SERVERS[@]}"; do
  server=$(echo "$server" | xargs)  # trim whitespace
  CONFIG+="server=${server}
"
done

# Cache
CONFIG+="
# DNS cache
cache-size=${CACHE_SIZE}
"

# Logging
if [[ "$LOG_QUERIES" == "true" ]]; then
  LOG_DIR="${DNSMASQ_LOG_DIR:-/var/log}"
  CONFIG+="
# Query logging
log-queries
log-facility=${LOG_DIR}/dnsmasq.log
"
fi

# Custom hosts
CONFIG+="
# Custom host entries
addn-hosts=/etc/dnsmasq.d/custom.hosts
"

# DHCP
if [[ "$MODE" == "dhcp" || "$MODE" == "both" ]]; then
  if [[ -z "$DHCP_RANGE" ]]; then
    echo "❌ DHCP mode requires --range"
    exit 1
  fi
  CONFIG+="
# DHCP configuration
dhcp-range=${DHCP_RANGE}
dhcp-authoritative
"
  if [[ -n "$DHCP_GATEWAY" ]]; then
    CONFIG+="dhcp-option=option:router,${DHCP_GATEWAY}
"
  fi
  if [[ -n "$DHCP_DNS" ]]; then
    CONFIG+="dhcp-option=option:dns-server,${DHCP_DNS}
"
  fi
  # Static leases file
  CONFIG+="
# Static DHCP leases
conf-file=/etc/dnsmasq.d/static-leases.conf
"
  sudo touch /etc/dnsmasq.d/static-leases.conf 2>/dev/null || true
fi

# TFTP/PXE
if [[ "$ENABLE_TFTP" == "true" ]]; then
  CONFIG+="
# TFTP/PXE boot
enable-tftp
tftp-root=${TFTP_ROOT:-/srv/tftp}
"
  if [[ -n "$PXE_FILE" ]]; then
    CONFIG+="dhcp-boot=${PXE_FILE}
"
  fi
  sudo mkdir -p "${TFTP_ROOT:-/srv/tftp}" 2>/dev/null || true
fi

# Write config
echo "$CONFIG" | sudo tee "$CONFIG_FILE" > /dev/null

# Test config
echo "🔍 Testing configuration..."
if sudo dnsmasq --test --conf-file="$CONFIG_FILE" 2>&1; then
  echo "✅ Configuration valid"
else
  echo "❌ Configuration error — check $CONFIG_FILE"
  exit 1
fi

# Restart dnsmasq
if systemctl is-active dnsmasq &>/dev/null 2>&1; then
  sudo systemctl restart dnsmasq
  echo "🔄 Dnsmasq restarted"
elif command -v systemctl &>/dev/null; then
  sudo systemctl enable --now dnsmasq
  echo "🚀 Dnsmasq started and enabled"
elif command -v brew &>/dev/null; then
  sudo brew services restart dnsmasq 2>/dev/null || sudo dnsmasq --conf-file="$CONFIG_FILE"
  echo "🚀 Dnsmasq started"
else
  sudo dnsmasq --conf-file="$CONFIG_FILE"
  echo "🚀 Dnsmasq started"
fi

echo ""
echo "✅ Dnsmasq configured in ${MODE} mode"
echo "   Upstream: ${UPSTREAM}"
echo "   Cache: ${CACHE_SIZE} entries"
[[ "$LOG_QUERIES" == "true" ]] && echo "   Logging: enabled → ${DNSMASQ_LOG_DIR:-/var/log}/dnsmasq.log"
[[ "$MODE" == "dhcp" || "$MODE" == "both" ]] && echo "   DHCP range: ${DHCP_RANGE}"
echo "   Config: ${CONFIG_FILE}"
