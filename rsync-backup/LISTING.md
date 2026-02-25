# Listing Copy: Rsync Backup Manager

## Metadata
- **Type:** Skill
- **Name:** rsync-backup
- **Display Name:** Rsync Backup Manager
- **Categories:** [data, automation]
- **Price:** $12
- **Dependencies:** [rsync, bash, ssh, cron]
- **Icon:** 💾

## Tagline
Automated rsync backups with incremental snapshots, retention policies, and failure alerts

## Description

Manually backing up files is tedious and error-prone. Forgetting a backup means losing data — and restoring from a weeks-old copy is painful. You need automated, incremental backups that run reliably in the background.

Rsync Backup Manager automates file and directory backups using rsync — the fastest, most battle-tested sync tool on Linux and Mac. Configure backup jobs with a simple YAML file, schedule them via cron, and get Telegram or email alerts if anything fails. No external services, no monthly fees.

**What it does:**
- 💾 Back up local or remote directories via rsync + SSH
- 📸 Incremental snapshots using hard links (space-efficient)
- 🗓️ Configurable retention (keep last N snapshots)
- 🔔 Telegram/email alerts on backup failure
- ⏱️ Cron scheduling with one command
- 🔄 Pre/post scripts (database dumps, service restarts)
- ✅ Verify and restore from any snapshot
- 🌐 Bandwidth limiting for remote backups

Perfect for developers, sysadmins, and self-hosters who want reliable, automated backups without the complexity of enterprise tools like Bacula or the cost of cloud backup services.

## Quick Start Preview

```bash
# Back up a directory with snapshots
bash scripts/rsync-backup.sh \
  --source /var/www --dest /mnt/backup/www \
  --name website --snapshots --retain 30

# Install scheduled backups from config
bash scripts/rsync-backup.sh --install-cron --config config.yaml
```

## Core Capabilities

1. Local & remote backups — rsync over SSH with key authentication
2. Incremental snapshots — Hard-linked snapshots look like full copies, use minimal space
3. Configurable retention — Keep last N snapshots, auto-prune old ones
4. Failure alerts — Telegram and email notifications on backup errors
5. Cron scheduling — Install scheduled jobs with one command
6. Pre/post scripts — Run database dumps or service commands around backups
7. Bandwidth limiting — Rate-limit transfers for shared connections
8. Dry run mode — Preview changes before executing
9. Backup verification — Compare source and dest for integrity
10. Restore from any snapshot — Point-in-time recovery
11. YAML configuration — Manage multiple backup jobs in one file
12. Exclusion patterns — Skip node_modules, caches, temp files

## Installation Time
**5 minutes** — rsync is pre-installed on most systems. Copy config, run.

## Pricing Justification
- LarryBrain median: $10-15
- Comparable: rsnapshot (complex config), Duplicity (slow), cloud backup ($5-20/mo)
- One-time $12 vs monthly subscriptions
