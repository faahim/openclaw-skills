---
name: certificate-watcher
description: >-
  Monitor SSL/TLS certificate expiry across all your domains. Get alerts before certificates expire.
categories: [security, automation]
dependencies: [openssl, bash, curl]
---

# Certificate Watcher

## What This Does

Monitors SSL/TLS certificates across your domains and alerts you before they expire. Checks certificate validity, chain integrity, issuer info, and days until expiry. Runs as a cron job or on-demand scan — no external services needed.

**Example:** "Monitor 20 domains, get a Telegram alert 30 days before any cert expires, log daily status."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# These are pre-installed on most systems
which openssl curl bash || echo "Install missing tools"
```

### 2. Scan a Single Domain

```bash
bash scripts/certwatch.sh check example.com
```

**Output:**
```
✅ example.com — Valid 247 days (expires 2026-10-30) — Let's Encrypt R3
```

### 3. Scan Multiple Domains

```bash
bash scripts/certwatch.sh scan \
  example.com \
  api.example.com \
  mysite.org \
  dashboard.myapp.io
```

**Output:**
```
🔍 Certificate Watcher — Scanning 4 domains...

✅ example.com         — Valid 247 days (expires 2026-10-30) — Let's Encrypt R3
⚠️  api.example.com    — Valid  12 days (expires 2026-03-09) — Let's Encrypt R3
✅ mysite.org          — Valid 189 days (expires 2026-09-02) — DigiCert SHA2
✅ dashboard.myapp.io  — Valid 364 days (expires 2027-02-24) — Cloudflare Inc

Summary: 4 scanned | 3 OK | 1 WARNING | 0 EXPIRED
```

## Core Workflows

### Workflow 1: Check Single Domain (Detailed)

```bash
bash scripts/certwatch.sh check --verbose example.com
```

**Output:**
```
🔒 Certificate Report: example.com
   Subject:    CN=example.com
   Issuer:     C=US, O=Let's Encrypt, CN=R3
   Valid From: 2026-01-15 00:00:00 UTC
   Expires:    2026-04-15 23:59:59 UTC
   Days Left:  49
   Serial:     03:A1:B2:C3:D4:E5
   SANs:       example.com, www.example.com
   Chain:      3 certificates (complete)
   OCSP:       Good
   Status:     ✅ VALID
```

### Workflow 2: Monitor from Config File

Create a domains file:

```bash
cat > domains.txt << 'EOF'
example.com
api.example.com
staging.example.com
mysite.org:8443
internal.corp.com:443
EOF
```

Run scan:

```bash
bash scripts/certwatch.sh scan --file domains.txt --warn 30 --critical 7
```

### Workflow 3: Alert on Expiring Certs

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="your-bot-token"
export TELEGRAM_CHAT_ID="your-chat-id"

bash scripts/certwatch.sh scan --file domains.txt --warn 30 --alert telegram
```

**Alert message (sent only for warnings/critical):**
```
⚠️ Certificate Watcher Alert

api.example.com — expires in 12 days (2026-03-09)
staging.example.com — expires in 5 days (2026-03-02)

Action needed: Renew these certificates ASAP.
```

### Workflow 4: JSON Output for Automation

```bash
bash scripts/certwatch.sh scan --file domains.txt --format json
```

```json
[
  {
    "domain": "example.com",
    "port": 443,
    "valid": true,
    "days_left": 247,
    "expires": "2026-10-30T23:59:59Z",
    "issuer": "Let's Encrypt R3",
    "status": "ok"
  },
  {
    "domain": "api.example.com",
    "port": 443,
    "valid": true,
    "days_left": 12,
    "expires": "2026-03-09T23:59:59Z",
    "issuer": "Let's Encrypt R3",
    "status": "warning"
  }
]
```

### Workflow 5: Cron Job (Daily Check)

```bash
# Add to crontab — runs daily at 8am, alerts on warnings
(crontab -l 2>/dev/null; echo "0 8 * * * cd /path/to/certificate-watcher && bash scripts/certwatch.sh scan --file domains.txt --warn 30 --critical 7 --alert telegram >> /var/log/certwatch.log 2>&1") | crontab -
```

### Workflow 6: Check Non-Standard Ports

```bash
# HTTPS on port 8443
bash scripts/certwatch.sh check myservice.com:8443

# SMTP with STARTTLS
bash scripts/certwatch.sh check --starttls smtp mail.example.com:587

# IMAP with STARTTLS
bash scripts/certwatch.sh check --starttls imap mail.example.com:993
```

## Configuration

### Environment Variables

```bash
# Telegram alerts
export TELEGRAM_BOT_TOKEN="<bot-token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Slack alerts (webhook)
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."

# Email alerts
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USER="alerts@example.com"
export SMTP_PASS="app-password"
export ALERT_EMAIL="admin@example.com"

# Thresholds (days)
export CERT_WARN_DAYS=30
export CERT_CRITICAL_DAYS=7
```

### Domains File Format

```text
# One domain per line. Comments start with #
# Format: domain[:port]
example.com
api.example.com
internal.service.com:8443
# mail.example.com  # disabled for now
```

## Troubleshooting

### Issue: "Connection refused" or timeout

**Fix:** The domain may not have HTTPS enabled, or a firewall is blocking port 443.
```bash
# Test connectivity first
nc -zv example.com 443
```

### Issue: "unable to get local issuer certificate"

**Fix:** The server has an incomplete certificate chain. This is a real issue to report.

### Issue: Self-signed certificate warnings

**Fix:** Use `--allow-self-signed` to check expiry without chain validation:
```bash
bash scripts/certwatch.sh check --allow-self-signed internal.example.com
```

## Dependencies

- `openssl` (1.1+) — TLS connection and cert parsing
- `bash` (4.0+) — Script runtime
- `curl` — Alert delivery (Telegram/Slack/webhook)
- `date` — Date calculations
- Optional: `nc` (netcat) — Connection testing
- Optional: `jq` — JSON output formatting
