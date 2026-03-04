---
name: openvpn-manager
description: >-
  Install, configure, and manage an OpenVPN server with automated client certificate generation and user management.
categories: [security, automation]
dependencies: [bash, curl, openssl]
---

# OpenVPN Manager

## What This Does

Deploy a full OpenVPN server in minutes. Generates PKI infrastructure, creates client certificates, manages users, and produces ready-to-use `.ovpn` config files. No manual certificate wrangling — everything is automated.

**Example:** "Set up OpenVPN on my VPS, create configs for 5 team members, revoke access for someone who left."

## Quick Start (10 minutes)

### 1. Install OpenVPN Server

```bash
# Installs OpenVPN + Easy-RSA, generates PKI, configures server
sudo bash scripts/install.sh
```

This will:
- Install OpenVPN and Easy-RSA
- Generate Certificate Authority (CA)
- Create server certificate and DH parameters
- Configure firewall rules (iptables/ufw)
- Enable IP forwarding
- Start the OpenVPN service

### 2. Create Your First Client

```bash
# Generate a client config file (.ovpn)
sudo bash scripts/client.sh add john

# Output: /etc/openvpn/clients/john.ovpn
# Transfer this file to the client device
```

### 3. Connect

Transfer the `.ovpn` file to your device and import it into any OpenVPN client:
- **Linux:** `sudo openvpn --config john.ovpn`
- **macOS:** Tunnelblick or OpenVPN Connect
- **Windows:** OpenVPN GUI
- **iOS/Android:** OpenVPN Connect app

## Core Workflows

### Workflow 1: Add a New User

```bash
sudo bash scripts/client.sh add alice

# With custom options:
sudo bash scripts/client.sh add alice --dns 1.1.1.1 --routes "10.0.0.0/24"
```

**Output:**
```
✅ Client certificate generated: alice
📄 Config file: /etc/openvpn/clients/alice.ovpn
🔑 Valid until: 2028-03-04
```

### Workflow 2: Revoke a User

```bash
sudo bash scripts/client.sh revoke alice

# Immediately disconnects and prevents future connections
```

**Output:**
```
🚫 Certificate revoked: alice
📋 CRL updated
♻️  OpenVPN service reloaded
```

### Workflow 3: List All Users

```bash
sudo bash scripts/client.sh list
```

**Output:**
```
ACTIVE CLIENTS:
  john        Created: 2026-03-04  Expires: 2028-03-04
  bob         Created: 2026-03-01  Expires: 2028-03-01

REVOKED CLIENTS:
  alice       Revoked: 2026-03-04
```

### Workflow 4: Check Server Status

```bash
sudo bash scripts/status.sh
```

**Output:**
```
OpenVPN Server Status
═══════════════════════
Service:     ✅ Running (pid 1234)
Protocol:    UDP 1194
Subnet:      10.8.0.0/24
DNS:         1.1.1.1, 1.0.0.1

Connected Clients (2):
  john       10.8.0.2    Connected: 2h 15m    Bytes: ↑12MB ↓45MB
  bob        10.8.0.3    Connected: 0h 42m    Bytes: ↑3MB ↓8MB

Certificates:
  Active: 3    Revoked: 1    Expiring <30d: 0
```

### Workflow 5: Rotate Server Certificate

```bash
# Regenerate server cert (e.g., before expiry)
sudo bash scripts/rotate.sh server
```

### Workflow 6: Backup PKI

```bash
# Backup all certificates, keys, and configs
sudo bash scripts/backup.sh /path/to/backup/

# Restore from backup
sudo bash scripts/backup.sh --restore /path/to/backup/
```

## Configuration

### Server Config (`/etc/openvpn/server.conf`)

The installer generates a secure default config. Key settings:

```
port 1194
proto udp
dev tun
topology subnet
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"
keepalive 10 120
cipher AES-256-GCM
auth SHA256
tls-crypt /etc/openvpn/ta.key
persist-key
persist-tun
user nobody
group nogroup
verb 3
```

### Customization

Edit `/etc/openvpn/server.conf` for:

