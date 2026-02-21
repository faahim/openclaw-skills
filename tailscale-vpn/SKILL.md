---
name: tailscale-vpn
description: >-
  Install, configure, and manage Tailscale VPN — connect machines to a private mesh network with zero firewall config.
categories: [security, automation]
dependencies: [curl, tailscale]
---

# Tailscale VPN Manager

## What This Does

Installs and manages Tailscale, a zero-config mesh VPN that creates a private network between your machines. No port forwarding, no firewall rules, no manual WireGuard config — just `tailscale up` and your devices are connected.

**Example:** "Install Tailscale on this server, connect it to my tailnet, enable SSH access, and set up an exit node."

## Quick Start (3 minutes)

### 1. Install Tailscale

```bash
bash scripts/install.sh
```

This auto-detects your OS (Debian/Ubuntu, RHEL/Fedora, Arch, Alpine, macOS) and installs Tailscale.

### 2. Connect to Your Tailnet

```bash
# Start Tailscale and authenticate
sudo tailscale up

# Follow the URL to authenticate in your browser
# Once authenticated, check status:
tailscale status
```

### 3. Verify Connection

```bash
# Show your Tailscale IP
tailscale ip -4

# Ping another device on your tailnet
tailscale ping <device-name>

# List all devices
tailscale status
```

## Core Workflows

### Workflow 1: Connect a New Machine

**Use case:** Add a server/VM to your private network

```bash
# Install + connect
bash scripts/install.sh
sudo tailscale up --hostname my-server

# Verify
tailscale status
```

**Output:**
```
100.64.0.3  my-server        user@example.com linux   active; direct
100.64.0.1  my-laptop        user@example.com macOS   active; direct
100.64.0.2  my-phone         user@example.com iOS     active; relay
```

### Workflow 2: Enable Tailscale SSH

**Use case:** SSH into machines without managing keys or opening port 22

```bash
# Enable Tailscale SSH on the target machine
sudo tailscale up --ssh

# From any other tailnet device:
ssh user@my-server  # Uses Tailscale IP automatically
# Or use the MagicDNS name:
ssh user@my-server.tail1234.ts.net
```

**No SSH keys needed** — Tailscale handles authentication via your identity provider.

### Workflow 3: Set Up an Exit Node

**Use case:** Route all internet traffic through a specific machine (like a VPN)

```bash
# On the exit node machine:
sudo tailscale up --advertise-exit-node

# On the client machine:
sudo tailscale up --exit-node=<exit-node-ip>

# Verify traffic is routed:
curl ifconfig.me  # Should show exit node's public IP
```

### Workflow 4: Share a Service (Funnel/Serve)

**Use case:** Expose a local service to the internet or your tailnet

```bash
# Expose port 3000 to your tailnet only:
tailscale serve 3000

# Expose port 8080 to the PUBLIC internet via Tailscale Funnel:
tailscale funnel 8080

# Check what's being served:
tailscale serve status
```

### Workflow 5: Subnet Router

**Use case:** Access an entire LAN/subnet through one Tailscale node

```bash
# Advertise local subnet
sudo tailscale up --advertise-routes=192.168.1.0/24

# Enable IP forwarding (Linux)
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# Approve the route in Tailscale admin console or via CLI
```

### Workflow 6: Status & Diagnostics

**Use case:** Check network health and debug connectivity

```bash
# Full diagnostic report
bash scripts/diagnostics.sh

# Quick status
tailscale status

# Debug connectivity to a specific peer
tailscale ping --verbose <device-name>

# Check if using direct connection or DERP relay
tailscale netcheck
```

### Workflow 7: ACL & Access Control

**Use case:** Manage who can access what on your tailnet

```bash
# View current ACL policy (requires API key)
bash scripts/acl.sh view

# Apply ACL policy from file
bash scripts/acl.sh apply acl-policy.json
```

**Example ACL policy:**
```json
{
  "acls": [
    {"action": "accept", "src": ["group:admin"], "dst": ["*:*"]},
    {"action": "accept", "src": ["group:dev"], "dst": ["tag:server:22,80,443"]},
    {"action": "accept", "src": ["autogroup:member"], "dst": ["autogroup:self:*"]}
  ],
  "groups": {
    "group:admin": ["user@example.com"],
    "group:dev": ["dev1@example.com", "dev2@example.com"]
  },
  "tagOwners": {
    "tag:server": ["group:admin"]
  }
}
```

## Configuration

### Environment Variables

```bash
# Tailscale API key (for ACL management, device listing via API)
export TAILSCALE_API_KEY="tskey-api-xxxx"

# Tailnet name (usually your email domain or tailnet ID)
export TAILSCALE_TAILNET="example.com"
```

### Auth Keys (for unattended installs)

```bash
# Generate a pre-auth key in Tailscale Admin Console
# Use it for automated server provisioning:
sudo tailscale up --authkey=tskey-auth-xxxx --hostname=auto-server-01
```

### Common Flags

```bash
# Advertise as exit node + enable SSH + set hostname
sudo tailscale up \
  --advertise-exit-node \
  --ssh \
  --hostname=my-server \
  --accept-routes \
  --accept-dns
```

## Advanced Usage

### Automated Fleet Provisioning

```bash
# Provision multiple servers (uses auth key)
for host in server-{01..05}; do
  ssh root@$host "curl -fsSL https://tailscale.com/install.sh | sh && tailscale up --authkey=tskey-auth-xxxx --hostname=$host"
done
```

### MagicDNS

Tailscale automatically provides DNS names for all devices:

```bash
# Access devices by name instead of IP
ssh my-server.tail1234.ts.net
curl http://my-server:3000
ping my-laptop
```

### Tailscale as Docker Sidecar

```bash
# Run Tailscale in a Docker container
docker run -d \
  --name=tailscale \
  --hostname=docker-host \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -v /dev/net/tun:/dev/net/tun \
  -v tailscale-state:/var/lib/tailscale \
  -e TS_AUTHKEY=tskey-auth-xxxx \
  tailscale/tailscale
```

## Troubleshooting

### Issue: "tailscale up" hangs

**Fix:**
```bash
# Check if tailscaled is running
sudo systemctl status tailscaled

# If not running:
sudo systemctl start tailscaled
sudo systemctl enable tailscaled

# Then retry:
sudo tailscale up
```

### Issue: Can't reach other devices

**Fix:**
```bash
# Check connectivity
tailscale netcheck

# Check if firewall is blocking UDP 41641
sudo iptables -L -n | grep 41641

# Allow Tailscale traffic
sudo ufw allow in on tailscale0
```

### Issue: "Permission denied" for tailscale commands

**Fix:**
```bash
# Most tailscale commands need sudo
sudo tailscale up
sudo tailscale down

# Status doesn't need sudo
tailscale status
```

### Issue: Slow connection (using DERP relay)

**Fix:**
```bash
# Check connection type
tailscale ping --verbose <device>

# If showing "via DERP", check:
# 1. Both devices can reach UDP 41641
# 2. NAT type isn't symmetric on both sides
tailscale netcheck
```

## Key Principles

1. **Zero config** — Tailscale handles NAT traversal, key exchange, firewall rules
2. **WireGuard underneath** — Battle-tested encryption protocol
3. **Identity-based** — Access tied to user identity, not IP addresses
4. **MagicDNS** — Access devices by name, not IP
5. **No open ports** — Nothing exposed to the public internet unless you choose to

## Dependencies

- `curl` (for installation)
- `tailscale` (installed by scripts/install.sh)
- Linux kernel 4.1+ / macOS 10.15+ / Windows 10+
- Root/sudo access for installation and `tailscale up`
