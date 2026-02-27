# Listing Copy: Email Deliverability Checker

## Metadata
- **Type:** Skill
- **Name:** email-deliverability
- **Display Name:** Email Deliverability Checker
- **Categories:** [communication, security]
- **Price:** $8
- **Dependencies:** [dig, curl, bash]
- **Icon:** 📧

## Tagline

"Check email deliverability for any domain — SPF, DKIM, DMARC, MX & blacklist audit"

## Description

Emails landing in spam? DNS records misconfigured? Don't guess — check. Email Deliverability Checker validates your domain's entire email authentication stack in seconds.

Run one command and get a complete report: MX records, SPF policy, DKIM signatures, DMARC enforcement, plus a scan against 30+ DNS blacklists. Get a 0-100 deliverability score with specific, actionable recommendations to fix any issues.

**What it does:**
- ✅ Validate MX, SPF, DKIM, and DMARC records
- 🚫 Scan 30+ DNS blacklists (DNSBL) for IP reputation
- 📊 Score 0-100 with specific fix recommendations
- 🔑 Auto-check common DKIM selectors (Google, Microsoft, SendGrid, Mailgun, etc.)
- 📋 JSON output for automation and monitoring
- ⚡ Batch check multiple domains
- 🔄 Run as cron job for continuous monitoring

Perfect for developers, sysadmins, email marketers, and anyone running their own mail server or using transactional email services.

## Core Capabilities

1. MX record validation — Verify mail servers are properly configured
2. SPF policy check — Detect missing, weak (+all), or misconfigured SPF
3. DKIM verification — Auto-scan 8 common selectors (Google, Microsoft, SendGrid, etc.)
4. DMARC enforcement check — Flag 'none' policies, validate reporting addresses
5. Blacklist scan — Check IP against 30+ DNSBL services
6. Deliverability score — 0-100 weighted score with grade
7. Actionable recommendations — Specific fixes, not vague advice
8. JSON output — Pipe into monitoring, alerting, or dashboards
9. Custom DKIM selectors — Specify your provider's exact selector
10. Batch mode — Check multiple domains in one pass

## Dependencies
- `bash` (4.0+)
- `dig` (part of dnsutils/bind-utils)
- `jq` (optional, for JSON formatting)

## Installation Time
**2 minutes** — No installation needed, just run the script
