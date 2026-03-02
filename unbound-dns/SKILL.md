---
name: unbound-dns
description: >-
  Install and manage a local recursive DNS resolver for privacy, speed, and ad-blocking.
categories: [security, home]
dependencies: [bash, curl, unbound]
---

# Unbound DNS Resolver

## What This Does

Installs and configures [Unbound](https://nlnetlabs.nl/projects/unbound/about/) as a local recursive DNS resolver. Instead of sending every DNS query to Google or Cloudflare, your machine resolves domains itself by talking directly to authoritative nameservers. This gives you **full DNS privacy**, **faster cached lookups**, and optional **ad-blocking** via blocklists.

**Example:** "Install Unbound, configure DNSSEC validation, add ad-blocking, and verify it's working — all in 5 minutes."

## Quick Start (5 minutes)

### 1. Install Unbound

```bash
bash scripts/install.sh
```

This detects your OS (Ubuntu/Debian, RHEL/Fedora, Arch, Alpine, macOS) and installs Unbound + dependencies.

### 2. Configure & Start

```bash
bash scripts/configure.sh
```

This writes an optimized `unbound.conf`, fetches root hints, enables DNSSEC, and starts the service.

### 3. Verify It Works

```bash
bash scripts/verify.sh
```

**Output:**
```
[✓] Unbound is running (PID 12345)
[✓] DNS resolution working: example.com → 93.184.216.34 (12ms)
[✓] DNSSEC validation: PASS (sigok.verteiltesysteme.net)
[✓] Recursive resolution: PASS (not forwarding to upstream)
[✓] Cache hit speed: 0ms (second query)
```

## Core Workflows

### Workflow 1: Privacy-First DNS (Default)

Full recursive resolution — no third-party DNS provider sees your queries.

```bash
bash scripts/configure.sh --mode recursive
```

Your machine queries root servers → TLD servers → authoritative servers directly.

### Workflow 2: Performance Mode (Forward + Cache)

Forward to a fast upstream (Cloudflare/Quad9) but cache aggressively locally.

```bash
bash scripts/configure.sh --mode forward --upstream 1.1.1.1 9.9.9.9
```

Best for: fast lookups when you trust an upstream but want local caching.

### Workflow 3: Ad-Blocking DNS

Block ads and trackers at the DNS level using community blocklists.

```bash
bash scripts/adblock.sh --enable
```

This fetches Steven Black's unified hosts list and converts it to Unbound local-zone blocks. Updates automatically via cron.

```
[✓] Downloaded blocklist: 85,000 domains
[✓] Converted to Unbound format: /etc/unbound/blocklist.conf
[✓] Cron job added: daily update at 4:00 AM
[✓] Unbound reloaded
```

To disable:
```bash
bash scripts/adblock.sh --disable
```

### Workflow 4: DNS-over-TLS (DoT)

Encrypt DNS queries to upstream resolvers.

```bash
bash scripts/configure.sh --mode forward --dot --upstream 1.1.1.1@853 9.9.9.9@853
```

### Workflow 5: Monitor & Stats

Check resolver performance and cache statistics.

```bash
bash scripts/stats.sh
```

**Output:**
```
Unbound Statistics (last 24h):
  Total queries:     12,847
  Cache hits:        9,231 (71.8%)
  Cache misses:      3,616 (28.2%)
  Avg response time: 2.3ms (cached) / 45ms (recursive)
  DNSSEC validated:  11,502 (89.5%)
  Blocked (adblock): 1,847 (14.4%)
  Uptime:            3d 14h 22m
```

## Configuration

### Environment Variables

```bash
# Override defaults
export UNBOUND_LISTEN="127.0.0.1"       # Listen address (default: localhost)
export UNBOUND_PORT="53"                 # Listen port
export UNBOUND_CACHE_SIZE="256m"         # Cache size (default: 256MB)
export UNBOUND_NUM_THREADS="2"           # Worker threads (default: auto-detect)
export UNBOUND_VERBOSITY="1"             # Log verbosity (0-5)
```

### Config File

The main config lives at `/etc/unbound/unbound.conf`. The configure script generates an optimized version, but you can edit it directly:

```yaml
# Key settings in unbound.conf
server:
    interface: 127.0.0.1
    port: 53
    do-ip6: no
    
    # Performance
    num-threads: 2
    msg-cache-size: 128m
    rrset-cache-size: 256m
    cache-min-ttl: 300
    cache-max-ttl: 86400
    prefetch: yes
    prefetch-key: yes
    
    # Security
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: yes
    
    # Ad-blocking (if enabled)
    include: /etc/unbound/blocklist.conf
```

## Advanced Usage

### Use as Network-Wide DNS

Serve DNS for your entire LAN (e.g., from a Raspberry Pi or home server):

```bash
bash scripts/configure.sh --mode recursive --listen 0.0.0.0 --access-control "192.168.1.0/24 allow"
```

Then point your router's DHCP DNS setting to this machine's IP.

### Custom Local Domains

Add local DNS entries for homelab services:

```bash
bash scripts/local-zone.sh add myserver.home 192.168.1.100
bash scripts/local-zone.sh add nas.home 192.168.1.50
bash scripts/local-zone.sh list
bash scripts/local-zone.sh remove myserver.home
```

### Flush Cache

```bash
bash scripts/cache.sh flush
bash scripts/cache.sh flush example.com   # Flush specific domain
bash scripts/cache.sh dump                 # Dump cache contents
```

### Health Check (for cron)

```bash
# Add to crontab — alerts if Unbound is down
*/5 * * * * bash /path/to/scripts/healthcheck.sh || echo "Unbound DOWN" | mail -s "DNS Alert" admin@example.com
```

## Troubleshooting

### Issue: "port 53 already in use"

Another DNS service (systemd-resolved, dnsmasq) is using port 53.

**Fix:**
```bash
# Disable systemd-resolved (Ubuntu)
sudo systemctl disable --now systemd-resolved
sudo rm /etc/resolv.conf
echo "nameserver 127.0.0.1" | sudo tee /etc/resolv.conf

# Or run Unbound on a different port
bash scripts/configure.sh --port 5353
```

### Issue: "DNSSEC validation failed"

System clock may be wrong (DNSSEC requires accurate time).

**Fix:**
```bash
sudo timedatectl set-ntp true
sudo systemctl restart unbound
```

### Issue: Slow first queries

Normal — recursive resolution requires multiple round-trips. Subsequent queries are cached (sub-millisecond). Enable prefetching for popular domains:

```bash
# Already enabled by default in our config
# prefetch: yes
# prefetch-key: yes
```

### Issue: Unbound won't start after config edit

**Fix:**
```bash
# Check config syntax
unbound-checkconf /etc/unbound/unbound.conf

# Check logs
sudo journalctl -u unbound --since "5 minutes ago"
```

## Uninstall

```bash
bash scripts/uninstall.sh
```

Removes Unbound, restores original DNS settings, removes cron jobs and blocklists.

## Dependencies

- `bash` (4.0+)
- `curl` or `wget` (for downloading root hints + blocklists)
- `unbound` (installed by install.sh)
- `openssl` (for DNS-over-TLS)
- Root/sudo access (DNS services require port 53)
