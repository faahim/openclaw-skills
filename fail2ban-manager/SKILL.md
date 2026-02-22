---
name: fail2ban-manager
description: >-
  Install, configure, and manage Fail2ban intrusion prevention — monitor bans, manage jails, whitelist IPs, and get alerts on brute-force attacks.
categories: [security, automation]
dependencies: [fail2ban, bash, iptables]
---

# Fail2ban Manager

## What This Does

Automates Fail2ban intrusion prevention system setup and management. Install fail2ban, configure jails for SSH/Nginx/Apache/custom services, monitor active bans, whitelist trusted IPs, and get Telegram alerts when attackers are banned.

**Example:** "Set up fail2ban to protect SSH, ban IPs after 3 failed attempts for 1 hour, whitelist my office IP, alert me on Telegram when someone gets banned."

## Quick Start (5 minutes)

### 1. Install Fail2ban

```bash
bash scripts/install.sh
```

This installs fail2ban and enables it on boot. Supports Ubuntu/Debian, CentOS/RHEL, and Fedora.

### 2. Configure SSH Protection (Default)

```bash
bash scripts/configure.sh --jail sshd --maxretry 3 --bantime 3600 --findtime 600
```

Output:
```
✅ Jail [sshd] configured:
   Max retries: 3
   Ban time: 3600s (1 hour)
   Find time: 600s (10 minutes)
   Action: iptables-multiport
✅ Fail2ban reloaded
```

### 3. Check Status

```bash
bash scripts/status.sh
```

Output:
```
╔══════════════════════════════════════════════╗
║          FAIL2BAN STATUS REPORT             ║
╠══════════════════════════════════════════════╣
║ Service: active (running)                    ║
║ Jails:   2 active                           ║
╠══════════════════════════════════════════════╣
║ Jail: sshd                                  ║
║   Currently banned: 3                        ║
║   Total banned: 47                           ║
║   Banned IPs: 192.168.1.100, 10.0.0.5, ...  ║
╠══════════════════════════════════════════════╣
║ Jail: nginx-http-auth                        ║
║   Currently banned: 1                        ║
║   Total banned: 12                           ║
╚══════════════════════════════════════════════╝
```

## Core Workflows

### Workflow 1: Protect SSH from Brute-Force

```bash
# Standard SSH protection
bash scripts/configure.sh --jail sshd --maxretry 5 --bantime 3600

# Aggressive (ban after 2 attempts for 24h)
bash scripts/configure.sh --jail sshd --maxretry 2 --bantime 86400

# Permanent ban (recidive jail — bans repeat offenders permanently)
bash scripts/configure.sh --jail recidive --maxretry 3 --bantime -1
```

### Workflow 2: Protect Nginx/Apache

```bash
# Nginx HTTP auth
bash scripts/configure.sh --jail nginx-http-auth --maxretry 3 --bantime 3600

# Nginx rate limiting (too many requests)
bash scripts/configure.sh --jail nginx-limit-req --maxretry 10 --bantime 600

# Apache auth failures
bash scripts/configure.sh --jail apache-auth --maxretry 5 --bantime 3600
```

### Workflow 3: Whitelist Trusted IPs

```bash
# Whitelist single IP
bash scripts/whitelist.sh --add 203.0.113.50

# Whitelist CIDR range
bash scripts/whitelist.sh --add 10.0.0.0/24

# Remove from whitelist
bash scripts/whitelist.sh --remove 203.0.113.50

# List all whitelisted IPs
bash scripts/whitelist.sh --list
```

### Workflow 4: Manual Ban/Unban

```bash
# Ban an IP in sshd jail
bash scripts/ban.sh --jail sshd --ip 192.168.1.100

# Unban an IP
bash scripts/ban.sh --unban --jail sshd --ip 192.168.1.100

# Unban all IPs in a jail
bash scripts/ban.sh --unban-all --jail sshd
```

