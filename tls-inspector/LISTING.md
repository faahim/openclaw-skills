# Listing Copy: TLS Inspector

## Metadata
- **Type:** Skill
- **Name:** tls-inspector
- **Display Name:** TLS Inspector
- **Categories:** [security, dev-tools]
- **Price:** $10
- **Dependencies:** [openssl, curl, bash]
- **Icon:** 🔒

## Tagline

Scan SSL/TLS security — Get instant grades and actionable fixes for any domain

## Description

Checking your SSL/TLS configuration usually means waiting in a queue on SSL Labs or manually running openssl commands. You need fast, repeatable scans — especially when managing multiple domains.

TLS Inspector deep-scans any domain's SSL/TLS setup and gives you an instant security grade (A+ to F). It checks protocol support (TLS 1.3/1.2/1.1/1.0/SSLv3), certificate health, cipher negotiation, HSTS headers, OCSP stapling, and HTTP→HTTPS redirects. Runs locally — no rate limits, no waiting, no external services.

**What it does:**
- 🔒 Grade SSL/TLS security from A+ to F with detailed scoring
- 📜 Certificate analysis — expiry, key size, signature algorithm, SANs
- 🔐 Protocol audit — flags deprecated TLS 1.0/1.1 and SSLv3
- 🛡️ Security headers — HSTS, HTTP redirect, OCSP stapling
- 📊 JSON output for automation and monitoring pipelines
- 📋 Batch scanning — scan hundreds of domains from a file
- ⚡ Fast — scan a domain in under 5 seconds

Perfect for developers, sysadmins, and security teams who need quick SSL audits without external dependencies.

## Core Capabilities

1. SSL/TLS grading — Score from A+ to F with transparent deduction breakdown
2. Certificate health — Expiry warnings, key size validation, SHA-1 detection
3. Protocol scanning — Tests TLS 1.3, 1.2, 1.1, 1.0, and SSLv3 support
4. Cipher inspection — Shows negotiated cipher suite
5. HSTS checking — Validates max-age, includeSubDomains, preload
6. Redirect detection — Checks HTTP→HTTPS redirect
7. OCSP stapling — Verifies certificate revocation optimization
8. Batch mode — Scan domain lists from file
9. JSON output — Machine-readable for CI/CD integration
10. Zero dependencies — Uses only openssl + curl (pre-installed everywhere)

## Installation Time
**2 minutes** — No install needed, just run the script

## Pricing Justification

**Why $10:**
- Comparable SaaS tools: SSL Labs (free but slow/rate-limited), Qualys ($$$), DigiCert ($$$)
- One-time payment, unlimited scans, no external service
- Useful for ongoing security audits, CI/CD pipelines, compliance
