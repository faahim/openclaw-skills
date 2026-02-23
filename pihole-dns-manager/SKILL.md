---
name: pihole-dns-manager
description: >-
  Install, configure, and manage Pi-hole DNS ad blocker — block ads network-wide, manage blocklists, whitelist/blacklist domains, and monitor DNS query stats.
categories: [home, security]
dependencies: [bash, curl, jq, pihole]
---

# Pi-hole DNS Manager

## What This Does

Installs and manages [Pi-hole](https://pi-hole.net), the network-wide ad blocker that acts as a DNS sinkhole. Block ads, trackers, and malware domains for every device on your network without installing anything on individual devices.

**Example:** "Install Pi-hole, add custom blocklists, whitelist my work domains, and get daily DNS query stats via Telegram."

## Quick Start (10 minutes)

### 1. Install Pi-hole

```bash
# Run the installer (automated, non-interactive)
bash scripts/install.sh

# Or interactive install (choose your settings)
bash scripts/install.sh --interactive
```

### 2. Check Status

```bash
bash scripts/pihole-manager.sh status
```

**Output:**
```
🛡️ Pi-hole Status
━━━━━━━━━━━━━━━━━━━━━━━━
Status:        ✅ Active (blocking)
Domains on blocklist: 174,892
DNS queries today:    2,847
Queries blocked:      612 (21.5%)
Memory usage:         42 MB
FTL version:          5.25.2
Web interface:        http://192.168.1.100/admin
```

### 3. Set as DNS Server

Point your router's DNS to the Pi-hole's IP address, or configure individual devices:
- **Router:** Set primary DNS to Pi-hole IP in router settings
- **Device:** Set DNS server to Pi-hole IP in network settings

## Core Workflows

### Workflow 1: Manage Blocklists

```bash
# List current blocklists
bash scripts/pihole-manager.sh blocklists

# Add a blocklist
bash scripts/pihole-manager.sh blocklist-add "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"

# Add popular blocklist packs
bash scripts/pihole-manager.sh blocklist-pack malware    # Malware domains
bash scripts/pihole-manager.sh blocklist-pack tracking   # Tracking domains
bash scripts/pihole-manager.sh blocklist-pack social     # Social media trackers
bash scripts/pihole-manager.sh blocklist-pack ads-aggressive  # Aggressive ad blocking

# Update gravity (apply blocklist changes)
bash scripts/pihole-manager.sh gravity-update
```

### Workflow 2: Whitelist / Blacklist Domains

```bash
# Whitelist a domain (allow it through)
bash scripts/pihole-manager.sh whitelist example.com

# Whitelist multiple domains
bash scripts/pihole-manager.sh whitelist-file domains.txt

# Blacklist a domain (block it)
bash scripts/pihole-manager.sh blacklist ads.example.com

# Remove from whitelist/blacklist
bash scripts/pihole-manager.sh whitelist-remove example.com
bash scripts/pihole-manager.sh blacklist-remove ads.example.com

# List all whitelisted/blacklisted domains
bash scripts/pihole-manager.sh whitelist-show
bash scripts/pihole-manager.sh blacklist-show
```

### Workflow 3: Query Monitoring & Stats

```bash
# Show today's stats
bash scripts/pihole-manager.sh stats

# Show top blocked domains
bash scripts/pihole-manager.sh top-blocked 20

# Show top permitted domains
bash scripts/pihole-manager.sh top-permitted 20

# Show top clients (which devices query most)
bash scripts/pihole-manager.sh top-clients

# Query log — find what happened to a specific domain
bash scripts/pihole-manager.sh query-log example.com

# Export stats as JSON (for dashboards/cron)
bash scripts/pihole-manager.sh stats --json
```

### Workflow 4: Enable/Disable Blocking

```bash
# Temporarily disable blocking (e.g., troubleshooting)
bash scripts/pihole-manager.sh disable 5m    # 5 minutes
bash scripts/pihole-manager.sh disable 1h    # 1 hour
bash scripts/pihole-manager.sh disable       # indefinitely

# Re-enable blocking
bash scripts/pihole-manager.sh enable
```

### Workflow 5: Daily Report via Telegram

```bash
# Set up daily stats report
export TELEGRAM_BOT_TOKEN="<your-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

bash scripts/pihole-manager.sh daily-report

# Output sent to Telegram:
# 🛡️ Pi-hole Daily Report — 2026-02-23
# ━━━━━━━━━━━━━━━━━━━━━━━━
# Total queries:    12,483
# Blocked:          2,891 (23.2%)
# Top blocked:      ads.doubleclick.net (342)
# Blocklist size:   174,892 domains
# Status:           ✅ Active

# Schedule as cron job (daily at 8am)
bash scripts/pihole-manager.sh setup-cron-report "0 8 * * *"
```

### Workflow 6: Backup & Restore

```bash
# Backup Pi-hole config (blocklists, whitelist, blacklist, settings)
bash scripts/pihole-manager.sh backup

# Output: Backup saved to /home/clawd/pihole-backups/pihole-backup-2026-02-23.tar.gz

# Restore from backup
bash scripts/pihole-manager.sh restore /home/clawd/pihole-backups/pihole-backup-2026-02-23.tar.gz

# List available backups
bash scripts/pihole-manager.sh backup-list
```

## Configuration

### Environment Variables

```bash
# Pi-hole API (auto-detected if running locally)
export PIHOLE_HOST="http://localhost"          # Pi-hole web address
export PIHOLE_API_KEY="<your-api-key>"         # From Pi-hole Admin > Settings > API

# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<bot-token>"
export TELEGRAM_CHAT_ID="<chat-id>"
```

### Getting Your Pi-hole API Key

```bash
# If Pi-hole is on this machine:
cat /etc/pihole/setupVars.conf | grep WEBPASSWORD

# Or from the web interface:
# Go to http://<pihole-ip>/admin > Settings > API > Show API token
```

## Advanced Usage

### Custom DNS Records (Local DNS)

```bash
# Add local DNS record (e.g., point myserver.local to 192.168.1.50)
bash scripts/pihole-manager.sh local-dns-add myserver.local 192.168.1.50

# List local DNS records
bash scripts/pihole-manager.sh local-dns-list

# Remove local DNS record
bash scripts/pihole-manager.sh local-dns-remove myserver.local
```

### CNAME Records

```bash
# Add CNAME record
bash scripts/pihole-manager.sh cname-add app.local myserver.local

# List CNAME records
bash scripts/pihole-manager.sh cname-list
```

### Regex Filtering

```bash
# Block domains matching a regex pattern
bash scripts/pihole-manager.sh regex-add ".*\.ads\..*"

# Whitelist regex
bash scripts/pihole-manager.sh regex-whitelist-add ".*\.mycompany\.com"

# List regex filters
bash scripts/pihole-manager.sh regex-list
```

### Unattended Update

```bash
# Update Pi-hole to latest version
bash scripts/pihole-manager.sh update

# Check for updates without installing
bash scripts/pihole-manager.sh update --check
```

## Troubleshooting

### Issue: Pi-hole not blocking ads

**Check:**
1. DNS is pointing to Pi-hole: `nslookup ads.google.com <pihole-ip>`
2. Pi-hole is running: `bash scripts/pihole-manager.sh status`
3. Gravity is up to date: `bash scripts/pihole-manager.sh gravity-update`

### Issue: Website broken after enabling Pi-hole

**Fix:** Whitelist the domain causing issues:
```bash
# Check query log to find blocked domain
bash scripts/pihole-manager.sh query-log broken-site.com

# Whitelist the necessary domain
bash scripts/pihole-manager.sh whitelist cdn.broken-site.com
```

### Issue: API key not working

**Fix:**
```bash
# Get the correct API key
sudo cat /etc/pihole/setupVars.conf | grep WEBPASSWORD
# Set it
export PIHOLE_API_KEY="<key-from-above>"
```

### Issue: Install fails

**Check:**
- Must run as root/sudo
- Ports 53 (DNS) and 80 (web) must be free
- `systemd-resolved` may conflict — installer handles this

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to Pi-hole API)
- `jq` (JSON parsing)
- `pihole` (installed by `scripts/install.sh`)
- Root/sudo access (for installation and DNS management)
