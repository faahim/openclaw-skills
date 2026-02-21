---
name: database-backup
description: >-
  Automated database backups with compression, rotation, and cloud upload for PostgreSQL, MySQL, and MongoDB.
categories: [data, automation]
dependencies: [bash, gzip]
---

# Database Backup

## What This Does

Automates database backups for PostgreSQL, MySQL, and MongoDB. Dumps databases, compresses with gzip, rotates old backups, and optionally uploads to S3/GCS/B2. Runs standalone or via cron for scheduled backups.

**Example:** "Back up my Postgres database every 6 hours, keep 7 days of backups, upload to S3."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# PostgreSQL
which pg_dump || sudo apt-get install -y postgresql-client

# MySQL
which mysqldump || sudo apt-get install -y mysql-client

# MongoDB
which mongodump || sudo apt-get install -y mongodb-database-tools

# Cloud upload (optional)
which aws || pip3 install awscli        # For S3
which gsutil || pip3 install gsutil     # For GCS
which b2 || pip3 install b2             # For Backblaze B2
```

### 2. Configure

```bash
# Copy and edit config
cp scripts/config-template.env backup.env

# Edit backup.env with your database connection details
# See Configuration section below
```

### 3. Run First Backup

```bash
# Single database backup
bash scripts/run.sh --env backup.env

# Output:
# [2026-02-21 12:00:00] 🔄 Starting backup: mydb (postgres)
# [2026-02-21 12:00:05] ✅ Dumped: mydb → /backups/mydb_2026-02-21_120000.sql.gz (2.3 MB)
# [2026-02-21 12:00:07] ☁️  Uploaded to s3://my-backups/mydb_2026-02-21_120000.sql.gz
# [2026-02-21 12:00:07] 🗑️  Rotated: removed 2 backups older than 7 days
# [2026-02-21 12:00:07] ✅ Backup complete (7s)
```

## Core Workflows

### Workflow 1: PostgreSQL Backup

```bash
# Quick one-liner (no config file needed)
bash scripts/run.sh \
  --type postgres \
  --host localhost \
  --port 5432 \
  --user myuser \
  --password mypass \
  --database mydb \
  --output /backups
```

### Workflow 2: MySQL Backup

```bash
bash scripts/run.sh \
  --type mysql \
  --host localhost \
  --port 3306 \
  --user root \
  --password mypass \
  --database mydb \
  --output /backups
```

### Workflow 3: MongoDB Backup

```bash
bash scripts/run.sh \
  --type mongo \
  --host localhost \
  --port 27017 \
  --database mydb \
  --output /backups
```

### Workflow 4: Backup All Databases

```bash
# Postgres: dump all databases
bash scripts/run.sh --type postgres --host localhost --user myuser --all-databases --output /backups

# MySQL: dump all databases
bash scripts/run.sh --type mysql --host localhost --user root --all-databases --output /backups
```

### Workflow 5: Backup + Upload to S3

```bash
bash scripts/run.sh \
  --type postgres \
  --host localhost \
  --user myuser \
  --database mydb \
  --output /backups \
  --upload s3 \
  --bucket my-backup-bucket \
  --prefix db-backups/
```

### Workflow 6: Scheduled Backups via Cron

```bash
# Every 6 hours
0 */6 * * * cd /path/to/skill && bash scripts/run.sh --env backup.env >> /var/log/db-backup.log 2>&1

# Daily at 2 AM
0 2 * * * cd /path/to/skill && bash scripts/run.sh --env backup.env >> /var/log/db-backup.log 2>&1

# Install crontab entry automatically
bash scripts/run.sh --install-cron "0 */6 * * *" --env backup.env
```

### Workflow 7: Restore from Backup

```bash
# PostgreSQL
gunzip -c /backups/mydb_2026-02-21_120000.sql.gz | psql -h localhost -U myuser mydb

# MySQL
gunzip -c /backups/mydb_2026-02-21_120000.sql.gz | mysql -h localhost -u root -p mydb