### Workflow 5: Telegram Alerts on Bans

```bash
# Set up Telegram notifications
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

bash scripts/configure.sh --jail sshd --alert telegram

# You'll receive messages like:
# 🚨 Fail2ban Alert
# Jail: sshd
# Action: BAN
# IP: 192.168.1.100
# Country: CN
# Time: 2026-02-22 16:53:00 UTC
```

### Workflow 6: View Ban History & Stats

```bash
# Recent bans (last 24h)
bash scripts/history.sh --hours 24

# Top banned IPs (all time)
bash scripts/history.sh --top 10

# Bans by country (requires geoip)
bash scripts/history.sh --by-country

# Export ban log to CSV
bash scripts/history.sh --export bans.csv
```

## Configuration

### Custom Jail (Any Service)

```bash
# Create custom jail for any log file
bash scripts/configure.sh \
  --jail my-app \
  --logpath /var/log/myapp/auth.log \
  --filter-regex 'Failed login from <HOST>' \
  --maxretry 5 \
  --bantime 3600
```

### Config File (YAML)

```yaml
# fail2ban-config.yaml
global:
  bantime: 3600
  findtime: 600
  maxretry: 5
  ignoreip:
    - 127.0.0.1/8
    - 10.0.0.0/24

jails:
  sshd:
    enabled: true
    maxretry: 3
    bantime: 86400
    
  nginx-http-auth:
    enabled: true
    maxretry: 5
    bantime: 3600
    
  custom-app:
    enabled: true
    logpath: /var/log/myapp/access.log
    filter_regex: 'Unauthorized access from <HOST>'
    maxretry: 3
    bantime: 7200

alerts:
  telegram:
    bot_token: "${TELEGRAM_BOT_TOKEN}"
    chat_id: "${TELEGRAM_CHAT_ID}"
```

Apply config:
```bash
bash scripts/configure.sh --config fail2ban-config.yaml
```

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# GeoIP for country lookup (optional)
export GEOIP_DB="/usr/share/GeoIP/GeoLite2-Country.mmdb"
```

## Advanced Usage

### Scheduled Ban Report (Cron)

```bash
# Daily ban report at 9am
0 9 * * * bash /path/to/scripts/history.sh --hours 24 --summary | bash /path/to/scripts/notify.sh
```

### Fail2ban + Cloudflare (Ban at CDN level)

```bash
# Configure Cloudflare action (bans IP at Cloudflare, not just iptables)
export CLOUDFLARE_API_TOKEN="your-cf-token"
export CLOUDFLARE_ZONE_ID="your-zone-id"

bash scripts/configure.sh --jail sshd --action cloudflare
```

### Monitor Multiple Servers

```bash
# Pull status from remote servers via SSH
bash scripts/status.sh --remote user@server1.com user@server2.com
```

## Troubleshooting

### Issue: "fail2ban-client: command not found"

```bash
# Run the installer
bash scripts/install.sh
```

### Issue: Fail2ban not starting

```bash
# Check for config errors
sudo fail2ban-client -t

# Check logs
sudo tail -50 /var/log/fail2ban.log
```

### Issue: IPs not getting banned

Check:
1. Log path is correct: `sudo fail2ban-client get sshd logpath`
2. Filter matches log format: `sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf`
3. Fail2ban is running: `sudo systemctl status fail2ban`

### Issue: Locked myself out

```bash
# If you have console access:
sudo fail2ban-client set sshd unbanip YOUR_IP

# Or stop fail2ban temporarily:
sudo systemctl stop fail2ban
# Fix your whitelist, then restart
```

## Dependencies

- `fail2ban` (installed by scripts/install.sh)
- `bash` (4.0+)
- `iptables` or `nftables` (firewall backend)
- `curl` (for Telegram alerts)
- Optional: `geoiplookup` (country lookup for banned IPs)
- Optional: `jq` (JSON parsing for Cloudflare integration)
