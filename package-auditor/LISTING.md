# Listing Copy: Package Auditor

## Metadata
- **Type:** Skill
- **Name:** package-auditor
- **Display Name:** Package Auditor
- **Categories:** [security, dev-tools]
- **Icon:** 🔍
- **Dependencies:** [bash, jq]

## Tagline

Audit all package managers for outdated and vulnerable packages — one command, unified report.

## Description

Every server and dev machine accumulates packages across multiple managers — apt, brew, npm, pip, cargo. Each has its own update command, its own vulnerability scanner, its own output format. Keeping track of what needs updating across all of them is tedious and error-prone. Miss a security patch and you're exposed.

Package Auditor scans every package manager on your system in one command. It checks for outdated packages, known CVEs, and security updates, then generates a unified report. No external services, no accounts — it runs locally using the tools you already have installed.

**What it does:**
- 🔍 Scans apt, brew, npm, pip, and cargo in one pass
- 🛡️ Flags packages with known security vulnerabilities (CVEs)
- 📊 Generates text or JSON reports for tracking over time
- 🔧 Auto-generates a safe fix script you can review before running
- ⏰ Cron-ready with Telegram alerts on new vulnerabilities
- 🚦 CI/CD integration with exit codes for pipeline gates
- 📈 Compare reports over time to track improvement

Perfect for sysadmins, developers, and anyone running servers who wants a single-command security overview without subscribing to expensive monitoring services.

## Quick Start Preview

```bash
bash scripts/audit.sh
# Scans all detected package managers, outputs unified report

bash scripts/audit.sh --security-only --alert telegram
# Quick CVE check, alerts only if vulnerabilities found

bash scripts/audit.sh --fix-script > fix.sh && bash fix.sh
# Generate and run update script
```

## Core Capabilities

1. Multi-manager scanning — apt, brew, npm, pip, cargo detected automatically
2. Security-first mode — Check only for CVEs, skip version bumps
3. Fix script generation — Review-before-run update commands
4. JSON output — Machine-readable for automation and tracking
5. Report comparison — Track security posture over time
6. Telegram alerts — Get notified when new vulnerabilities appear
7. CI/CD exit codes — Fail pipelines on critical vulnerabilities
8. Ignore lists — Skip packages you manage separately
9. Per-project auditing — Scan specific project dependencies
10. Timeout protection — Won't hang on slow package managers
11. Single-manager mode — Audit just one manager when needed
12. Zero external dependencies — Uses only bash, jq, and your existing package managers
