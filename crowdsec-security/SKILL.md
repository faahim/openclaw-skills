---
name: crowdsec-security
description: >-
  Install and manage CrowdSec — a collaborative intrusion prevention system that analyzes server logs, detects attacks, and shares threat intelligence with the community.
categories: [security, automation]
dependencies: [bash, curl, jq]
---

# CrowdSec Security Manager

## What This Does

CrowdSec is a collaborative intrusion prevention system (IPS). It analyzes your server logs in real-time, detects brute-force attacks, port scans, web exploits, and more — then blocks malicious IPs automatically. Unlike traditional firewalls, CrowdSec shares threat intelligence across its community: when one server detects an attacker, all participants benefit.

This skill installs CrowdSec, configures it for your stack, manages bouncers (the enforcement layer), and gives you full control over alerts, decisions, and blocklists.

**Example:** "Install CrowdSec, protect SSH + Nginx, auto-ban attackers, get Telegram alerts on incidents."

## Quick Start (10 minutes)

### 1. Install CrowdSec

```bash
bash scripts/install.sh
```

This installs the CrowdSec engine + CLI (`cscli`). Supports Debian/Ubuntu, RHEL/CentOS/Fedora, and Alpine.

### 2. Install a Bouncer (Enforcement)

```bash
# For iptables/nftables firewall blocking
bash scripts/setup-bouncer.sh firewall

# For Nginx (403 on banned IPs)
bash scripts/setup-bouncer.sh nginx

# For Cloudflare (block at edge)
bash scripts/setup-bouncer.sh cloudflare
```

### 3. Verify It's Working

```bash
bash scripts/status.sh
```

Output:
```
CrowdSec Engine: ✅ Running (v1.6.x)
Acquisitions:
  - /var/log/auth.log (sshd)
  - /var/log/nginx/access.log (nginx)
Bouncers:
  - cs-firewall-bouncer ✅ Active
Scenarios: 28 installed
Community Blocklists: ✅ Subscribed
Last 24h: 3 alerts, 12 decisions (bans)
```

## Core Workflows

### Workflow 1: Protect SSH from Brute Force

```bash
# Install SSH collection (scenarios + parsers)
cscli collections install crowdsecurity/sshd

# Verify log acquisition
cscli machines list
cscli metrics

# Test: simulate failed logins
# CrowdSec auto-detects and bans after threshold
```

### Workflow 2: Protect Web Server (Nginx/Apache)

```bash
# Install web server collections
cscli collections install crowdsecurity/nginx
# or
cscli collections install crowdsecurity/apache2

# Configure log path if non-standard
bash scripts/add-log.sh /var/log/nginx/access.log nginx

# Install WAF-like scenarios
cscli scenarios install crowdsecurity/http-bad-user-agent
cscli scenarios install crowdsecurity/http-crawl-non_statics
cscli scenarios install crowdsecurity/http-path-traversal-probing
```

### Workflow 3: View & Manage Alerts

```bash
# View recent alerts
cscli alerts list

# View active bans/decisions
cscli decisions list

# Manually ban an IP
cscli decisions add --ip 1.2.3.4 --duration 24h --reason "manual ban"

# Unban an IP
cscli decisions delete --ip 1.2.3.4

# Check if a specific IP is banned
cscli decisions list --ip 1.2.3.4
```

### Workflow 4: Subscribe to Community Blocklists

```bash
# Register with CrowdSec Central API (free)
cscli capi register

# Enroll in console (optional, for web dashboard)
cscli console enroll <enrollment-key>

# Check blocklist status
cscli capi status
```

### Workflow 5: Set Up Telegram Alerts

```bash
bash scripts/setup-alerts.sh telegram \
  --bot-token "$TELEGRAM_BOT_TOKEN" \
  --chat-id "$TELEGRAM_CHAT_ID"
```

On detection:
```
🚨 CrowdSec Alert
IP: 45.33.12.87
Scenario: crowdsecurity/ssh-bf
Action: Ban 4h
Source: CN (Beijing)
```

### Workflow 6: Whitelist Trusted IPs

