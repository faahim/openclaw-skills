---
name: email-deliverability
description: >-
  Check email deliverability for any domain — SPF, DKIM, DMARC, MX records, and blacklist status.
categories: [communication, security]
dependencies: [dig, curl, bash]
---

# Email Deliverability Checker

## What This Does

Checks whether a domain's email setup is properly configured for reliable delivery. Validates SPF, DKIM, DMARC, and MX records, checks against 30+ DNS blacklists, and generates a deliverability score with actionable recommendations.

**Example:** "Check example.com → SPF ✅, DKIM ❌ (no record), DMARC ✅, MX ✅, Blacklists: clean. Score: 75/100. Fix: Add DKIM record."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# Required (pre-installed on most systems)
which dig curl bash || echo "Install bind-utils (dig) and curl"
```

### 2. Run First Check

```bash
bash scripts/check.sh example.com
```

### 3. Full Report with Blacklist Scan

```bash
bash scripts/check.sh --full example.com
```

## Core Workflows

### Workflow 1: Quick DNS Check

**Use case:** Verify email DNS records are correct

```bash
bash scripts/check.sh yourdomain.com
```

**Output:**
```
═══════════════════════════════════════════════
  Email Deliverability Report: yourdomain.com
═══════════════════════════════════════════════

📬 MX Records
  ✅ 10 mail.yourdomain.com
  ✅ 20 mail2.yourdomain.com

🛡️  SPF Record
  ✅ v=spf1 include:_spf.google.com ~all

🔑 DKIM (default selector)
  ❌ No DKIM record found for selector 'default'

📋 DMARC Record
  ✅ v=DMARC1; p=reject; rua=mailto:dmarc@yourdomain.com

📊 Score: 75/100

⚠️  Recommendations:
  1. Add DKIM record for selector 'default' (or specify your selector with --dkim-selector)
```

### Workflow 2: Full Audit with Blacklists

**Use case:** Complete deliverability audit before a campaign

```bash
bash scripts/check.sh --full yourdomain.com
```

Adds blacklist checks against 30+ DNSBL services.

### Workflow 3: Check Specific DKIM Selector

**Use case:** Your DKIM uses a custom selector (e.g., Google uses `google`)

```bash
bash scripts/check.sh --dkim-selector google yourdomain.com
```

### Workflow 4: Batch Check Multiple Domains

```bash
echo -e "domain1.com\ndomain2.com\ndomain3.com" | while read d; do
  bash scripts/check.sh "$d"
  echo "---"
done
```

### Workflow 5: JSON Output (for automation)

```bash
bash scripts/check.sh --json yourdomain.com
```

**Output:**
```json
{
  "domain": "yourdomain.com",
  "score": 75,
  "mx": {"status": "pass", "records": ["10 mail.yourdomain.com"]},
  "spf": {"status": "pass", "record": "v=spf1 include:_spf.google.com ~all"},
  "dkim": {"status": "fail", "selector": "default", "error": "No record found"},
  "dmarc": {"status": "pass", "record": "v=DMARC1; p=reject; rua=mailto:dmarc@yourdomain.com"},
  "blacklists": {"checked": 0, "listed": 0},
  "recommendations": ["Add DKIM record for selector 'default'"]
}
```

## Configuration

### Environment Variables

```bash
# Custom DKIM selectors to check (comma-separated)
export DKIM_SELECTORS="default,google,selector1,selector2,k1,s1,s2,dkim"

# Timeout for DNS queries (seconds)
export DNS_TIMEOUT=5

# Custom DNS server
export DNS_SERVER="8.8.8.8"
```

## Advanced Usage

### Run as OpenClaw Cron Job

```bash
# Weekly deliverability check
# Add to OpenClaw cron: run every Monday at 9am
bash scripts/check.sh --json yourdomain.com > /path/to/reports/$(date +%Y-%m-%d).json
```

### Compare Over Time

```bash
# Check and append to log
bash scripts/check.sh --json yourdomain.com | jq '{date: now | todate, score: .score, issues: [.recommendations[]]}' >> deliverability-log.jsonl
```

### Integration with OpenClaw Alerts

```bash
# Alert if score drops below threshold
SCORE=$(bash scripts/check.sh --json yourdomain.com | jq '.score')
if [ "$SCORE" -lt 80 ]; then
  echo "⚠️ Deliverability score dropped to $SCORE/100"
fi
```

## Troubleshooting

### Issue: "dig: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install dnsutils

# RHEL/CentOS
sudo yum install bind-utils

# Mac
# dig is pre-installed
```

### Issue: Blacklist checks timing out

Some DNSBL servers may be slow. Use `--timeout 10` to increase the DNS query timeout, or skip blacklists with `--no-blacklist`.

### Issue: DKIM shows fail but it's configured

DKIM records use selectors. Check which selector your email provider uses:
- **Google Workspace:** `google`
- **Microsoft 365:** `selector1`, `selector2`
- **Mailgun:** `smtp`, `k1`
- **SendGrid:** `s1`, `s2`
- **Postmark:** `20230601` (date-based)

```bash
bash scripts/check.sh --dkim-selector google,selector1,selector2 yourdomain.com
```

## Scoring

| Check | Points | Criteria |
|-------|--------|----------|
| MX Records | 25 | At least one valid MX record |
| SPF | 25 | Valid SPF record with proper policy |
| DKIM | 25 | Valid DKIM record for at least one selector |
| DMARC | 25 | Valid DMARC record with enforcement policy |
| Blacklists | -5 each | Deduct 5 points per blacklist listing |

## Dependencies

- `bash` (4.0+)
- `dig` (DNS lookups — part of `dnsutils` / `bind-utils`)
- `curl` (optional, for future webhook alerts)
- `jq` (optional, for JSON output formatting)
