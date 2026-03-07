---
name: dnsmasq-manager
description: >-
  Install and manage dnsmasq as a local DNS forwarder, ad blocker, and DHCP server with one command.
categories: [home, automation]
dependencies: [bash, dnsmasq, curl]
---

# Dnsmasq Manager

## What This Does

Installs and configures **dnsmasq** — a lightweight DNS forwarder, DHCP server, and ad blocker for your local network. Perfect for home labs, development environments, and network-level ad blocking without the overhead of Pi-hole.

**Example:** "Set up local DNS with ad blocking, custom domain aliases, and DHCP in under 5 minutes."

## Quick Start (5 minutes)

### 1. Install Dnsmasq

```bash
bash scripts/install.sh
```

This detects your OS (Debian/Ubuntu, RHEL/Fedora, Arch, Alpine, macOS) and installs dnsmasq.

### 2. Configure Local DNS

```bash
# Set up as local DNS forwarder with Cloudflare + Google upstream
bash scripts/configure.sh --mode dns --upstream "1.1.1.1,8.8.8.8"
```

### 3. Add Custom Domains

```bash
# Point local domains to IPs (great for dev/homelab)
bash scripts/manage.sh add-host myapp.local 192.168.1.50
bash scripts/manage.sh add-host api.local 192.168.1.51
bash scripts/manage.sh add-host nas.local 192.168.1.100
```

### 4. Enable Ad Blocking

```bash
# Download and apply ad-blocking hosts list
bash scripts/manage.sh enable-adblock
```

## Core Workflows

### Workflow 1: Local DNS Forwarder

**Use case:** Speed up DNS resolution, use custom upstream servers

```bash
bash scripts/configure.sh --mode dns \
  --upstream "1.1.1.1,1.0.0.1" \
  --cache-size 10000 \
  --log-queries

# Verify
dig @127.0.0.1 google.com
```

**Output:**
```
✅ Dnsmasq configured as DNS forwarder
   Upstream: 1.1.1.1, 1.0.0.1
   Cache: 10000 entries
   Logging: enabled → /var/log/dnsmasq.log
```

### Workflow 2: DHCP Server

**Use case:** Assign IPs to devices on your network

```bash
bash scripts/configure.sh --mode dhcp \
  --range "192.168.1.100,192.168.1.200,24h" \
  --gateway 192.168.1.1 \
  --dns-server 192.168.1.1

# Static leases
bash scripts/manage.sh add-lease "AA:BB:CC:DD:EE:FF" 192.168.1.50 "my-server"
bash scripts/manage.sh add-lease "11:22:33:44:55:66" 192.168.1.51 "my-nas"
```

### Workflow 3: Network-Level Ad Blocking

**Use case:** Block ads and trackers for all devices on the network

```bash
# Enable with default blocklist (StevenBlack unified hosts)
bash scripts/manage.sh enable-adblock

# Use custom blocklist URL
bash scripts/manage.sh enable-adblock --url "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

# Update blocklist (run periodically)
bash scripts/manage.sh update-adblock

# Check blocked domains count
bash scripts/manage.sh adblock-stats
```

**Output:**
```
📊 Ad Blocking Stats:
   Blocked domains: 85,412
   Last updated: 2026-03-07 12:00:00
   Source: StevenBlack unified hosts
```

### Workflow 4: Split DNS / Custom Domains

**Use case:** Route specific domains to internal servers

```bash
# Add custom host entries
bash scripts/manage.sh add-host gitlab.home 192.168.1.10
bash scripts/manage.sh add-host wiki.home 192.168.1.11
bash scripts/manage.sh add-host plex.home 192.168.1.12

# Add wildcard domain (all *.dev.local → one IP)
bash scripts/manage.sh add-wildcard dev.local 192.168.1.20

# List all custom entries
bash scripts/manage.sh list-hosts

# Remove an entry
bash scripts/manage.sh remove-host gitlab.home
```

### Workflow 5: DNS Query Logging & Analytics

**Use case:** See what's being queried on your network

```bash
# Enable query logging
bash scripts/manage.sh enable-logging

# View recent queries
bash scripts/manage.sh query-log --last 50

# Top queried domains
bash scripts/manage.sh query-log --top 20

# Most blocked domains
bash scripts/manage.sh query-log --blocked --top 20
```

## Configuration

### Main Config File

After running `configure.sh`, the config lives at `/etc/dnsmasq.d/openclaw.conf`:

```ini
# DNS settings
server=1.1.1.1
server=1.0.0.1
cache-size=10000
no-resolv

# DHCP settings (if enabled)
dhcp-range=192.168.1.100,192.168.1.200,24h
dhcp-option=option:router,192.168.1.1
dhcp-option=option:dns-server,192.168.1.1

# Logging
log-queries
log-facility=/var/log/dnsmasq.log

# Ad blocking
addn-hosts=/etc/dnsmasq.d/adblock.hosts

# Custom hosts
addn-hosts=/etc/dnsmasq.d/custom.hosts
```

### Environment Variables

```bash
# Override defaults
export DNSMASQ_UPSTREAM="1.1.1.1,8.8.8.8"
export DNSMASQ_CACHE_SIZE=10000
export DNSMASQ_LOG_DIR="/var/log"
export DNSMASQ_ADBLOCK_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
```

## Advanced Usage

### Run as Cron Job (Auto-Update Blocklist)

```bash
# Update ad blocklist daily at 3am
echo "0 3 * * * bash /path/to/scripts/manage.sh update-adblock" | crontab -
```

### Conditional Forwarding

```bash
# Forward specific domains to specific DNS servers
bash scripts/manage.sh add-forward "corp.example.com" "10.0.0.1"
bash scripts/manage.sh add-forward "vpn.internal" "10.10.0.1"
```

### TFTP/PXE Boot (Network Boot)

```bash
bash scripts/configure.sh --enable-tftp \
  --tftp-root /srv/tftp \
  --pxe-file pxelinux.0
```

### DNS-over-HTTPS Upstream

```bash
# Use cloudflared as upstream DoH proxy
bash scripts/configure.sh --mode dns --upstream "127.0.0.1#5053" --doh
```

## Troubleshooting

### Issue: "port 53 already in use"

**Fix:** Another DNS service (systemd-resolved) is using port 53.

```bash
# Disable systemd-resolved (Ubuntu/Debian)
bash scripts/install.sh --disable-resolved
```

### Issue: DHCP conflicts with existing server

**Fix:** Only run DHCP if no other DHCP server exists on the network.

```bash
# Check for existing DHCP servers
bash scripts/manage.sh check-dhcp
```

### Issue: Ad blocking too aggressive

```bash
# Whitelist a domain
bash scripts/manage.sh whitelist "example.com"

# View whitelist
bash scripts/manage.sh list-whitelist
```

### Issue: DNS not resolving after config change

```bash
# Restart dnsmasq
bash scripts/manage.sh restart

# Test resolution
bash scripts/manage.sh test-dns google.com
```

## Service Management

```bash
bash scripts/manage.sh status     # Check if running
bash scripts/manage.sh start      # Start dnsmasq
bash scripts/manage.sh stop       # Stop dnsmasq
bash scripts/manage.sh restart    # Restart dnsmasq
bash scripts/manage.sh backup     # Backup config
bash scripts/manage.sh restore    # Restore from backup
bash scripts/manage.sh uninstall  # Remove dnsmasq and configs
```

## Dependencies

- `bash` (4.0+)
- `dnsmasq` (installed by scripts/install.sh)
- `curl` (for downloading blocklists)
- `dig` or `nslookup` (for testing — usually pre-installed)
- Root/sudo access (for service management and port 53)
