---
name: package-auditor
description: >-
  Audit all package managers for outdated, vulnerable, and unused packages.
  Generates a unified security report across apt, brew, npm, pip, and cargo.
categories: [security, dev-tools]
dependencies: [bash, jq]
---

# Package Auditor

## What This Does

Scans every package manager on your system — apt, brew, npm (global + per-project), pip, and cargo — for outdated packages, known vulnerabilities, and unused dependencies. Outputs a unified report with severity ratings and one-command fixes.

**Example:** "Scan my server, find 12 outdated apt packages (3 with CVEs), 8 outdated npm globals, generate a fix script."

## Quick Start (2 minutes)

### 1. Run Full Audit

```bash
bash scripts/audit.sh
```

**Output:**
```
╔══════════════════════════════════════════════════╗
║           PACKAGE AUDIT REPORT                   ║
║           2026-03-01 18:53 UTC                   ║
╠══════════════════════════════════════════════════╣

📦 APT (Debian/Ubuntu)
  Installed: 342 packages
  Outdated:  12 packages
  Security:  3 packages with pending security updates
  ├── libssl3      3.0.13-1  → 3.0.14-1  [CVE-2024-5535]
  ├── curl         8.5.0-2   → 8.7.1-1   [CVE-2024-2398]
  └── openssh-server 9.6p1-3 → 9.7p1-1   [CVE-2024-6387]

🍺 HOMEBREW
  Installed: 87 packages
  Outdated:  5 packages
  ├── node     21.6.1 → 22.0.0
  ├── python   3.12.1 → 3.12.3
  └── ...

📦 NPM (Global)
  Installed: 23 packages
  Outdated:  8 packages
  Vulnerable: 2 packages (npm audit)
  ├── typescript  5.3.3 → 5.4.5
  └── ...

🐍 PIP
  Installed: 45 packages
  Outdated:  6 packages

🦀 CARGO
  Installed: 12 packages
  Outdated:  3 packages

══════════════════════════════════════════════════
SUMMARY: 34 outdated | 5 vulnerable | 5 managers scanned
══════════════════════════════════════════════════
```

### 2. Security-Only Scan (Fast)

```bash
bash scripts/audit.sh --security-only
```

Only checks for known CVEs and security updates. Skips version comparison for non-security packages.

### 3. Generate Fix Script

```bash
bash scripts/audit.sh --fix-script > fix.sh
chmod +x fix.sh
# Review fix.sh, then:
bash fix.sh
```

Generates a safe update script you can review before running.

## Core Workflows

### Workflow 1: Full System Audit

**Use case:** Weekly check of all package health

```bash
bash scripts/audit.sh --output json > audit-report.json
```

Outputs machine-readable JSON for tracking over time.

### Workflow 2: Security Audit Only

**Use case:** Quick CVE check before deploying

```bash
bash scripts/audit.sh --security-only --output text
```

### Workflow 3: Single Manager Audit

**Use case:** Check only npm packages

```bash
bash scripts/audit.sh --only npm
bash scripts/audit.sh --only apt
bash scripts/audit.sh --only pip
bash scripts/audit.sh --only brew
bash scripts/audit.sh --only cargo
```

### Workflow 4: Project Dependency Audit

**Use case:** Audit a specific project's node_modules

```bash
bash scripts/audit.sh --project /path/to/your/project
```

Runs `npm audit` / `pip-audit` in the project directory.

### Workflow 5: Scheduled Audit with Alerts

**Use case:** Daily security check via cron

```bash
# Add to crontab
0 8 * * * cd /path/to/skill && bash scripts/audit.sh --security-only --alert telegram 2>&1 >> /var/log/package-audit.log
```

Only sends alert if vulnerabilities are found.

## Configuration

### Environment Variables

```bash
# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="<your-bot-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"

# Ignore specific packages (comma-separated)
export AUDIT_IGNORE="linux-headers,linux-image"

# Set severity threshold (low, medium, high, critical)
export AUDIT_MIN_SEVERITY="medium"
```

### Ignore File

Create `.audit-ignore` in the skill directory:

```
# Packages to skip (one per line)
linux-headers-*
linux-image-*
snapd
```

## Advanced Usage

### Compare Audits Over Time

```bash
# Save today's audit
bash scripts/audit.sh --output json > audits/$(date +%Y-%m-%d).json

# Compare with yesterday
bash scripts/compare.sh audits/2026-02-28.json audits/2026-03-01.json
```

### Custom Package Managers

Add support for additional managers by creating scripts in `scripts/managers/`:

```bash
# scripts/managers/flatpak.sh
audit_flatpak() {
  flatpak update --appstream 2>/dev/null
  flatpak remote-ls --updates 2>/dev/null | while read line; do
    echo "$line"
  done
}
```

### CI/CD Integration

```bash
# Exit with code 1 if critical vulnerabilities found
bash scripts/audit.sh --security-only --fail-on critical
echo $?  # 0 = clean, 1 = vulnerabilities found
```

## Troubleshooting

### Issue: "apt: command not found"

Not on Debian/Ubuntu. The auditor skips unavailable managers automatically.

### Issue: npm audit takes too long

Use `--timeout 30` to limit each manager's scan time:

```bash
bash scripts/audit.sh --timeout 30
```

### Issue: pip packages show false positives

Some system-managed pip packages (installed via apt) may show as outdated. Add them to `.audit-ignore`.

## Dependencies

- `bash` (4.0+)
- `jq` (JSON output)
- Detected automatically: `apt`, `brew`, `npm`, `pip`/`pip3`, `cargo`
- Optional: `curl` (for Telegram alerts)