```bash
# Change port
port 443

# Use TCP (for restrictive networks)
proto tcp

# Change subnet
server 172.16.0.0 255.255.255.0

# Push routes to clients (access LAN)
push "route 192.168.1.0 255.255.255.0"

# Split tunnel (don't route all traffic)
# Remove: push "redirect-gateway def1 bypass-dhcp"
```

After changes: `sudo systemctl restart openvpn@server`

### Environment Variables

```bash
# Optional: Override defaults during install
export OVPN_PORT=1194          # Server port
export OVPN_PROTO=udp          # udp or tcp
export OVPN_SUBNET="10.8.0.0"  # VPN subnet
export OVPN_DNS="1.1.1.1"      # Client DNS
export OVPN_CERT_DAYS=730      # Certificate validity (days)
```

## Advanced Usage

### Split Tunnel (Route Only Specific Traffic)

```bash
# During install, or edit server.conf:
sudo bash scripts/install.sh --no-redirect

# Then push specific routes:
# push "route 10.0.0.0 255.0.0.0"
# push "route 192.168.0.0 255.255.0.0"
```

### Multi-Server Setup

```bash
# Second server on different port/protocol
sudo bash scripts/install.sh --name server2 --port 443 --proto tcp
```

### Automated Client Provisioning

```bash
# Batch create clients
for user in alice bob carol dave; do
  sudo bash scripts/client.sh add "$user"
done

# Email configs (requires mail CLI)
for user in alice bob carol dave; do
  mail -a "/etc/openvpn/clients/${user}.ovpn" \
    -s "Your VPN Config" "${user}@company.com" <<< "Attached is your VPN config."
done
```

### Monitor with Cron

```bash
# Add to crontab: alert if server goes down
*/5 * * * * bash /etc/openvpn/scripts/status.sh --check || \
  curl -s "https://ntfy.sh/your-topic" -d "OpenVPN server is DOWN"
```

### Certificate Expiry Monitoring

```bash
# Check for certs expiring in <30 days
sudo bash scripts/client.sh expiring 30
```

**Output:**
```
⚠️  Certificates expiring within 30 days:
  bob         Expires: 2026-04-01 (28 days)

Renew with: sudo bash scripts/client.sh renew bob
```

## Troubleshooting

### Issue: "TLS handshake failed"

**Cause:** Clock skew between server and client, or mismatched certificates.

**Fix:**
```bash
# Check server time
date
# Sync time
sudo timedatectl set-ntp true

# Regenerate client config if needed
sudo bash scripts/client.sh add username --force
```

### Issue: Connected but no internet

**Fix:**
```bash
# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should be 1

# Check NAT rules
sudo iptables -t nat -L POSTROUTING -v

# Re-apply firewall rules
sudo bash scripts/install.sh --fix-firewall
```

### Issue: "Cannot allocate TUN/TAP dev"

**Fix:**
```bash
# On VPS, check TUN device exists
ls -la /dev/net/tun

# If missing, create it
sudo mkdir -p /dev/net
sudo mknod /dev/net/tun c 10 200
sudo chmod 600 /dev/net/tun
```

### Issue: Port blocked by ISP

**Fix:** Switch to TCP 443 (looks like HTTPS traffic):
```bash
# Edit /etc/openvpn/server.conf
# proto tcp
# port 443
sudo systemctl restart openvpn@server

# Regenerate all client configs
sudo bash scripts/client.sh regenerate-all
```

## Security Best Practices

1. **Use TLS-Crypt** — Enabled by default (ta.key), adds HMAC authentication
2. **AES-256-GCM** — Strong cipher, hardware-accelerated on most CPUs
3. **Revoke promptly** — When someone leaves, revoke immediately
4. **Monitor connections** — Use `status.sh` to watch for unauthorized access
5. **Backup PKI** — Losing your CA means regenerating ALL certificates
6. **Firewall** — Only expose the VPN port, nothing else

## Dependencies

- `bash` (4.0+)
- `openvpn` (2.5+) — installed by `install.sh`
- `easy-rsa` (3.0+) — installed by `install.sh`
- `openssl` — for certificate operations
- `iptables` or `ufw` — for firewall rules
- Root/sudo access required

## Supported Platforms

- Ubuntu 20.04+ / Debian 11+
- CentOS 8+ / Rocky Linux 8+ / AlmaLinux 8+
- Amazon Linux 2
- Arch Linux
