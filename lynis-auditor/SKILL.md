---
name: lynis-auditor
description: >-
  Run comprehensive Linux security audits with Lynis — get actionable hardening recommendations with prioritized fixes.
categories: [security, automation]
dependencies: [bash, lynis, jq]
---

# Lynis Security Auditor

## What This Does

Automates Linux security auditing using [Lynis](https://cisofy.com/lynis/), the industry-standard open-source security tool. Installs Lynis, runs comprehensive system scans, parses raw output into prioritized actionable reports, and tracks hardening progress over time.

**Example:** "Audit this server, show me the top 10 security fixes ranked by severity, and track my hardening score week-over-week."

## Quick Start (5 minutes)

### 1. Install Lynis

```bash
bash scripts/install.sh
```

This auto-detects your OS and installs Lynis via package manager or from source.

### 2. Run Your First Audit

```bash
sudo bash scripts/run.sh --audit
```

**Output:**
```
🔍 Running Lynis security audit...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Hardening Index: 67/100
⚠️  Warnings: 3
💡 Suggestions: 24

🔴 CRITICAL (fix these first):
  1. [AUTH-9262] No password hashing rounds configured
  2. [FIRE-4590] iptables has no active rules
  3. [SSH-7408] SSH root login is permitted

🟡 IMPORTANT:
  4. [KRNL-5820] Core dump not disabled
  5. [FILE-6310] No AIDE/Tripwire file integrity monitoring
  ...

📁 Full report: /var/log/lynis-report.dat
📁 Parsed report: ./reports/2026-02-23.json
```

### 3. Track Progress Over Time

```bash
bash scripts/run.sh --compare
```

**Output:**
```
📈 Hardening Progress:
  2026-02-16: 52/100 (baseline)
  2026-02-19: 61/100 (+9 after SSH hardening)
  2026-02-23: 67/100 (+6 after firewall setup)

🎯 Next milestone: 75/100 — fix 3 more critical items
```

## Core Workflows

### Workflow 1: Full Security Audit

```bash
sudo bash scripts/run.sh --audit
```

Runs a complete Lynis audit and parses results into:
- Hardening score (0-100)
- Critical/warning/suggestion counts
- Prioritized fix list with remediation commands
- JSON report for programmatic access

### Workflow 2: Category-Specific Audit

```bash
# Audit only SSH configuration
sudo bash scripts/run.sh --audit --category ssh

# Audit only firewall rules
sudo bash scripts/run.sh --audit --category firewall

# Audit only authentication settings
sudo bash scripts/run.sh --audit --category authentication
```

Available categories: `authentication`, `boot`, `crypto`, `dns`, `firewall`, `kernel`, `logging`, `mail`, `networking`, `php`, `scheduler`, `shell`, `snmp`, `ssh`, `storage`, `time`, `webserver`

### Workflow 3: Generate Remediation Script

```bash
sudo bash scripts/run.sh --audit --fix-script
```

**Output:** Generates `./reports/remediation.sh` with commands to fix discovered issues:

```bash
#!/bin/bash
# Auto-generated remediation script — review before running!

# [SSH-7408] Disable SSH root login
sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart sshd

# [AUTH-9262] Configure password hashing rounds
echo "SHA_CRYPT_MIN_ROUNDS 5000" >> /etc/login.defs
echo "SHA_CRYPT_MAX_ROUNDS 10000" >> /etc/login.defs

# [FIRE-4590] Enable basic iptables rules
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -j DROP
iptables-save > /etc/iptables/rules.v4
```

### Workflow 4: Scheduled Audits (Cron)

```bash
# Run weekly audit, save reports
sudo bash scripts/run.sh --audit --cron

# Compare last 4 audits
bash scripts/run.sh --compare --last 4
```

Add to crontab:
```bash
0 3 * * 0 cd /path/to/lynis-auditor && sudo bash scripts/run.sh --audit --cron >> logs/audit.log 2>&1
```

### Workflow 5: Compliance Check

```bash
# Check against CIS benchmarks
sudo bash scripts/run.sh --audit --profile cis

# Check against specific compliance framework
sudo bash scripts/run.sh --audit --compliance hipaa
sudo bash scripts/run.sh --audit --compliance pci-dss
```

## Configuration

### Environment Variables

```bash
# Custom report directory (default: ./reports)
export LYNIS_REPORT_DIR="/path/to/reports"

# Telegram alerts for critical findings
export TELEGRAM_BOT_TOKEN="<token>"
export TELEGRAM_CHAT_ID="<chat-id>"

# Email alerts
export ALERT_EMAIL="admin@example.com"
```

### Lynis Profile Customization

Edit `scripts/custom.prf` to skip specific tests:

```ini
# Skip tests that don't apply
skip-test=USB-1000
skip-test=STRG-1846

# Set audit level
config:test_skip_always=yes
```

## Troubleshooting

### Issue: "lynis: command not found"

```bash
# Re-run installer
bash scripts/install.sh

# Or install manually
# Ubuntu/Debian
sudo apt-get install -y lynis

# RHEL/CentOS/Fedora
sudo dnf install -y lynis

# From source (any Linux)
cd /tmp && git clone https://github.com/CISOfy/lynis.git && sudo mv lynis /opt/lynis
sudo ln -s /opt/lynis/lynis /usr/local/bin/lynis
```

### Issue: "Permission denied"

Lynis needs root for a full audit:
```bash
sudo bash scripts/run.sh --audit
```

### Issue: Old Lynis version

```bash
lynis --version
# If < 3.0, update:
bash scripts/install.sh --force
```

## Dependencies

- `bash` (4.0+)
- `lynis` (3.0+ — auto-installed by install.sh)
- `jq` (JSON parsing)
- `sudo` (for system-level auditing)
- Optional: `awk`, `sed` (report parsing — usually pre-installed)
