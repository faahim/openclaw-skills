# Listing Copy: Kopia Backup Manager

## Metadata
- **Type:** Skill
- **Name:** kopia-backup
- **Display Name:** Kopia Backup Manager
- **Categories:** [data, automation]
- **Price:** $12
- **Dependencies:** [bash, curl]

## Tagline

"Encrypted, deduplicated backups to S3, B2, SFTP, or local storage — set up in 5 minutes"

## Description

Manually copying files to an external drive isn't a backup strategy. And most backup tools are either too complex to set up or don't encrypt your data properly. You need automated, encrypted backups that just work.

Kopia Backup Manager installs and configures [Kopia](https://kopia.io) — a modern backup tool with built-in AES-256 encryption, block-level deduplication, and zstd compression. Back up to local drives, S3, Backblaze B2, SFTP, Google Cloud, or Azure Blob — all from one CLI. After the first full backup, only changed blocks are uploaded (saving bandwidth and storage).

**What it does:**
- 🔐 AES-256 encryption — data encrypted before leaving your machine
- 📦 Block-level deduplication — saves 50-90% storage over time
- ☁️ Multi-backend — S3, B2, SFTP, GCS, Azure, local
- ⏱️ Cron-ready automated backups with failure alerts
- 🗜️ zstd compression for smaller backups
- 📂 Mount snapshots as virtual filesystem for instant file browsing
- 🔄 Configurable retention (daily/weekly/monthly/annual)
- 📊 Telegram/ntfy/webhook notifications on failure

Perfect for developers, sysadmins, and self-hosters who want reliable encrypted backups without enterprise complexity.

## Quick Start Preview

```bash
# Install Kopia
bash scripts/install.sh

# Create repository
kopia repository create filesystem --path /backup/repo

# Back up
kopia snapshot create /home/user

# Restore
kopia restore <snapshot-id> /tmp/restored/
```

## Core Capabilities

1. One-command installation — auto-detects OS and architecture
2. Local backups — external drives, NAS, any mounted path
3. Cloud backups — S3, Backblaze B2, SFTP, GCS, Azure Blob
4. AES-256 encryption — zero-knowledge, data encrypted at rest
5. Block-level deduplication — only unique data stored
6. Incremental snapshots — first backup is full, rest are fast
7. Retention policies — keep N daily/weekly/monthly/annual snapshots
8. Cron automation — backup script with failure notifications
9. Snapshot mounting — browse backups as a virtual filesystem
10. Multi-notification — Telegram, ntfy, Slack webhook on failure

## Dependencies
- `bash` (4.0+)
- `curl`
- Kopia (installed by skill)

## Installation Time
**5 minutes**
