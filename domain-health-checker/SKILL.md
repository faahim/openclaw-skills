---
name: domain-health-checker
description: >-
  Complete domain health audit — DNS, SSL, HTTP, WHOIS, email auth (SPF/DKIM/DMARC) in one command.
categories: [dev-tools, security]
dependencies: [bash, curl, dig, openssl, whois]
---

# Domain Health Checker

## What This Does

Run a full health check on any domain in seconds. Checks DNS resolution, SSL certificate validity & expiry, HTTP status & redirects, WHOIS registration expiry, and email authentication records (SPF, DKIM, DMARC). Outputs a clear pass/warn/fail report.

**Example:** `bash scripts/check.sh example.com` → full diagnostic report with actionable findings.

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# These are pre-installed on most Linux/Mac systems
which curl dig openssl whois || echo "Install missing tools: apt install dnsutils openssl whois curl"
```

### 2. Run Your First Check

```bash
bash scripts/check.sh yourdomain.com
```

### 3. Output Example

```
╔══════════════════════════════════════════════════════╗
║          DOMAIN HEALTH CHECK: example.com           ║
╚══════════════════════════════════════════════════════╝

── DNS ──────────────────────────────────────────────
  ✅ A Record:       93.184.216.34
  ✅ AAAA Record:    2606:2800:220:1:248:1893:25c8:1946
  ✅ NS Records:     a.iana-servers.net, b.iana-servers.net
  ✅ MX Records:     0 .
  ⚠️  CAA Record:    Not set (recommended for SSL control)

── SSL ──────────────────────────────────────────────
  ✅ Certificate:    Valid
  ✅ Issuer:         DigiCert Inc
  ✅ Expires:        2025-03-01 (182 days remaining)
  ✅ SANs:           example.com, www.example.com
  ⚠️  HSTS:          Not enabled

── HTTP ─────────────────────────────────────────────
  ✅ Status:         200 OK
  ✅ Response Time:  145ms
  ✅ Redirect:       http → https (301)
  ✅ www Redirect:   www → apex (or vice versa)

── WHOIS ────────────────────────────────────────────
  ✅ Registrar:      MarkMonitor Inc.
  ✅ Expires:        2025-08-13 (347 days remaining)
  ⚠️  DNSSEC:        unsigned

── EMAIL AUTH ───────────────────────────────────────
  ✅ SPF:            v=spf1 -all
  ❌ DKIM:           No DKIM record found (selector: default)
  ✅ DMARC:          v=DMARC1; p=reject

── SUMMARY ──────────────────────────────────────────
  Score: 82/100  |  ✅ 12 passed  ⚠️ 3 warnings  ❌ 1 failed
```

## Core Workflows

### Workflow 1: Quick Domain Check

```bash
bash scripts/check.sh example.com
```

### Workflow 2: Check Multiple Domains

```bash
bash scripts/check.sh example.com mysite.org api.service.com
```

### Workflow 3: SSL-Only Check (Fast)

```bash
bash scripts/check.sh --ssl-only example.com
```

### Workflow 4: JSON Output (for scripting)

```bash
bash scripts/check.sh --json example.com
```

### Workflow 5: Monitor Domain Expiry

```bash
# Alert if SSL or WHOIS expires within 30 days
bash scripts/check.sh --expiry-alert 30 example.com
```

### Workflow 6: Email Auth Audit

```bash
# Check SPF, DKIM, DMARC only
bash scripts/check.sh --email-only example.com
```

### Workflow 7: Custom DKIM Selector

```bash
bash scripts/check.sh --dkim-selector google example.com
```

## Configuration

### Environment Variables (Optional)

```bash
# Custom DKIM selector (default: "default")
export DKIM_SELECTOR="google"

# Timeout for HTTP checks (default: 10 seconds)
export HTTP_TIMEOUT=10

# Telegram alerts for expiring domains
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"
```

## Advanced Usage

### Run as Cron (Weekly Domain Audit)

```bash
# Check all your domains every Monday at 9am
0 9 * * 1 bash /path/to/scripts/check.sh --expiry-alert 30 --json domain1.com domain2.com >> /var/log/domain-health.json
```

### Pipe to Notification

```bash
bash scripts/check.sh --json example.com | jq '.summary' | \
  curl -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" \
  -d "chat_id=$CHAT_ID" -d "text=$(cat -)"
```

## Troubleshooting

### "dig: command not found"
```bash
sudo apt install dnsutils    # Debian/Ubuntu
brew install bind            # macOS
```

### "whois: command not found"
```bash
sudo apt install whois       # Debian/Ubuntu
brew install whois           # macOS
```

### Slow WHOIS lookups
WHOIS servers can be slow or rate-limit. Add `--skip-whois` to skip.

### DKIM not found
DKIM requires knowing the selector. Try common ones: `google`, `default`, `selector1` (Microsoft), `k1` (Mailchimp).

```bash
bash scripts/check.sh --dkim-selector google example.com
bash scripts/check.sh --dkim-selector selector1 example.com
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP checks)
- `dig` (DNS lookups) — part of `dnsutils` / `bind-utils`
- `openssl` (SSL certificate checks)
- `whois` (domain registration checks)
- `jq` (optional, for JSON output)
