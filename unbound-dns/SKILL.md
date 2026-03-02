---
name: unbound-dns
description: >-
  Install and manage Unbound as a local recursive DNS resolver for privacy, speed, and ad-blocking.
categories: [security, home]
dependencies: [bash, curl, unbound]
---

# Unbound DNS Resolver

## What This Does

Installs and configures [Unbound](https://nlnetlabs.nl/projects/unbound/about/) as a local recursive DNS resolver. Instead of sending every DNS query to Google or Cloudflare, your machine resolves domains itself — directly from root servers. Adds DNSSEC validation, optional ad-blocking via blocklists, and query logging.

**Why:** Full DNS privacy (no third-party sees your queries), faster resolution after cache warm-up, DNSSEC validation out of the box, and optional ad/tracker blocking without Pi-hole.

## Quick Start (5 minutes)

### 1. Install Unbound

```bash
bash scripts/install.sh
```

This detects your OS (Debian/Ubuntu, RHEL/Fedora, Alpine, macOS) and installs Unbound + downloads root hints.

### 2. Apply Base Configuration

```bash
sudo bash scripts/configure.sh --mode recursive
```

Modes:
- `recursive` — Full recursive resolver (maximum privacy, queries root servers directly)
- `forwarding` — Forward to upstream (Cloudflare/Quad9) with caching + DNSSEC
- `adblock` — Recursive + ad/tracker blocking via blocklists

### 3. Verify It Works

```bash
bash scripts/status.sh
```

Output:
```
✅ Unbound is running (PID 1234)
✅ DNSSEC validation: active
✅ Listening on: 127.0.0.1:53
✅ Cache entries: 1,847
✅ Queries today: 3,291
⏱️ Avg response: 12ms (cached), 85ms (recursive)
```

### 4. Set as System DNS

```bash
sudo bash scripts/set-system-dns.sh
```

Points your system's `/etc/resolv.conf` to `127.0.0.1`. Creates backup of original config.

## Core Workflows

### Workflow 1: Full Recursive Setup (Maximum Privacy)

```bash
# Install + configure + set as system DNS
bash scripts/install.sh
sudo bash scripts/configure.sh --mode recursive
sudo bash scripts/set-system-dns.sh

# Test DNSSEC
bash scripts/test-dnssec.sh
# ✅ sigok.verteiltesysteme.net — DNSSEC valid
# ❌ sigfail.verteiltesysteme.net — DNSSEC correctly rejected
```

### Workflow 2: Forwarding Mode (Speed + Privacy Balance)

```bash
# Forward to Quad9 (malware blocking) with local cache
sudo bash scripts/configure.sh --mode forwarding --upstream quad9

# Options: cloudflare, quad9, google, custom
# Custom:
sudo bash scripts/configure.sh --mode forwarding --upstream custom --dns "9.9.9.9 149.112.112.112"
```

### Workflow 3: Ad-Blocking DNS

```bash
# Recursive + StevenBlack unified hosts blocklist
sudo bash scripts/configure.sh --mode adblock

# Update blocklists (run weekly via cron)
sudo bash scripts/update-blocklist.sh

# Check blocked domains count
bash scripts/status.sh --blocklist
# 🚫 Blocked domains: 142,857
# 📅 Last updated: 2026-03-02
```

### Workflow 4: Query Logging & Analysis

```bash
# Enable query logging
sudo bash scripts/configure.sh --logging on

# View recent queries
bash scripts/query-log.sh --last 50

# Top queried domains
bash scripts/query-log.sh --top 20

# Find suspicious queries
bash scripts/query-log.sh --suspicious
```

### Workflow 5: Cache Management

```bash
# View cache stats
bash scripts/cache.sh --stats

# Dump cache contents
bash scripts/cache.sh --dump

# Flush entire cache
sudo bash scripts/cache.sh --flush

# Flush specific domain
sudo bash scripts/cache.sh --flush example.com
```

## Configuration

### Config File Location

- Linux: `/etc/unbound/unbound.conf`
- macOS: `/opt/homebrew/etc/unbound/unbound.conf` (or `/usr/local/etc/unbound/`)

### Key Settings

```yaml
# Performance tuning (scripts/configure.sh handles these)
num-threads: 4          # Match CPU cores
msg-cache-size: 64m     # Message cache
rrset-cache-size: 128m  # RRset cache
cache-min-ttl: 300      # Minimum cache TTL (seconds)
cache-max-ttl: 86400    # Maximum cache TTL (1 day)
prefetch: yes           # Prefetch expiring entries

# Privacy
hide-identity: yes
hide-version: yes
qname-minimisation: yes  # RFC 7816 — minimize info sent to auth servers

# Security
harden-glue: yes
harden-dnssec-stripped: yes
use-caps-for-id: yes     # 0x20 encoding for spoofing protection
```

### Access Control

```bash
# Allow local network to query (default: localhost only)
sudo bash scripts/configure.sh --allow-network 192.168.1.0/24

# Serve as DNS for entire LAN (e.g., set in router DHCP)
sudo bash scripts/configure.sh --interface 0.0.0.0 --allow-network 192.168.0.0/16
```

## Advanced Usage

### Run as Cron for Blocklist Updates

```bash
# Update blocklists weekly (Sunday 3am)
echo "0 3 * * 0 root /path/to/scripts/update-blocklist.sh >> /var/log/unbound-blocklist.log 2>&1" | sudo tee /etc/cron.d/unbound-blocklist
```

### Monitor with OpenClaw Cron

```bash
# Check Unbound health every 30 min
bash scripts/status.sh --json
# Returns JSON for easy parsing:
# {"running":true,"pid":1234,"dnssec":true,"cache_entries":1847,"queries_today":3291}
```

### Custom Local Zones

```bash
# Add local DNS entries (e.g., homelab services)
sudo bash scripts/local-zone.sh add myserver.home 192.168.1.100
sudo bash scripts/local-zone.sh add nas.home 192.168.1.50

# List local zones
bash scripts/local-zone.sh list

# Remove
sudo bash scripts/local-zone.sh remove myserver.home
```

### DNSSEC Trust Anchor Updates

```bash
# Auto-update root trust anchor
sudo bash scripts/update-root-hints.sh
```

## Troubleshooting

### Issue: "port 53 already in use"

**Fix:** Another DNS resolver (systemd-resolved, dnsmasq) is running.
```bash
# Check what's using port 53
sudo ss -tlnp | grep :53

# Disable systemd-resolved (Ubuntu)
sudo systemctl disable --now systemd-resolved
sudo bash scripts/set-system-dns.sh
```

### Issue: Slow first queries

**Expected.** Recursive resolution queries root → TLD → authoritative servers. After first lookup, results are cached. Use `prefetch: yes` to keep popular entries warm.

### Issue: DNSSEC validation failures

```bash
# Check if it's the domain or your config
bash scripts/test-dnssec.sh --domain problematic-domain.com

# Temporarily disable DNSSEC for debugging
sudo bash scripts/configure.sh --dnssec off
```

### Issue: Can't resolve after reboot

```bash
# Check if Unbound started
sudo systemctl status unbound

# Check if resolv.conf was overwritten
cat /etc/resolv.conf
# Should show: nameserver 127.0.0.1

# Re-apply if needed
sudo bash scripts/set-system-dns.sh
```

## Uninstall

```bash
# Restore original DNS and stop Unbound
sudo bash scripts/uninstall.sh
```

## Dependencies

- `bash` (4.0+)
- `curl` (for downloading root hints and blocklists)
- `unbound` (installed by install.sh)
- Root/sudo access (DNS binds to port 53)
