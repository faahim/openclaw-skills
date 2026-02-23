# Listing Copy: Lynis Security Auditor

## Metadata
- **Type:** Skill
- **Name:** lynis-auditor
- **Display Name:** Lynis Security Auditor
- **Categories:** [security, automation]
- **Price:** $12
- **Dependencies:** [bash, lynis, jq]
- **Icon:** 🛡️

## Tagline

"Run Linux security audits with Lynis — get prioritized hardening fixes instantly"

## Description

Manually checking your server's security posture is slow and error-prone. You miss misconfigurations, outdated packages, and weak SSH settings until it's too late. You need automated, repeatable security auditing.

Lynis Security Auditor installs and runs [Lynis](https://cisofy.com/lynis/) — the industry-standard open-source security tool — then parses raw output into prioritized, actionable reports. No more reading 500-line audit logs. Get a hardening score, top fixes ranked by severity, and auto-generated remediation scripts.

**What it does:**
- 🔍 Full system security audit in one command
- 📊 Hardening score (0-100) with trend tracking
- 🔴 Prioritized fix list — critical items first
- 🔧 Auto-generated remediation scripts
- 📂 Category-specific audits (SSH, firewall, auth, etc.)
- ⏰ Cron-ready with Telegram/email alerts
- 📈 Track progress over time — see your score improve
- 🏢 CIS benchmark and compliance checks (HIPAA, PCI-DSS)

**Who it's for:** Developers, sysadmins, and indie hackers who want to keep their servers secure without hiring a security consultant.

## Quick Start Preview

```bash
# Install Lynis
bash scripts/install.sh

# Run full audit
sudo bash scripts/run.sh --audit

# Output:
# 📊 Hardening Index: 67/100
# ⚠️  Warnings: 3
# 🔴 CRITICAL:
#   1. [SSH-7408] SSH root login is permitted
#   2. [FIRE-4590] iptables has no active rules
```

## Core Capabilities

1. Full system audit — Check 300+ security tests across all system components
2. Hardening score — Get a 0-100 score showing your security posture
3. Prioritized fixes — Critical warnings first, then suggestions
4. Remediation scripts — Auto-generated bash scripts to fix issues
5. Category audits — Focus on SSH, firewall, auth, kernel, etc.
6. Progress tracking — Compare scores across audits, see improvement
7. Cron scheduling — Weekly automated audits with alerting
8. Telegram/email alerts — Get notified of critical findings
9. CIS benchmarks — Check against industry compliance standards
10. Cross-platform — Ubuntu, Debian, RHEL, Fedora, Arch, macOS

## Dependencies
- `bash` (4.0+)
- `lynis` (auto-installed)
- `jq`
- `sudo` (for system auditing)

## Installation Time
**5 minutes** — auto-installer handles everything
