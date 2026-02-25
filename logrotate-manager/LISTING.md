# Listing Copy: Logrotate Manager

## Metadata
- **Type:** Skill
- **Name:** logrotate-manager
- **Display Name:** Logrotate Manager
- **Categories:** [automation, dev-tools]
- **Price:** $8
- **Dependencies:** [bash, logrotate]
- **Icon:** 🔄

## Tagline
Manage log rotation configs — prevent disk-full disasters before they happen

## Description

Servers die when logs fill the disk. It's one of the most common — and most preventable — outages. But setting up logrotate correctly means remembering arcane config syntax, testing without breaking production, and hoping you didn't miss a log directory.

Logrotate Manager gives your OpenClaw agent full control over log rotation. Create configs with simple flags, audit your entire server for unrotated or oversized logs, dry-run test before applying, and monitor log growth with configurable alerts. No more SSH-ing in to hand-edit `/etc/logrotate.d/` files.

**What it does:**
- 🔍 Audit all rotation configs and find unmanaged large logs
- ⚙️ Create new rotation configs with one command
- 🧪 Dry-run test configs before they go live
- 🔄 Force immediate rotation (pre-deployment, incident response)
- 📊 List all configs in a clean table view
- ⚠️ Monitor log sizes with threshold-based alerting
- 🗑️ Safely remove configs

Perfect for developers, sysadmins, and anyone running servers who wants their agent to handle log hygiene automatically.

## Quick Start Preview

```bash
# Audit current log rotation
bash scripts/logrotate-manager.sh audit

# Create rotation for app logs
bash scripts/logrotate-manager.sh create \
  --path "/var/log/myapp/*.log" \
  --name myapp --rotate 7 --compress --maxsize 100M

# Monitor for oversized logs
bash scripts/logrotate-manager.sh monitor --threshold 500M
```
