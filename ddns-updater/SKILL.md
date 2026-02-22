---
name: ddns-updater
description: >-
  Automatically update DNS records when your public IP changes. Supports Cloudflare, DuckDNS, Namecheap, and generic webhook providers.
categories: [automation, dev-tools]
dependencies: [bash, curl, jq]
---

# DDNS Updater

## What This Does

Keep your DNS records in sync with your dynamic public IP — automatically. Perfect for self-hosted services, home labs, and remote access setups where your ISP changes your IP without warning.

**Example:** "Check IP every 5 minutes, update Cloudflare DNS if it changed, log all changes, alert via Telegram."

## Quick Start (3 minutes)

### 1. Install Dependencies

```bash
# These are pre-installed on most systems
which curl jq || sudo apt-get install -y curl jq

# Copy the script
cp scripts/ddns-updater.sh ~/.local/bin/ddns-updater
chmod +x ~/.local/bin/ddns-updater
```

### 2. Configure a Provider

```bash
# Copy config template
cp scripts/config-template.yaml ~/.config/ddns-updater/config.yaml

# Edit with your provider details (see Provider Setup below)
```

### 3. Run First Update

```bash
bash scripts/ddns-updater.sh --config ~/.config/ddns-updater/config.yaml

# Output:
# [2026-02-22 12:00:00] 🔍 Current IP: 203.0.113.42
# [2026-02-22 12:00:00] 📝 DNS record home.example.com points to 203.0.113.40
# [2026-02-22 12:00:01] ✅ Updated home.example.com → 203.0.113.42
```

## Provider Setup

### Cloudflare (Recommended)

```bash
# Set environment variables
export CF_API_TOKEN="your-cloudflare-api-token"
export CF_ZONE_ID="your-zone-id"

# Run for a specific record
bash scripts/ddns-updater.sh --provider cloudflare --domain home.example.com
```

**Getting your API token:**
1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Create token → "Edit zone DNS" template
3. Select your zone → Create Token

**Getting your Zone ID:**
1. Go to your domain's Overview page in Cloudflare
2. Zone ID is in the right sidebar under "API"

### DuckDNS (Free, No Domain Required)

```bash
export DUCKDNS_TOKEN="your-duckdns-token"

bash scripts/ddns-updater.sh --provider duckdns --domain myhost
# Updates myhost.duckdns.org
```

**Getting your token:**
1. Go to https://www.duckdns.org
2. Sign in → your token is displayed on the dashboard

### Namecheap

```bash
export NAMECHEAP_PASSWORD="your-ddns-password"

bash scripts/ddns-updater.sh --provider namecheap --domain home --zone example.com
```

**Enable DDNS:**
1. Namecheap Dashboard → Domain List → Manage → Advanced DNS
2. Enable "Dynamic DNS" → copy the password

### Generic Webhook

```bash
bash scripts/ddns-updater.sh --provider webhook \
  --webhook-url "https://your-dns-api.com/update?ip={IP}&host={DOMAIN}"
```

Placeholders `{IP}` and `{DOMAIN}` are replaced with actual values.

## Core Workflows

### Workflow 1: One-Shot Update

```bash
bash scripts/ddns-updater.sh --provider cloudflare --domain home.example.com
```

### Workflow 2: Continuous Monitoring (Daemon Mode)

```bash
bash scripts/ddns-updater.sh \
  --provider cloudflare \
  --domain home.example.com \
  --interval 300 \
  --daemon
# Checks every 5 minutes, updates only when IP changes
```

### Workflow 3: Cron Job (Recommended)

```bash
# Add to crontab — check every 5 minutes
(crontab -l 2>/dev/null; echo "*/5 * * * * bash /path/to/scripts/ddns-updater.sh --provider cloudflare --domain home.example.com --config /path/to/config.yaml >> /var/log/ddns-updater.log 2>&1") | crontab -
```

### Workflow 4: Multiple Domains

```yaml
# config.yaml
providers:
  - provider: cloudflare
    domains:
      - home.example.com
      - vpn.example.com
      - nas.example.com
    env:
      CF_API_TOKEN: "your-token"
      CF_ZONE_ID: "your-zone-id"

  - provider: duckdns
    domains:
      - myhost
    env:
      DUCKDNS_TOKEN: "your-token"
```

