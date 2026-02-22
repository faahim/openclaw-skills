# Listing Copy: Cloud Sync & Backup

## Metadata
- **Type:** Skill
- **Name:** cloud-sync-backup
- **Display Name:** Cloud Sync & Backup
- **Categories:** [data, automation]
- **Price:** $12
- **Dependencies:** [rclone, bash, cron, gpg]

## Tagline

"Sync and backup files to any cloud storage — encrypted, compressed, scheduled."

## Description

Losing data is painful and entirely preventable. But setting up reliable cloud backups with encryption, compression, and retention policies is tedious — especially when you're juggling S3 credentials, cron syntax, and rclone flags.

Cloud Sync & Backup gives your OpenClaw agent everything it needs to manage automated backups to 40+ cloud storage providers. One command to install rclone, one command to configure a remote, one command to schedule encrypted nightly backups with automatic pruning. Works with AWS S3, Backblaze B2, Google Drive, Dropbox, DigitalOcean Spaces, Cloudflare R2, SFTP, and more.

**What it does:**
- ☁️ Sync files to any rclone-supported cloud provider (40+)
- 📦 Compressed backups (tar.gz) to minimize storage costs
- 🔐 AES-256 encrypted archives for sensitive data
- ⏰ Scheduled backups via cron (nightly, hourly, weekly)
- 🗑️ Automatic pruning with configurable retention policies
- 🔄 Restore from any backup with one command
- 📊 List, inspect, and manage remote backups
- 🔔 Telegram alerts on backup success/failure
- ⚙️ Pre/post commands (database dumps, service stops, cleanup)

Perfect for developers, sysadmins, and anyone who needs reliable automated backups without managing complex backup infrastructure.

## Core Capabilities

1. Multi-provider support — AWS S3, B2, GDrive, Dropbox, DO Spaces, R2, SFTP, and 30+ more
2. One-command setup — Install rclone + configure remote in under 5 minutes
3. Compressed backups — tar.gz archives reduce storage costs by 50-80%
4. AES-256 encryption — GPG-encrypted archives for sensitive data
5. Scheduled automation — Cron-based scheduling with zero maintenance
6. Retention policies — Auto-prune backups older than N days
7. Database backups — Pre-command hooks for pg_dump, mysqldump, mongodump
8. Bandwidth limiting — Control upload speed to avoid saturating your connection
9. Restore with one command — Download, decrypt, extract in one step
10. Telegram alerts — Get notified on backup success or failure
11. Dry-run mode — Preview what would happen without making changes
12. Exclude patterns — Skip node_modules, .git, logs, temp files

## Dependencies
- `rclone` (auto-installed by install.sh)
- `bash` (4.0+)
- `tar` + `gzip`
- `gpg` (for encryption)
- `cron` (for scheduling)

## Installation Time
**5 minutes** — Install rclone, configure remote, run first backup