```bash
# Whitelist a single IP
bash scripts/whitelist.sh add 10.0.0.1

# Whitelist a CIDR range
bash scripts/whitelist.sh add 192.168.1.0/24

# List whitelisted IPs
bash scripts/whitelist.sh list

# Remove from whitelist
bash scripts/whitelist.sh remove 10.0.0.1
```

## Configuration

### Acquisitions (Log Sources)

Edit `/etc/crowdsec/acquis.yaml` or use the helper:

```bash
# Add a new log source
bash scripts/add-log.sh /var/log/myapp/access.log nginx

# List current acquisitions
cat /etc/crowdsec/acquis.yaml
```

Example `acquis.yaml`:
```yaml
filenames:
  - /var/log/auth.log
labels:
  type: syslog
---
filenames:
  - /var/log/nginx/access.log
  - /var/log/nginx/error.log
labels:
  type: nginx
```

### Environment Variables

```bash
# For Telegram alerts
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# For Cloudflare bouncer
export CF_API_TOKEN="<cloudflare-api-token>"
export CF_ACCOUNT_ID="<account-id>"
```

### Tuning Ban Duration

Edit `/etc/crowdsec/profiles.yaml`:
```yaml
name: default_ip_remediation
filters:
  - Alert.Remediation == true && Alert.GetScope() == "Ip"
decisions:
  - type: ban
    duration: 4h  # Change this (default: 4h)
```

## Advanced Usage

### Custom Scenario (Rate Limiting)

```bash
# Create custom scenario for your app
bash scripts/create-scenario.sh \
  --name "myapp/login-bf" \
  --filter "evt.Meta.log_type == 'myapp'" \
  --groupby "evt.Meta.source_ip" \
  --threshold 5 \
  --timewindow 60s \
  --ban-duration 2h
```

### Run as Monitoring Dashboard

```bash
# Real-time metrics
cscli metrics

# Export Prometheus metrics (for Grafana)
# Enabled by default on :6060/metrics
curl -s localhost:6060/metrics | grep cs_
```

### Multi-Server Setup

```bash
# On central server: register new machine
cscli machines add worker-1 --password <password>

# On worker: configure to report to central
# Edit /etc/crowdsec/config.yaml → api.server
```

### Backup & Restore

```bash
# Backup all configs, scenarios, decisions
bash scripts/backup.sh /path/to/backup/

# Restore from backup
bash scripts/restore.sh /path/to/backup/
```

## Troubleshooting

### Issue: CrowdSec not detecting attacks

**Check:**
1. Log file exists and is readable: `ls -la /var/log/auth.log`
2. Acquisition is configured: `cat /etc/crowdsec/acquis.yaml`
3. Parsers match log format: `cscli parsers list`
4. Test with: `cscli explain --file /var/log/auth.log --type syslog`

### Issue: Bouncer not blocking

**Check:**
1. Bouncer is registered: `cscli bouncers list`
2. Bouncer service running: `systemctl status crowdsec-firewall-bouncer`
3. Decisions exist: `cscli decisions list`
4. Test: `cscli decisions add --ip 203.0.113.1 --duration 1m --reason test`

### Issue: Too many false positives

**Fix:**
1. Whitelist legitimate IPs: `bash scripts/whitelist.sh add <ip>`
2. Increase scenario thresholds in `/etc/crowdsec/scenarios/`
3. Use `cscli alerts inspect <id>` to understand what triggered

### Issue: High memory usage

**Fix:**
```bash
# Prune old decisions
cscli decisions delete --all --contained

# Reduce in-memory bucket count
# Edit /etc/crowdsec/config.yaml
# crowdsec_service.buckets_routines: 10
```

## Dependencies

- `bash` (4.0+)
- `curl` (for API calls and installation)
- `jq` (for JSON parsing)
- `systemd` (for service management)
- Root/sudo access (for installation and firewall rules)

## Key Principles

1. **Defense in depth** — Multiple detection scenarios, not just one
2. **Community-powered** — Shared threat intelligence makes everyone safer
3. **Low false positives** — Tuned scenarios with sane defaults
4. **Graduated response** — Captcha → throttle → ban escalation available
5. **Observable** — Prometheus metrics, detailed logs, alert notifications
