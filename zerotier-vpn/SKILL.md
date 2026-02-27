---
name: zerotier-vpn
description: >-
  Install, configure, and manage ZeroTier virtual networks — create secure peer-to-peer VPN meshes without port forwarding or central servers.
categories: [security, automation]
dependencies: [curl, jq]
---

# ZeroTier VPN Manager

## What This Does

Installs and manages ZeroTier One — a peer-to-peer encrypted virtual network that connects your devices without port forwarding, firewall rules, or central VPN servers. Create private networks, join devices, manage members, and monitor connectivity.

**Example:** "Set up a private network connecting your laptop, VPS, and Raspberry Pi — all accessible via private IPs, no port forwarding needed."

## Quick Start (5 minutes)

### 1. Install ZeroTier

```bash
# Linux (Debian/Ubuntu/CentOS/Fedora/Arch)
curl -s https://install.zerotier.com | sudo bash

# macOS
brew install --cask zerotier-one

# Verify installation
sudo zerotier-cli info
# Output: 200 info <node-id> <version> ONLINE
```

### 2. Create a Network (via API)

```bash
# Set your ZeroTier Central API token
export ZT_API_TOKEN="your-api-token-from-my.zerotier.com"

# Create a new private network
NETWORK=$(curl -s -X POST "https://api.zerotier.com/api/v1/network" \
  -H "Authorization: token $ZT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"config": {"name": "my-network", "private": true, "ipAssignmentPools": [{"ipRangeStart": "10.147.17.1", "ipRangeEnd": "10.147.17.254"}], "routes": [{"target": "10.147.17.0/24"}], "v4AssignMode": {"zt": true}}}')

NETWORK_ID=$(echo "$NETWORK" | jq -r '.id')
echo "Network created: $NETWORK_ID"
```

### 3. Join the Network

```bash
# Join from any device
sudo zerotier-cli join $NETWORK_ID

# Authorize the device (via API)
NODE_ID=$(sudo zerotier-cli info | awk '{print $3}')
curl -s -X POST "https://api.zerotier.com/api/v1/network/$NETWORK_ID/member/$NODE_ID" \
  -H "Authorization: token $ZT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"config": {"authorized": true}}'

echo "Device authorized. Check IP:"
sudo zerotier-cli listnetworks
```

## Core Workflows

### Workflow 1: Install & Join Existing Network

**Use case:** Add a new device to an existing ZeroTier network

```bash
# Install
bash scripts/install.sh

# Join network
bash scripts/manage.sh join <network-id>

# Check status
bash scripts/manage.sh status
```

### Workflow 2: Create & Manage a Network

**Use case:** Set up a new private mesh VPN

```bash
export ZT_API_TOKEN="your-token"

# Create network with custom IP range
bash scripts/manage.sh create --name "home-lab" --cidr "10.42.0.0/24"

# List members
bash scripts/manage.sh members <network-id>

# Authorize a member
bash scripts/manage.sh authorize <network-id> <member-id>

# Deauthorize a member
bash scripts/manage.sh deauthorize <network-id> <member-id>
```

### Workflow 3: Network Diagnostics

**Use case:** Troubleshoot connectivity between nodes

```bash
# Check local node status
bash scripts/manage.sh status

# List all peers and their paths (direct vs relay)
bash scripts/manage.sh peers

# Ping a peer via ZeroTier IP
ping 10.147.17.5

# Check if connection is direct or relayed
sudo zerotier-cli peers | grep <node-id>
# DIRECT = good, RELAY = behind strict NAT
```

### Workflow 4: Monitor Network Health

**Use case:** Periodic health check of your ZeroTier mesh

```bash
export ZT_API_TOKEN="your-token"

# Get network overview
bash scripts/manage.sh overview <network-id>
# Output:
# Network: home-lab (abc123def4)
# Members: 5 authorized, 1 pending
# IP Range: 10.42.0.0/24
# Online: 4/5

# Check all members' online status
bash scripts/manage.sh members <network-id> --online-only
```

### Workflow 5: Auto-Join on Boot (systemd)

**Use case:** Ensure ZeroTier starts and connects on reboot

```bash
# Enable systemd service (usually auto-enabled on install)
sudo systemctl enable zerotier-one
sudo systemctl start zerotier-one

# Verify auto-join
sudo zerotier-cli listnetworks
```

## Configuration

### Environment Variables

