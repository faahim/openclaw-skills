# Listing Copy: Rclone Cloud Storage Manager

## Metadata
- **Type:** Skill
- **Name:** rclone-cloud-storage
- **Display Name:** Rclone Cloud Storage Manager
- **Categories:** [data, automation]
- **Price:** $12
- **Dependencies:** [rclone, bash, cron]

## Tagline

Sync, backup, and mount 40+ cloud providers — S3, Google Drive, Dropbox, and more

## Description

Managing files across cloud providers shouldn't require a PhD in each provider's CLI. Whether you need nightly backups to Backblaze, bidirectional sync with Google Drive, or mounting S3 as a local folder — it's always a maze of auth tokens, cron jobs, and retention policies.

Rclone Cloud Storage Manager gives your OpenClaw agent full control over rclone — the Swiss Army knife of cloud storage. One-command installs, scripted remote configuration, automated backups with timestamped snapshots and smart retention, bidirectional sync, FUSE mounts, encrypted remotes, and storage usage reports.

**What it does:**
- 📤 One-way and bidirectional sync between any two locations
- 🔄 Scheduled backups with incremental snapshots and retention (daily/weekly/monthly)
- 📂 Mount remote storage as local directories via FUSE
- 🔐 Encrypted remotes for sensitive data at rest
- 📊 Storage usage reports by file type and size
- ⚡ Parallel transfers, bandwidth limiting, smart filtering
- 🔧 Non-interactive remote configuration (S3, SFTP, B2, and more)

Perfect for developers and sysadmins who need reliable cloud storage automation without wrestling with provider-specific tools.

## Core Capabilities

1. Multi-provider sync — Works with S3, Google Drive, Dropbox, Backblaze B2, OneDrive, SFTP, and 35+ more
2. Automated backups — Timestamped snapshots with configurable daily/weekly/monthly retention
3. Incremental transfers — Only uploads changed files, saving bandwidth and time
4. FUSE mounting — Access remote storage as local directories with caching
5. Encrypted remotes — Transparent encryption layer for any provider
6. Bidirectional sync — Keep two locations mirrored (like Dropbox)
7. Storage reports — Analyze usage by file type, size, and count
8. Filter system — Include/exclude patterns, filter files for precise control
9. Bandwidth control — Rate limiting and parallel transfer tuning
10. Cron-ready — One command to schedule recurring backups
11. Non-interactive setup — Script remote configuration without interactive prompts
12. Cloud-to-cloud — Transfer directly between providers without local intermediary
