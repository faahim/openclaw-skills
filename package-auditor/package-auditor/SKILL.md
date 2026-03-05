---
name: package-auditor
description: >-
  Audit installed system packages for known vulnerabilities, orphaned packages, and outdated dependencies. Supports apt, dnf, and brew.
categories: [security, automation]
dependencies: [bash, apt/dnf/brew]
---

# Package Auditor

## What This Does

Scans your system's installed packages to find known CVEs (vulnerabilities), orphaned/unused packages wasting disk space, and outdated packages with available updates. Generates a prioritized report with actionable fix commands.

**Example:** "Scan 847 installed packages, find 3 critical CVEs, 12 orphaned packages using 340MB, and 28 packages with updates available."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Debian/Ubuntu — install debsecan for CVE checking
sudo apt-get install -y debsecan apt-show-versions

# RHEL/Fedora — dnf has built-in security advisories
# No extra install needed

# macOS — brew has built-in outdated check
# No extra install needed
```

### 2. Run Full Audit

```bash
bash scripts/audit.sh
```

**Output:**
```
╔══════════════════════════════════════════╗
║         SYSTEM PACKAGE AUDIT            ║
║         2026-03-05 18:53 UTC            ║
╚══════════════════════════════════════════╝

📦 Total installed packages: 847

🔴 VULNERABILITIES (debsecan)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CRITICAL: 1 package(s)
    - openssl 3.0.2-0ubuntu1.12 → CVE-2024-XXXX (remote code execution)
  HIGH: 2 package(s)
    - curl 7.81.0 → CVE-2024-YYYY (MITM attack)
    - libxml2 2.9.13 → CVE-2024-ZZZZ (XXE injection)
  MEDIUM: 5 package(s)

🗑️ ORPHANED PACKAGES
━━━━━━━━━━━━━━━━━━━━
  12 orphaned packages found (340 MB total)
    - linux-headers-5.15.0-91 (128 MB)
    - linux-image-5.15.0-91 (95 MB)
    - libfoo-dev (12 MB)
  Run: sudo apt autoremove --purge

📥 AVAILABLE UPDATES
━━━━━━━━━━━━━━━━━━━━
  28 packages have updates available
    - Security updates: 8
    - Regular updates: 20
  Run: sudo apt upgrade

📊 SUMMARY
━━━━━━━━━━
  Risk score: 7.2/10 (ACTION NEEDED)
  Recommended: Fix critical CVEs immediately
```

### 3. Run Specific Checks

```bash
# Vulnerability scan only
bash scripts/audit.sh --vulns

# Orphaned packages only
bash scripts/audit.sh --orphans

# Outdated packages only
bash scripts/audit.sh --outdated

# JSON output (for automation)
bash scripts/audit.sh --json > audit-report.json

# Fix mode (generates fix commands)
bash scripts/audit.sh --fix
```

## Core Workflows

### Workflow 1: Security Vulnerability Scan

**Use case:** Check if any installed packages have known CVEs

```bash
bash scripts/audit.sh --vulns
```

On Debian/Ubuntu, uses `debsecan` to check against the Debian Security Tracker.
On RHEL/Fedora, uses `dnf updateinfo list --security`.

### Workflow 2: Disk Space Recovery

**Use case:** Find and remove orphaned packages eating disk space

```bash
bash scripts/audit.sh --orphans

# Preview what would be removed
bash scripts/audit.sh --orphans --dry-run

# Auto-remove (asks for confirmation)
bash scripts/audit.sh --orphans --clean
```

### Workflow 3: Scheduled Audit (Cron)

**Use case:** Run weekly audit, alert on critical findings

```bash
# Add to crontab — runs every Sunday at 3am
echo "0 3 * * 0 cd /path/to/package-auditor && bash scripts/audit.sh --json >> logs/audit-history.jsonl" | crontab -

# Or use OpenClaw cron
# Schedule: weekly
# Command: bash scripts/audit.sh --json
```

### Workflow 4: Before/After Comparison

**Use case:** Compare audit results over time

```bash
# Save baseline
bash scripts/audit.sh --json > baseline.json

# ... time passes, packages change ...

# Compare
bash scripts/audit.sh --diff baseline.json
```

## Configuration

### Environment Variables

```bash
# Severity threshold for alerts (critical, high, medium, low)
export AUDIT_MIN_SEVERITY="high"

# Output format (text, json, markdown)
export AUDIT_FORMAT="text"

# Skip specific packages from audit
export AUDIT_IGNORE="linux-headers-*,snapd"

# Log directory
export AUDIT_LOG_DIR="./logs"
```

## Advanced Usage

### Custom Ignore List

Create `config/ignore.txt`:
```
# Packages to skip in vulnerability reports
linux-headers-*
snapd
ubuntu-advantage-tools
```

### Integration with CI/CD

```bash
# Exit code 1 if critical CVEs found (useful in pipelines)
bash scripts/audit.sh --vulns --strict
echo $?  # 0 = clean, 1 = critical issues
```

### Export Formats

```bash
# Markdown report
bash scripts/audit.sh --format markdown > report.md

# JSON for programmatic use
bash scripts/audit.sh --json | jq '.vulnerabilities[] | select(.severity == "critical")'

# CSV for spreadsheets
bash scripts/audit.sh --format csv > report.csv
```

## Troubleshooting

### Issue: "debsecan: command not found"

```bash
sudo apt-get install -y debsecan
```

### Issue: "apt-show-versions: command not found"

```bash
sudo apt-get install -y apt-show-versions
```

### Issue: Slow scan on systems with many packages

The first `debsecan` run downloads the vulnerability database. Subsequent runs use cache.
```bash
# Force cache refresh
debsecan --update-db
```

## Dependencies

- `bash` (4.0+)
- `apt` / `dnf` / `brew` (auto-detected)
- `debsecan` (Debian/Ubuntu — for CVE scanning)
- `apt-show-versions` (Debian/Ubuntu — optional, for version checks)
- `jq` (optional — for JSON output)
