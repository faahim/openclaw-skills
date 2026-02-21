#!/bin/bash
# Tailscale VPN Diagnostics — Full network health check
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[diag]${NC} $1"; }
warn() { echo -e "${YELLOW}[diag]${NC} $1"; }
err() { echo -e "${RED}[diag]${NC} $1"; }
section() { echo -e "\n${CYAN}═══ $1 ═══${NC}"; }

echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Tailscale VPN Diagnostics Report   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
echo "Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

# 1. Installation check
section "Installation"
if ! command -v tailscale &>/dev/null; then
    err "Tailscale is NOT installed"
    echo "Run: bash scripts/install.sh"
    exit 1
fi
VERSION=$(tailscale version 2>/dev/null | head -1)
log "Version: $VERSION"

# 2. Service status
section "Service Status"
if systemctl is-active --quiet tailscaled 2>/dev/null; then
    log "tailscaled: ✅ running"
else
    err "tailscaled: ❌ not running"
    echo "Fix: sudo systemctl start tailscaled"
fi

# 3. Connection status
section "Connection Status"
STATUS=$(tailscale status --json 2>/dev/null)
if [[ $? -eq 0 ]]; then
    SELF_IP=$(echo "$STATUS" | jq -r '.Self.TailscaleIPs[0] // "none"')
    SELF_NAME=$(echo "$STATUS" | jq -r '.Self.HostName // "unknown"')
    ONLINE=$(echo "$STATUS" | jq -r '.Self.Online // false')
    
    log "Hostname: $SELF_NAME"
    log "Tailscale IP: $SELF_IP"
    log "Online: $ONLINE"
    
    # Peer count
    PEER_COUNT=$(echo "$STATUS" | jq '[.Peer | to_entries[]] | length' 2>/dev/null || echo "0")
    ACTIVE_PEERS=$(echo "$STATUS" | jq '[.Peer | to_entries[] | select(.value.Online == true)] | length' 2>/dev/null || echo "0")
    log "Peers: $ACTIVE_PEERS active / $PEER_COUNT total"
    
    # List peers
    if [[ "$PEER_COUNT" -gt 0 ]]; then
        echo ""
        echo "  Peers:"
        tailscale status 2>/dev/null | tail -n +2 | while read -r line; do
            echo "    $line"
        done
    fi
else
    warn "Not connected to a tailnet"
    echo "Fix: sudo tailscale up"
fi

# 4. Network check
section "Network Health"
if command -v tailscale &>/dev/null; then
    tailscale netcheck 2>/dev/null | while read -r line; do
        echo "  $line"
    done
fi

# 5. IP forwarding (for subnet routing / exit node)
section "IP Forwarding"
if [[ -f /proc/sys/net/ipv4/ip_forward ]]; then
    IPV4_FWD=$(cat /proc/sys/net/ipv4/ip_forward)
    if [[ "$IPV4_FWD" == "1" ]]; then
        log "IPv4 forwarding: ✅ enabled"
    else
        warn "IPv4 forwarding: ❌ disabled (needed for subnet routing/exit node)"
        echo "  Fix: echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward"
    fi
fi
if [[ -f /proc/sys/net/ipv6/conf/all/forwarding ]]; then
    IPV6_FWD=$(cat /proc/sys/net/ipv6/conf/all/forwarding)
    if [[ "$IPV6_FWD" == "1" ]]; then
        log "IPv6 forwarding: ✅ enabled"
    else
        warn "IPv6 forwarding: ❌ disabled"
    fi
fi

# 6. Tailscale SSH
section "Tailscale SSH"
if tailscale status --json 2>/dev/null | jq -e '.Self.Capabilities // [] | map(select(. == "https://tailscale.com/cap/ssh")) | length > 0' &>/dev/null; then
    log "Tailscale SSH: ✅ enabled"
else
    warn "Tailscale SSH: not enabled"
    echo "  Enable: sudo tailscale up --ssh"
fi

# 7. Exit node
section "Exit Node"
EXIT_NODE=$(tailscale status --json 2>/dev/null | jq -r '.ExitNodeStatus.ID // "none"')
if [[ "$EXIT_NODE" != "none" && "$EXIT_NODE" != "null" ]]; then
    log "Using exit node: $EXIT_NODE"
else
    log "Not using an exit node"
fi

IS_EXIT=$(tailscale status --json 2>/dev/null | jq -r '.Self.ExitNode // false')
if [[ "$IS_EXIT" == "true" ]]; then
    log "This machine IS an exit node"
fi

# 8. DNS
section "DNS"
DNS_STATUS=$(tailscale status --json 2>/dev/null | jq -r '.MagicDNSSuffix // "not configured"')
log "MagicDNS suffix: $DNS_STATUS"

echo ""
echo -e "${CYAN}═══ Diagnostics Complete ═══${NC}"