# MongoDB
mongorestore --gzip --archive=/backups/mydb_2026-02-21_120000.archive.gz --db mydb
```

## Configuration

### Config File (backup.env)

```bash
# Database connection
DB_TYPE=postgres          # postgres | mysql | mongo
DB_HOST=localhost
DB_PORT=5432              # 5432 (pg) | 3306 (mysql) | 27017 (mongo)
DB_USER=myuser
DB_PASSWORD=mypassword
DB_NAME=mydb              # or "all" for all databases

# Backup settings
BACKUP_DIR=/backups
COMPRESS=true             # gzip compression
RETAIN_DAYS=7             # Delete backups older than N days (0 = keep all)
TIMESTAMP_FORMAT="%Y-%m-%d_%H%M%S"

# Cloud upload (optional — leave empty to skip)
UPLOAD_TYPE=               # s3 | gcs | b2 | ""
UPLOAD_BUCKET=
UPLOAD_PREFIX=db-backups/
UPLOAD_REGION=us-east-1    # For S3

# Notifications (optional)
NOTIFY_ON_SUCCESS=false
NOTIFY_ON_FAILURE=true
NOTIFY_WEBHOOK=            # Slack/Discord webhook URL
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=

# Advanced
EXTRA_DUMP_ARGS=           # Extra args passed to pg_dump/mysqldump/mongodump
PARALLEL_JOBS=1            # For pg_dump --jobs (directory format only)
```

### Environment Variables

All config values can be set as environment variables instead of a file:

```bash
export DB_TYPE=postgres
export DB_HOST=localhost
export DB_USER=myuser
export DB_PASSWORD=mypassword
export DB_NAME=mydb
export BACKUP_DIR=/backups

bash scripts/run.sh
```

## Advanced Usage

### Custom Dump Arguments

```bash
# PostgreSQL: schema-only backup
bash scripts/run.sh --type postgres --database mydb --extra "--schema-only"

# PostgreSQL: specific tables
bash scripts/run.sh --type postgres --database mydb --extra "--table=users --table=orders"

# MySQL: with routines and triggers
bash scripts/run.sh --type mysql --database mydb --extra "--routines --triggers"
```

### Pre/Post Hooks

```bash
# Run custom script before/after backup
bash scripts/run.sh --env backup.env \
  --pre-hook "echo 'Starting backup...'" \
  --post-hook "curl -X POST https://hooks.slack.com/... -d '{\"text\":\"Backup done!\"}'"
```

### Encryption

```bash
# Encrypt with GPG (requires gpg installed)
bash scripts/run.sh --env backup.env --encrypt --gpg-recipient admin@example.com

# Output: mydb_2026-02-21_120000.sql.gz.gpg

# Decrypt
gpg --decrypt mydb_2026-02-21_120000.sql.gz.gpg | gunzip | psql mydb
```

## Troubleshooting

### Issue: "pg_dump: command not found"

```bash
sudo apt-get install -y postgresql-client
# or on Mac:
brew install postgresql
```

### Issue: "Access denied for user"

Check credentials in backup.env. For PostgreSQL, ensure pg_hba.conf allows your connection. For MySQL, grant LOCK TABLES + SELECT privileges:

```sql
GRANT SELECT, LOCK TABLES ON mydb.* TO 'backupuser'@'localhost';
```

### Issue: "Upload failed: No credentials"

```bash
# S3: Configure AWS CLI
aws configure

# GCS: Authenticate
gcloud auth login

# B2: Authorize
b2 authorize-account <keyId> <appKey>
```

### Issue: Backup file is 0 bytes

Database might be empty or credentials are wrong. Test connection first:

```bash
# PostgreSQL
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1;"

# MySQL
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD $DB_NAME -e "SELECT 1;"
```

## Dependencies

- `bash` (4.0+)
- `gzip` (compression)
- `date` (timestamps)
- Database client: `pg_dump` / `mysqldump` / `mongodump`
- Optional: `aws` CLI, `gsutil`, `b2` CLI (cloud upload)
- Optional: `gpg` (encryption)
- Optional: `curl` (webhook notifications)