```bash
# ZeroTier Central API token (get from my.zerotier.com → Account)
export ZT_API_TOKEN="your-api-token"
```

### Network Configuration (via API)

```bash
# Update network settings
curl -s -X POST "https://api.zerotier.com/api/v1/network/$NETWORK_ID" \
  -H "Authorization: token $ZT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "name": "production-mesh",
      "private": true,
      "ipAssignmentPools": [
        {"ipRangeStart": "10.42.0.1", "ipRangeEnd": "10.42.0.254"}
      ],
      "routes": [
        {"target": "10.42.0.0/24"}
      ],
      "v4AssignMode": {"zt": true}
    }
  }'
```

### DNS Configuration

```bash
# Set DNS for the network (members get these DNS servers)
curl -s -X POST "https://api.zerotier.com/api/v1/network/$NETWORK_ID" \
  -H "Authorization: token $ZT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "dns": {
        "domain": "zt.home",
        "servers": ["10.42.0.1"]
      }
    }
  }'
```

## Advanced Usage

### Flow Rules (Firewall)

```bash
# Set network flow rules
# Example: Allow only SSH and HTTP between members
curl -s -X POST "https://api.zerotier.com/api/v1/network/$NETWORK_ID" \
  -H "Authorization: token $ZT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rulesSource": "accept ipprotocol tcp and dport 22;\naccept ipprotocol tcp and dport 80;\naccept ipprotocol tcp and dport 443;\ndrop;"
  }'
```

### Bridge Mode (Route Traffic Between Networks)

```bash
# On the bridge node:
sudo sysctl -w net.ipv4.ip_forward=1

# Allow bridge in ZeroTier
curl -s -X POST "https://api.zerotier.com/api/v1/network/$NETWORK_ID/member/$BRIDGE_NODE_ID" \
  -H "Authorization: token $ZT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"config": {"activeBridge": true}}'

# Add route for remote subnet
curl -s -X POST "https://api.zerotier.com/api/v1/network/$NETWORK_ID" \
  -H "Authorization: token $ZT_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"config": {"routes": [{"target": "10.42.0.0/24"}, {"target": "192.168.1.0/24", "via": "10.42.0.1"}]}}'
```

### Run as OpenClaw Cron (Periodic Health Check)

```bash
# Add to OpenClaw cron: check ZeroTier health every 30 min
# The manage.sh script outputs alerts for:
# - Offline members that were previously online
# - Relayed connections (NAT traversal issues)
# - Unauthorized pending members
bash scripts/manage.sh health-check <network-id>
```

## Troubleshooting

### Issue: "zerotier-cli: command not found"

**Fix:**
```bash
# Reinstall
curl -s https://install.zerotier.com | sudo bash
# Or check PATH
ls /usr/sbin/zerotier-cli /opt/zerotier/bin/zerotier-cli 2>/dev/null
```

### Issue: Node shows OFFLINE

**Check:**
1. Service running: `sudo systemctl status zerotier-one`
2. Network joined: `sudo zerotier-cli listnetworks`
3. Firewall: ZeroTier uses UDP port 9993 — ensure it's open
4. Restart: `sudo systemctl restart zerotier-one`

### Issue: Connection relayed (slow)

**Fix:**
```bash
# Check peer connection type
sudo zerotier-cli peers
# If RELAY: UDP port 9993 is blocked
# Open it: sudo ufw allow 9993/udp
# Or: sudo iptables -A INPUT -p udp --dport 9993 -j ACCEPT
```

### Issue: Can't ping other members

**Check:**
1. Member authorized: `bash scripts/manage.sh members <network-id>`
2. IP assigned: `sudo zerotier-cli listnetworks`
3. Both nodes online: Check ZeroTier Central dashboard
4. OS firewall: May block ZeroTier interface (zt*)

## Dependencies

- `curl` (API calls)
- `jq` (JSON parsing)
- `zerotier-one` (installed by scripts/install.sh)
- Optional: `systemctl` (service management on Linux)

## Key Principles

1. **Private by default** — Networks are private; members must be authorized
2. **Peer-to-peer** — Direct encrypted connections, no central server routing traffic
3. **Zero config** — No port forwarding, no firewall rules, no DNS setup needed
4. **Cross-platform** — Linux, macOS, Windows, Android, iOS, FreeBSD
5. **Free tier** — Up to 25 devices per network at no cost
