# Listing Copy: Kopia Backup Manager

## Metadata
- **Type:** Skill
- **Name:** kopia-backup
- **Display Name:** Kopia Backup Manager
- **Categories:** [data, automation]
- **Icon:** 💾
- **Dependencies:** [bash, curl, kopia]

## Tagline

Fast, encrypted, deduplicated backups — local, S3, B2, GCS, or SFTP with one command.

## Description

Losing data is not a matter of if, but when. Whether it's a corrupted disk, accidental deletion, or ransomware, you need automated backups you can trust. Setting up reliable backup systems manually is tedious and error-prone.

Kopia Backup Manager installs and configures [Kopia](https://kopia.io), a modern open-source backup tool with client-side encryption, deduplication, and compression. Back up to local drives, S3, Backblaze B2, Google Cloud Storage, Azure, or any SFTP server. Schedule automatic snapshots, set retention policies, and verify backup integrity — all through your OpenClaw agent.

**What you get:**
- 💾 Encrypted, deduplicated backups to 10+ storage backends
- ⏱️ Scheduled snapshots with configurable retention (daily/weekly/monthly/yearly)
- 🔍 Integrity verification with content-level checks
- 🔔 Telegram alerts when backups fail or go stale
- 🖥️ Optional web UI for visual management
- 🔧 Pre/post snapshot hooks (database dumps, notifications)
- 📊 Health check reports with storage stats and dedup ratios

**Who it's for:** Developers, sysadmins, and self-hosters who want reliable, encrypted backups without enterprise complexity.

## Quick Start Preview

```bash
# Install Kopia
bash scripts/install.sh

# Create encrypted repository on S3
kopia repository create s3 --bucket my-backups --region us-east-1

# Snapshot home directory
kopia snapshot create /home

# Schedule every 6 hours with 7-day retention
kopia policy set /home --snapshot-interval 6h --keep-daily 7
```

## Core Capabilities

1. Multi-backend storage — Local filesystem, S3, B2, GCS, Azure, SFTP, rclone
2. Client-side encryption — AES-256-GCM, password never leaves your machine
3. Deduplication — Only store changed blocks, save 50-90% storage
4. Scheduled snapshots — Built-in intervals or cron-based scheduling
5. Retention policies — Keep N daily/weekly/monthly/yearly snapshots automatically
6. Integrity verification — Content-level checks to detect corruption early
7. Selective restore — Restore full snapshots or individual files
8. Compression — zstd, gzip, s2 — configurable per policy
9. Pre/post hooks — Dump databases before snapshot, notify after
10. Health monitoring — Automated checks with Telegram alerts on failure
11. Web UI — Optional browser-based management via kopia server
12. Cross-platform — Linux (amd64/arm64), macOS, Windows

## Dependencies
- `bash` (4.0+)
- `curl`
- `kopia` (installed by scripts/install.sh)
- Optional: `cron`, `jq`, Telegram bot token

## Installation Time
**5 minutes** — Run install script, create repository, take first snapshot.
