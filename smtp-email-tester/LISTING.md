# Listing Copy: SMTP Email Tester

## Metadata
- **Type:** Skill
- **Name:** smtp-email-tester
- **Display Name:** SMTP Email Tester
- **Categories:** [communication, dev-tools]
- **Icon:** 📧
- **Dependencies:** [bash, openssl, dig]

## Tagline
Test SMTP connections and audit email DNS — diagnose deliverability issues in seconds.

## Description

Debugging email delivery is painful. Is it the SMTP config? The DNS records? A blacklist? You need to check multiple things across different tools, and most online checkers don't let you test your own SMTP auth.

SMTP Email Tester gives your OpenClaw agent a complete email diagnostics toolkit. Test SMTP connections with STARTTLS, verify authentication, audit SPF/DKIM/DMARC records, send test emails, check TLS certificates, and scan spam blacklists — all from one script.

**What it does:**
- 🔌 Test SMTP server connectivity and STARTTLS support
- 🔐 Verify SMTP authentication (PLAIN, LOGIN)
- 📋 Audit MX, SPF, DKIM, and DMARC DNS records
- 📨 Send actual test emails to verify end-to-end delivery
- 🔒 Check TLS certificate validity and expiry
- 🚫 Scan IPs against 12 major spam blacklists
- 🔍 Auto-discover DKIM selectors across common providers
- ⚡ Smart diagnostics with actionable fix suggestions

Perfect for developers, sysadmins, and anyone managing email infrastructure who wants quick, reliable diagnostics without leaving the terminal.

## Quick Start Preview

```bash
# Audit your domain's email DNS
bash scripts/smtp-test.sh dns --domain example.com

# Test SMTP connection
bash scripts/smtp-test.sh connect --host smtp.gmail.com --port 587

# Check blacklists
bash scripts/smtp-test.sh blacklist --ip 203.0.113.1
```

## Core Capabilities

1. SMTP connection testing — TCP, banner, EHLO, auth methods
2. STARTTLS verification — Check TLS support and negotiate
3. Authentication testing — PLAIN auth with credential validation
4. MX record lookup — Find and validate mail servers
5. SPF record audit — Parse policy, flag dangerous +all
6. DKIM verification — Check selector, auto-try common selectors
7. DMARC analysis — Parse policy, check reporting config
8. Test email sending — Full end-to-end delivery test
9. TLS certificate check — Validity, expiry, SANs, cipher suite
10. Blacklist scanning — Check 12 major DNSBL providers
11. Reverse DNS check — Verify PTR records for mail servers
12. Actionable diagnostics — Every failure includes fix suggestions