```bash
bash scripts/ddns-updater.sh --config config.yaml --all
```

### Workflow 5: With Telegram Alerts

```bash
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

bash scripts/ddns-updater.sh \
  --provider cloudflare \
  --domain home.example.com \
  --alert telegram
# Sends: "🔄 DDNS Updated: home.example.com → 203.0.113.42 (was 203.0.113.40)"
```

## Configuration

### Config File Format (YAML)

```yaml
# ~/.config/ddns-updater/config.yaml
ip_check_url: "https://api.ipify.org"  # or https://ifconfig.me, https://icanhazip.com
log_file: "/var/log/ddns-updater.log"
ip_cache_file: "/tmp/ddns-last-ip"

providers:
  - provider: cloudflare
    domains:
      - home.example.com
    env:
      CF_API_TOKEN: "your-api-token"
      CF_ZONE_ID: "your-zone-id"

alerts:
  telegram:
    bot_token: "your-bot-token"
    chat_id: "your-chat-id"
  webhook:
    url: "https://hooks.slack.com/services/..."
```

### Environment Variables

```bash
# IP detection (optional — defaults to api.ipify.org)
export DDNS_IP_CHECK_URL="https://api.ipify.org"

# Cloudflare
export CF_API_TOKEN="your-token"
export CF_ZONE_ID="your-zone-id"

# DuckDNS
export DUCKDNS_TOKEN="your-token"

# Namecheap
export NAMECHEAP_PASSWORD="your-ddns-password"

# Alerts
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

## Advanced Usage

### Force Update (Skip IP Change Check)

```bash
bash scripts/ddns-updater.sh --provider cloudflare --domain home.example.com --force
```

### IPv6 Support

```bash
bash scripts/ddns-updater.sh --provider cloudflare --domain home.example.com --ipv6
# Uses https://api6.ipify.org for IPv6 detection
```

### Dry Run (Preview Without Updating)

```bash
bash scripts/ddns-updater.sh --provider cloudflare --domain home.example.com --dry-run
# [2026-02-22 12:00:00] 🔍 Current IP: 203.0.113.42
# [2026-02-22 12:00:00] [DRY RUN] Would update home.example.com → 203.0.113.42
```

### Custom IP Source (Behind NAT/VPN)

```bash
# Use a specific interface
bash scripts/ddns-updater.sh --ip-source "curl -s https://api.ipify.org"

# Or provide IP directly
bash scripts/ddns-updater.sh --ip 203.0.113.42 --provider cloudflare --domain home.example.com
```

## Troubleshooting

### Issue: "Failed to detect public IP"

**Fix:** Try alternative IP check services:
```bash
curl -s https://api.ipify.org     # Default
curl -s https://ifconfig.me        # Alternative
curl -s https://icanhazip.com      # Alternative
curl -s https://ipinfo.io/ip       # Alternative
```

### Issue: Cloudflare "Authentication error"

**Check:**
1. Token is valid: `curl -s -H "Authorization: Bearer $CF_API_TOKEN" https://api.cloudflare.com/client/v4/user/tokens/verify | jq .`
2. Token has "Edit zone DNS" permission for your zone
3. Zone ID is correct

### Issue: Updates too frequent / API rate limits

**Fix:** Increase interval, or use IP caching:
```bash
# The script caches last known IP in /tmp/ddns-last-ip
# Only calls DNS API when IP actually changes
```

### Issue: "Record not found" on Cloudflare

**Fix:** Create the A record first in Cloudflare dashboard, then DDNS will update it.

## Key Principles

1. **Update only on change** — Caches last IP, skips API call if unchanged
2. **Multiple providers** — Cloudflare, DuckDNS, Namecheap, generic webhook
3. **Fail gracefully** — Logs errors, retries on transient failures
4. **Minimal footprint** — Pure bash + curl + jq, no heavy deps
5. **Alert on change** — Optional Telegram/webhook notifications

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests + IP detection)
- `jq` (JSON parsing for API responses)
- Optional: `cron` (scheduled runs)
