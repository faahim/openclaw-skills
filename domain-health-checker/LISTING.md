# Listing Copy: Domain Health Checker

## Metadata
- **Type:** Skill
- **Name:** domain-health-checker
- **Display Name:** Domain Health Checker
- **Categories:** [dev-tools, security]
- **Icon:** 🏥
- **Dependencies:** [bash, curl, dig, openssl, whois]

## Tagline
Complete domain diagnostics — DNS, SSL, HTTP, WHOIS & email auth in one command

## Description

Checking domain health means jumping between 5+ different tools: SSL checkers, DNS lookup sites, WHOIS databases, email auth validators. It's tedious and easy to miss something critical — like an expiring SSL cert or a missing DMARC record.

Domain Health Checker runs a comprehensive audit with a single command. It checks DNS records (A, AAAA, NS, MX, CAA), SSL certificate validity and expiry, HTTP status and redirects, WHOIS registration expiry, and email authentication (SPF, DKIM, DMARC). Everything outputs as a clear pass/warn/fail report.

**What it does:**
- 🔍 DNS audit — A, AAAA, NS, MX, CAA records
- 🔐 SSL check — validity, issuer, expiry countdown, SANs, HSTS
- 🌐 HTTP check — status codes, response time, HTTPS redirect, www handling
- 📋 WHOIS — registrar, expiry date, DNSSEC status
- ✉️ Email auth — SPF, DKIM (auto-detects selector), DMARC policy
- ⏰ Expiry alerts — warn before SSL/domain expires
- 📊 Multi-domain batch checks

Perfect for developers, sysadmins, and anyone managing domains who wants one tool instead of five browser tabs.
