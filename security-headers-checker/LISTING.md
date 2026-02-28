# Listing Copy: Security Headers Checker

## Metadata
- **Type:** Skill
- **Name:** security-headers-checker
- **Display Name:** Security Headers Checker
- **Categories:** [security, dev-tools]
- **Icon:** 🛡️
- **Dependencies:** [bash, curl]

## Tagline

Audit HTTP security headers for any URL — get a grade, analysis, and fix configs

## Description

Your site might be wide open to XSS, clickjacking, and MIME sniffing attacks — and you wouldn't know it just from looking at it. Security headers are the invisible shield between your users and attackers, but most developers forget to set them up properly.

Security Headers Checker scans any URL and evaluates 8 critical HTTP security headers including Content-Security-Policy, Strict-Transport-Security, X-Frame-Options, and Permissions-Policy. You get a letter grade (A+ to F), detailed per-header analysis explaining what each header does and why it matters, and — most importantly — copy-paste fix configs for Nginx, Apache, or Cloudflare.

**What it does:**
- 🛡️ Scan any URL for 8 critical security headers
- 📊 Get a letter grade (A+ to F) with detailed scoring
- 🔧 Generate fix configs for Nginx, Apache, and Cloudflare
- 📋 JSON output for CI/CD integration and dashboards
- ⚡ Scan multiple URLs in one command
- 🚫 No API keys, no external services — just curl

Perfect for developers, DevOps engineers, and security-conscious teams who want quick, actionable security audits without spinning up expensive SaaS tools.

## Quick Start Preview

```bash
bash scripts/check-headers.sh https://yoursite.com
# Grade: B (75/100) — missing CSP and Permissions-Policy

bash scripts/check-headers.sh --fix nginx https://yoursite.com
# Outputs copy-paste Nginx config for missing headers

bash scripts/check-headers.sh --json https://yoursite.com
# JSON report for automation/CI
```

## Core Capabilities

1. HTTP security header auditing — checks CSP, HSTS, X-Frame-Options, and 5 more
2. Letter grading system — A+ to F with percentage scores
3. Per-header scoring — weighted by impact (CSP=25pts, HSTS=15pts, etc.)
4. Fix config generation — Nginx, Apache, and Cloudflare ready configs
5. JSON output — pipe into dashboards, CI/CD, or monitoring
6. Multi-URL scanning — audit all your properties in one command
7. CI/CD gate — fail builds if security grade drops below threshold
8. Zero dependencies — just bash and curl (jq optional for JSON)
9. Redirect following — handles HTTP→HTTPS redirects
10. Header filtering — check only specific headers with --only flag
