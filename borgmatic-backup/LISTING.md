# Listing Copy: Borgmatic Backup Manager

## Metadata
- **Type:** Skill
- **Name:** borgmatic-backup
- **Display Name:** Borgmatic Backup Manager
- **Categories:** [data, automation]
- **Icon:** 🗄️
- **Dependencies:** [borgbackup, borgmatic, cron]

## Tagline

Encrypted, deduplicated backups with Borg — set up once, sleep well forever.

## Description

Losing data is preventable. But setting up proper encrypted backups with deduplication, retention policies, and database dumps is tedious — and most people skip it until it's too late.

Borgmatic Backup Manager handles everything: install BorgBackup + Borgmatic, initialize encrypted repositories (local or remote via SSH), configure what to back up (files, PostgreSQL, MySQL, MongoDB, Docker volumes), set retention policies (daily/weekly/monthly/yearly), schedule via cron, and get Telegram alerts on failure. Deduplication means daily backups of 1TB might use only 50GB of storage.

**What it does:**
- 🔒 AES-256 encrypted backups with passphrase protection
- 📦 Deduplicated storage — only changes are saved, massive space savings
- 🗄️ Back up files, PostgreSQL, MySQL, and Docker volumes
- 🌐 Local or remote repositories via SSH
- 🔄 Configurable retention: keep N daily/weekly/monthly/yearly snapshots
- ⏰ Cron scheduling — set and forget
- 🔔 Telegram alerts on backup failure
- 🔍 Integrity verification with one command
- ♻️ Point-in-time restore of any archive
- 📊 Status dashboard showing repo size, dedup ratio, last run

Perfect for developers, sysadmins, and anyone running servers who needs reliable, encrypted backups without the complexity of enterprise solutions.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Init encrypted repo
bash scripts/run.sh init --repo /mnt/backup/borg --encryption repokey

# Configure
bash scripts/run.sh configure --repo /mnt/backup/borg --source /home,/etc --passphrase-file /root/.borg-pass --keep-daily 7

# Backup + schedule
bash scripts/run.sh backup
bash scripts/run.sh schedule --cron "0 2 * * *"
```

## Installation Time
**5 minutes** — install, init, configure, schedule
