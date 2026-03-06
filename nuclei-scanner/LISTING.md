# Listing Copy: Nuclei Vulnerability Scanner

## Metadata
- **Type:** Skill
- **Name:** nuclei-scanner
- **Display Name:** Nuclei Vulnerability Scanner
- **Categories:** [security, dev-tools]
- **Price:** $15
- **Dependencies:** [bash, curl, unzip]
- **Icon:** 🔍

## Tagline

Scan websites and APIs for vulnerabilities — 8000+ detection templates, zero config

## Description

Most developers ship code without testing for known vulnerabilities. By the time a CVE hits the news, your exposed endpoint has already been indexed by attackers. You need automated security scanning that catches issues before they become incidents.

Nuclei Vulnerability Scanner installs and manages ProjectDiscovery's Nuclei — the industry-standard open-source vulnerability scanner trusted by security teams worldwide. Scan websites, APIs, and infrastructure for known CVEs, misconfigurations, exposed panels, default credentials, and more using 8000+ community-maintained detection templates.

**What it does:**
- 🔍 Scan any URL for known vulnerabilities and misconfigurations
- 🛡️ 8000+ community templates covering CVEs, exposed files, default logins
- ⚡ Fast parallel scanning with configurable rate limiting
- 📊 Multiple output formats (text, JSON, SARIF for GitHub Security)
- 🔄 Scheduled scans with summary reports
- 🎯 Filter by severity (critical/high/medium/low/info)
- 🔐 Custom headers and auth support for authenticated scanning
- 📝 Create custom detection templates for your specific checks

Perfect for developers, DevOps engineers, and security professionals who want automated vulnerability detection without expensive commercial tools.

## Quick Start Preview

```bash
# Install (one command, no dependencies)
bash scripts/install.sh

# Scan a target
nuclei -u https://yoursite.com -s critical,high

# Output:
# [exposed-gitconfig] [medium] https://yoursite.com/.git/config
# [missing-security-headers] [info] https://yoursite.com
```

## Core Capabilities

1. Web vulnerability scanning — Detect known CVEs, SQLi, XSS, SSRF, and more
2. Misconfiguration detection — Find exposed .git, .env, admin panels, debug endpoints
3. Default credential checks — Test for unchanged default passwords
4. SSL/TLS analysis — Certificate issues, weak ciphers, expiry warnings
5. Technology fingerprinting — Identify web servers, frameworks, and versions
6. Multi-target scanning — Scan hundreds of URLs from a file
7. API security testing — Authenticated scanning with custom headers
8. Scheduled audits — Cron-ready script with summary reports
9. Custom templates — Write your own YAML-based detection rules
10. Multiple output formats — Text, JSON, SARIF for CI/CD integration

## Dependencies
- `bash` (4.0+)
- `curl`
- `unzip`
- ~100MB disk (binary + templates)

## Installation Time
**5 minutes** — One script installs everything

## Pricing Justification

**Why $15:**
- Commercial alternatives: $100-500/month (Snyk, Qualys, Tenable)
- Open-source Nuclei: Free, but requires setup knowledge
- Our skill: One-command install, agent-managed scanning, scheduled reports
- Complexity: Medium-high (binary install + template management + scheduled scans)
