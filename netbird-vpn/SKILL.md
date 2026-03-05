---
name: netbird-vpn
description: >-
  Install, configure, and manage NetBird — an open-source WireGuard-based mesh VPN
  for connecting machines, containers, and cloud resources into a private network.
categories: [security, automation]
dependencies: [curl, netbird]
---

# NetBird VPN Manager

## What This Does

Installs and manages [NetBird](https://netbird.io) — an open-source, WireGuard-based mesh VPN that creates encrypted peer-to-peer connections between your machines. Unlike traditional VPNs, NetBird creates direct tunnels between peers (no central relay bottleneck), supports self-hosted management servers, and integrates with identity providers for access control.

**Example:** "Connect my home server, VPS, and laptop into a private mesh network with automatic peer discovery and firewall rules."

## Quick Start (5 minutes)

### 1. Install NetBird

```bash
# Linux (official install script)
curl -fsSL https://pkgs.netbird.io/install.sh | sudo sh

# Or via package manager (Debian/Ubuntu)
sudo apt-get update && sudo apt-get install -y netbird

# macOS
brew install netbird

# Verify installation
netbird version
```

### 2. Start and Authenticate

```bash
# Start the NetBird daemon
sudo netbird up

# This opens a browser for authentication (SSO)
# For headless servers, use setup key:
sudo netbird up --setup-key <YOUR_SETUP_KEY>
```

### 3. Check Status

```bash
# View connection status and peers
sudo netbird status

# Output:
# Daemon version: 0.31.0
# OS: linux/arm64
# Signal: Connected
# Management: Connected
# Relays: 2/2 Available
# Peers count: 3/3 Connected
```

## Core Workflows

### Workflow 1: Connect a New Machine

**Use case:** Add a server to your mesh network

```bash
# Generate a setup key from NetBird dashboard or API
# Then on the new machine:
bash scripts/setup.sh --setup-key "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

# Verify connection
sudo netbird status --detail
```

### Workflow 2: Manage Peers

**Use case:** List, inspect, or manage connected peers

```bash
# List all connected peers
bash scripts/manage.sh peers

# Output:
# PEER             IP              STATUS     LAST SEEN
# my-vps           100.64.0.1      Connected  just now
# home-server      100.64.0.2      Connected  2s ago
# laptop           100.64.0.3      Connected  5s ago

# Get detailed info on a specific peer
bash scripts/manage.sh peer-info my-vps
```

### Workflow 3: Configure Routes

**Use case:** Route traffic to subnets behind a peer

```bash
# Add a route (expose subnet 192.168.1.0/24 behind this peer)
bash scripts/manage.sh add-route --network "192.168.1.0/24" --peer "home-server"

# List routes
bash scripts/manage.sh routes
```

### Workflow 4: Monitor Connection Health

**Use case:** Continuously monitor mesh connectivity

```bash
# Run health check on all peers
bash scripts/health.sh

# Output:
# [2026-03-05 12:00:00] ✅ my-vps (100.64.0.1) — 23ms latency, WireGuard direct
# [2026-03-05 12:00:00] ✅ home-server (100.64.0.2) — 45ms latency, WireGuard direct
# [2026-03-05 12:00:00] ⚠️  laptop (100.64.0.3) — 120ms latency, relayed

# Run as cron (every 5 min)
bash scripts/health.sh --cron --alert telegram
```

### Workflow 5: Self-Hosted Management Server

**Use case:** Run your own NetBird management server (full control)

```bash
# Deploy self-hosted NetBird management
bash scripts/self-host.sh --domain vpn.yourdomain.com --email admin@yourdomain.com

# This sets up:
# - Management server
# - Signal server  
# - Coturn relay server
# - Dashboard UI
# - Let's Encrypt SSL
```

## Configuration

### Environment Variables

```bash
# NetBird cloud (default)
export NETBIRD_MANAGEMENT_URL="https://api.netbird.io"

# Self-hosted
export NETBIRD_MANAGEMENT_URL="https://vpn.yourdomain.com"

# Setup key (for headless auth)
export NETBIRD_SETUP_KEY="XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"

# For health check alerts
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"
```

### Config File

NetBird stores config at `/etc/netbird/config.json` (Linux) or `~/.netbird/config.json`.

```json
{
  "ManagementURL": "https://api.netbird.io",
  "AdminURL": "https://app.netbird.io",
  "WgPort": 51820,
  "DisableAutoConnect": false,
  "RosenpassEnabled": false
}
```

## Advanced Usage

### DNS Configuration

```bash
# Enable NetBird DNS (resolve peer names)
sudo netbird up --enable-dns

# Peers become accessible by name:
# ping my-vps.netbird.cloud
```

### Access Control Rules

```bash
# NetBird supports access control policies via the management API
# Example: Only allow SSH (port 22) between peers in "servers" group

curl -X POST "$NETBIRD_MANAGEMENT_URL/api/policies" \
  -H "Authorization: Token $NETBIRD_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Allow SSH to servers",
    "enabled": true,
    "rules": [{
      "name": "SSH",
      "enabled": true,
      "sources": ["developers"],
      "destinations": ["servers"],
      "bidirectional": false,
      "protocol": "tcp",
      "ports": ["22"],
      "action": "accept"
    }]
  }'
```

### Run as Systemd Service

```bash
# NetBird installs as a systemd service automatically
sudo systemctl status netbird
sudo systemctl enable netbird
sudo systemctl restart netbird

# View logs
sudo journalctl -u netbird -f
```

### Rosenpass Post-Quantum Security

```bash
# Enable Rosenpass for post-quantum key exchange
sudo netbird down
sudo netbird up --enable-rosenpass
```

## Troubleshooting

### Issue: "failed to connect to management server"

**Fix:**
```bash
# Check DNS resolution
dig api.netbird.io

# Check if port 443 is accessible
curl -I https://api.netbird.io

# Restart daemon
sudo netbird down && sudo netbird up
```

### Issue: Peers connected but no traffic

**Fix:**
```bash
# Check WireGuard interface
sudo wg show

# Check firewall rules
sudo iptables -L -n | grep wt0

# Ensure UDP port 51820 is open
sudo ufw allow 51820/udp
```

### Issue: High latency (relayed connection)

**Fix:**
```bash
# Check if direct connection is possible
sudo netbird status --detail

# Ensure UDP ports 49152-65535 are not blocked
# NAT traversal requires these for hole-punching
```

### Issue: Setup key expired

**Fix:**
```bash
# Generate new setup key from dashboard or API
curl -X POST "$NETBIRD_MANAGEMENT_URL/api/setup-keys" \
  -H "Authorization: Token $NETBIRD_API_TOKEN" \
  -d '{"name": "server-key", "type": "reusable", "expires_in": 86400}'
```

## Key Principles

1. **Mesh topology** — Peers connect directly (no bottleneck relay)
2. **Zero-trust** — All traffic encrypted with WireGuard
3. **Auto-discovery** — Peers find each other through management server
4. **NAT traversal** — Works behind firewalls without port forwarding
5. **Self-hostable** — Run your own management infrastructure
6. **Post-quantum ready** — Optional Rosenpass integration

## Dependencies

- `curl` (installation)
- `netbird` (installed by setup script)
- `wireguard` (kernel module, usually included)
- Optional: `docker` + `docker-compose` (for self-hosted management)
- Optional: `jq` (for API interactions)
