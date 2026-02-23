# Listing Copy: Auto-Update Manager

## Metadata
- **Type:** Skill
- **Name:** auto-update-manager
- **Display Name:** Auto-Update Manager
- **Categories:** [security, automation]
- **Price:** $10
- **Dependencies:** [bash, apt, systemd]
- **Icon:** 🛡️

## Tagline

Automated security updates for Linux — patch vulnerabilities while you sleep

## Description

Unpatched servers are the #1 attack vector. But manually running `apt upgrade` across your servers is tedious, error-prone, and easy to forget. One missed critical patch can mean a compromised system.

Auto-Update Manager configures `unattended-upgrades` on Debian/Ubuntu servers with a single command. It handles security-only updates, email notifications on changes, automatic maintenance reboots during safe windows, package blacklisting, and update history tracking. No external services — everything runs locally via systemd.

**What it does:**
- 🛡️ Auto-apply security patches daily (configurable schedule)
- 📧 Email notifications when updates are applied or fail
- 🔄 Optional auto-reboot at scheduled maintenance window
- 🚫 Blacklist packages you don't want touched (Docker, kernel, etc.)
- 📊 Status checks with JSON output for monitoring integration
- 📜 Update history and audit trail
- 🖥️ Multi-server config generation for fleet management
- ⚡ Force-apply pending updates on demand

## Quick Start

```bash
# Check current state
bash scripts/auto-update.sh status

# Full setup with auto-reboot at 4am
sudo bash scripts/auto-update.sh setup --auto-reboot --reboot-time "04:00" --email admin@example.com
```

## Core Capabilities

1. One-command setup — Install and configure unattended-upgrades in 30 seconds
2. Security-only mode — Only apply security patches, skip feature updates
3. Package blacklisting — Prevent Docker, kernel, or any package from auto-updating
4. Auto-reboot scheduling — Reboot at 4am Sunday, not during business hours
5. Email alerts — Know when updates are applied or fail
6. JSON status output — Integrate with OpenClaw cron for monitoring
7. Update history — Full audit trail of what was updated and when
8. Multi-server support — Generate config scripts for remote deployment
9. Force-apply — Push pending security updates immediately when needed
10. Reboot detection — Know instantly if a reboot is required

## Dependencies
- bash (4.0+)
- apt (Debian/Ubuntu)
- systemd
- unattended-upgrades (auto-installed)

## Installation Time
**30 seconds** — Run setup, done.

## Supported Systems
Ubuntu 18.04+, Debian 10+, Linux Mint 20+
