# Listing Copy: Restic Backup Manager

## Metadata
- **Type:** Skill
- **Name:** restic-backup
- **Display Name:** Restic Backup Manager
- **Categories:** [data, automation]
- **Icon:** 💾
- **Dependencies:** [restic, bash, cron]

## Tagline

Encrypted, deduplicated backups to S3, B2, SFTP & more — automated with retention policies.

## Description

Losing data is not a matter of if, but when. Whether it's a corrupted disk, accidental deletion, or ransomware — if you don't have automated backups, you're gambling with your files.

Restic Backup Manager installs and configures restic, the gold standard for encrypted, deduplicated backups. Point it at your directories and a storage backend (local disk, AWS S3, Backblaze B2, SFTP, or REST server), and it handles the rest: initial repo setup, scheduled backups via cron, intelligent retention policies (keep 7 daily, 4 weekly, 12 monthly), integrity checks, and restore operations. Telegram alerts on failure so you know immediately when something breaks.

**What it does:**
- 💾 Back up any directory to any backend (S3, B2, SFTP, local, REST)
- 🔐 AES-256 encryption — your backups are unreadable without the password
- 📦 Deduplication — only new/changed data is stored (saves 80%+ space)
- ⏰ Automated cron scheduling with retention policies
- 🔔 Telegram alerts on backup failures
- 🔄 Restore files from any snapshot (full or partial)
- 🔍 Repository integrity checks
- 🗄️ Mount snapshots as browseable filesystem
- 🔧 Pre-backup hooks (database dumps before backup)
- 📊 Bandwidth limiting for remote backends

Perfect for developers, sysadmins, and anyone who values their data. Follows the 3-2-1 backup rule: 3 copies, 2 media types, 1 offsite.

## Core Capabilities

1. Multi-backend support — S3, Backblaze B2, SFTP, local disk, REST server
2. AES-256 encryption — Zero-knowledge, password-protected backups
3. Content-defined deduplication — Only stores unique data chunks
4. Automated scheduling — Cron-based with configurable intervals
5. Smart retention — Keep N daily/weekly/monthly/yearly snapshots
6. Instant restore — Full snapshot or specific files
7. Integrity verification — Detect corruption before you need the backup
8. Pre-backup hooks — Dump databases before backing up
9. Failure alerts — Telegram notification on backup errors
10. Browseable snapshots — Mount backups as filesystem to browse

## Installation Time
**5 minutes** — Install restic, init repo, run first backup
