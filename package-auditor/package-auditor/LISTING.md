# Listing Copy: Package Auditor

## Metadata
- **Type:** Skill
- **Name:** package-auditor
- **Display Name:** Package Auditor
- **Categories:** [security, automation]
- **Price:** $8
- **Dependencies:** [bash, debsecan, jq]

## Tagline

Audit system packages for CVEs, orphans, and outdated deps — one command, full report.

## Description

Knowing what's installed on your server is easy. Knowing what's *vulnerable* is harder. Manually cross-referencing installed packages against CVE databases, hunting for orphaned dependencies eating disk space, and tracking which updates are security-critical vs routine — that's hours of work nobody does regularly enough.

Package Auditor runs a comprehensive scan of your system's installed packages in under a minute. It checks for known vulnerabilities using debsecan (Debian/Ubuntu) or dnf security advisories (RHEL/Fedora), identifies orphaned packages you can safely remove, and lists all available updates with security fixes highlighted.

**What it does:**
- 🔴 Scan for known CVEs with severity ratings (critical/high/medium/low)
- 🗑️ Find orphaned packages wasting disk space, with one-command cleanup
- 📥 List available updates, separating security fixes from routine updates
- 📊 Generate a risk score (0-10) with prioritized fix commands
- 🔄 Schedule weekly audits via cron with JSON history logging
- 📋 Export reports as text, JSON, Markdown, or CSV

Perfect for sysadmins, developers with production servers, and anyone running Linux who wants to stay on top of security without the manual grind.

## Quick Start Preview

```bash
# Full audit in one command
bash scripts/audit.sh

# Vulnerability scan only
bash scripts/audit.sh --vulns

# Find and clean orphaned packages
bash scripts/audit.sh --orphans --clean
```

## Core Capabilities

1. CVE vulnerability scanning — checks every installed package against known vulnerability databases
2. Orphaned package detection — finds unused dependencies wasting disk space
3. Update classification — separates security updates from routine package updates
4. Risk scoring — 0-10 risk score based on vulnerability severity and count
5. Multi-distro support — works with apt (Debian/Ubuntu), dnf (RHEL/Fedora), and brew (macOS)
6. JSON output — pipe to jq, log to files, integrate with monitoring
7. Ignore lists — skip known-safe packages via config file or environment variable
8. Strict mode — exit code 1 on critical CVEs (perfect for CI/CD pipelines)
9. Diff mode — compare current scan against a baseline to track changes
10. Auto-cleanup — remove orphaned packages with confirmation prompt

## Dependencies
- `bash` (4.0+)
- `debsecan` (Debian/Ubuntu) or `dnf` (RHEL/Fedora) or `brew` (macOS)
- `jq` (optional, for JSON output)

## Installation Time
**2 minutes** — run install.sh, then audit.sh
