# Listing Copy: File Integrity Monitor

## Metadata
- **Type:** Skill
- **Name:** file-integrity-monitor
- **Display Name:** File Integrity Monitor
- **Categories:** [security, automation]
- **Icon:** 🛡️
- **Dependencies:** [bash, sha256sum, find, curl]

## Tagline

Monitor files for unauthorized changes — Get instant alerts on modifications

## Description

Your server's config files shouldn't change without you knowing. A modified `/etc/passwd`, an injected backdoor in your web root, or a tampered SSH key can go unnoticed for weeks. By then, the damage is done.

File Integrity Monitor watches your critical files and directories using SHA-256 checksums. Create a baseline, then scan periodically — any modification, addition, or deletion triggers an instant alert via Telegram, email, or webhook. Think AIDE/Tripwire, but in pure bash with zero dependencies beyond coreutils.

**What it does:**
- 🔍 Baseline & scan directories with SHA-256 hashing
- ⚠️ Detect modified, added, and deleted files instantly
- 🔔 Alert via Telegram, webhook, or email
- 📊 Generate integrity reports and export to JSON/CSV
- 🔐 Monitor permissions and ownership changes
- ⏱️ Cron-ready — schedule checks every 5, 15, or 60 minutes
- 🗂️ Configurable exclusions for logs, temp files, caches
- 💾 Snapshot baselines for point-in-time comparison

Perfect for sysadmins, developers, and security-conscious users who need file monitoring without enterprise complexity or monthly SaaS fees.

## Core Capabilities

1. SHA-256 file hashing — Cryptographic verification of file contents
2. Change detection — Identifies modified, added, and deleted files
3. Multi-path monitoring — Watch /etc, /usr/bin, web roots, SSH keys simultaneously
4. Telegram alerts — Instant notification when files change
5. Webhook integration — Send alerts to Slack, Discord, or any endpoint
6. JSON/CSV export — Process results programmatically
7. Configurable exclusions — Skip logs, temp files, caches
8. Permission tracking — Detect ownership and permission changes
9. Baseline snapshots — Compare any two points in time
10. Zero dependencies — Pure bash + coreutils, works everywhere

## Installation Time
**3 minutes** — No installation needed, just run the script
