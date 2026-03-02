# Listing Copy: AIDE Intrusion Detection

## Metadata
- **Type:** Skill
- **Name:** aide-intrusion-detection
- **Display Name:** AIDE Intrusion Detection
- **Categories:** [security, automation]
- **Icon:** 🛡️
- **Dependencies:** [aide, bash, cron, curl]

## Tagline

Detect unauthorized file changes — know instantly when system files are modified

## Description

Someone modifies `/etc/passwd` on your server at 3am. A rogue cron job appears in `/etc/cron.d`. A binary in `/usr/bin` changes without a package update. How long until you notice?

**AIDE Intrusion Detection** creates a cryptographic snapshot of your system files and alerts you the moment anything changes. It monitors binaries, configs, SSH keys, and web files — catching unauthorized modifications, suspicious new files, and unexpected deletions.

**What it does:**
- 🔒 Creates SHA-256 baseline of critical system files
- 🔍 Detects added, modified, and deleted files
- 📱 Instant alerts via Telegram, email, or webhook
- ⏰ Automated checks via cron (every 1-24 hours)
- 📊 JSON output for automation pipelines
- 🎯 Monitor specific directories or full system
- 💾 Baseline versioning with automatic backups

**Perfect for** sysadmins, self-hosters, and anyone running production servers who needs to know when files change unexpectedly. 5-minute setup, zero ongoing maintenance.

## Quick Start Preview

```bash
# Install AIDE
bash scripts/install.sh

# Create baseline snapshot
bash scripts/run.sh init

# Check for changes (run manually or via cron)
bash scripts/run.sh check --alert

# Schedule automatic checks every 6 hours
bash scripts/run.sh schedule --interval 6h --alert
```

## Core Capabilities

1. File integrity monitoring — SHA-256 hashing of system binaries, configs, and critical files
2. Change detection — Identifies added, modified, and removed files since baseline
3. Attribute tracking — Monitors permissions, ownership, size, timestamps, and content hashes
4. Multi-channel alerts — Telegram, email, Slack webhook, custom endpoints
5. Automated scheduling — Cron-based checks from hourly to daily
6. Custom monitoring paths — Watch specific directories or full system
7. Baseline management — Init, update, and rollback with timestamped backups
8. JSON output — Machine-readable reports for automation
9. Configurable rules — Hash-only (fast), permissions-only, or full attribute check
10. Zero dependencies — Uses standard Linux tools (AIDE, bash, cron)
