# Listing Copy: Database Backup

## Metadata
- **Type:** Skill
- **Name:** database-backup
- **Display Name:** Database Backup
- **Categories:** [data, automation]
- **Price:** $15
- **Dependencies:** [bash, gzip, pg_dump/mysqldump/mongodump]

## Tagline

Automated database backups with compression, rotation, and cloud upload

## Description

Losing a database is one of those things that only happens once — because after that, you set up automated backups. But configuring dump scripts, compression, rotation policies, and cloud uploads from scratch is tedious and error-prone.

Database Backup handles the entire backup lifecycle for PostgreSQL, MySQL, and MongoDB. One config file, one script — it dumps your databases, compresses with gzip, rotates old backups based on your retention policy, and uploads to S3, GCS, or Backblaze B2. Set it up once with cron and forget about it.

**What it does:**
- 🐘 PostgreSQL, MySQL, and MongoDB support (single DB or all databases)
- 🗜️ Automatic gzip compression
- 🔄 Retention-based rotation (delete backups older than N days)
- ☁️ Upload to AWS S3, Google Cloud Storage, or Backblaze B2
- 🔐 Optional GPG encryption for sensitive data
- 🔔 Webhook/Telegram notifications on success or failure
- ⏰ One-command cron installation for scheduled backups
- 🪝 Pre/post backup hooks for custom workflows
- 📋 Restore instructions included

## Quick Start Preview

```bash
# Back up a Postgres database
bash scripts/run.sh --type postgres --host localhost --user myuser --database mydb --output /backups

# [2026-02-21 12:00:00] 🔄 Starting backup: mydb (postgres)
# [2026-02-21 12:00:05] ✅ Dumped: mydb → /backups/mydb_2026-02-21_120000.sql.gz (2.3 MB)
# [2026-02-21 12:00:05] ✅ Backup complete (5s)
```

## Installation Time
**5 minutes** — Configure env file, run script
