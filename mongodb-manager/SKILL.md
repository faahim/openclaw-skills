---
name: mongodb-manager
description: >-
  Install, configure, backup, restore, and monitor MongoDB instances from the command line.
categories: [dev-tools, data]
dependencies: [bash, curl, mongosh, mongodump, mongoexport]
---

# MongoDB Manager

## What This Does

Install and manage MongoDB servers, run backups and restores, monitor performance, and manage users/databases — all from bash scripts your OpenClaw agent can execute directly. No GUI needed.

**Example:** "Install MongoDB 8.0 on Ubuntu, create a database with a user, schedule nightly backups to S3, and alert me if the server goes down."

## Quick Start (5 minutes)

### 1. Install MongoDB

```bash
bash scripts/install.sh --version 8.0
# Installs MongoDB Community Server + mongosh + mongo tools
# Supports Ubuntu/Debian and RHEL/CentOS/Amazon Linux
```

### 2. Create a Database and User

```bash
bash scripts/manage.sh create-db --name myapp
bash scripts/manage.sh create-user --db myapp --user appuser --pass "$(openssl rand -base64 24)"
```

### 3. Check Server Status

```bash
bash scripts/monitor.sh status
# Output:
# ✅ MongoDB 8.0.4 running (PID 1234)
# 📊 Connections: 5/65536 | Memory: 256MB | Uptime: 3d 12h
# 💾 Databases: 3 | Collections: 12 | Data Size: 1.2GB
```

## Core Workflows

### Workflow 1: Install MongoDB

```bash
# Install latest stable
bash scripts/install.sh --version 8.0

# Install with authentication enabled (recommended)
bash scripts/install.sh --version 8.0 --auth

# Install with custom data directory
bash scripts/install.sh --version 8.0 --dbpath /mnt/data/mongodb
```

### Workflow 2: Backup & Restore

```bash
# Full backup (all databases)
bash scripts/backup.sh --output /backups/mongo --compress
# Output: ✅ Backup saved to /backups/mongo/2026-02-26_full.gz (145MB)

# Backup single database
bash scripts/backup.sh --db myapp --output /backups/mongo --compress

# Upload to S3 (requires aws CLI)
bash scripts/backup.sh --db myapp --compress --s3 s3://my-bucket/mongo-backups/

# Restore from backup
bash scripts/backup.sh restore --input /backups/mongo/2026-02-26_full.gz

# Restore single database
bash scripts/backup.sh restore --input /backups/mongo/2026-02-26_full.gz --db myapp
```

### Workflow 3: Export & Import Data

```bash
# Export collection to JSON
bash scripts/manage.sh export --db myapp --collection users --output users.json

# Export collection to CSV
bash scripts/manage.sh export --db myapp --collection users --output users.csv --csv --fields "name,email,created_at"

# Import JSON data
bash scripts/manage.sh import --db myapp --collection users --input users.json

# Import CSV
bash scripts/manage.sh import --db myapp --collection users --input users.csv --csv --headerline
```

### Workflow 4: Monitor Performance

```bash
# Quick status check
bash scripts/monitor.sh status

# Live monitoring (refreshes every 5 seconds)
bash scripts/monitor.sh live --interval 5

# Check slow queries (>100ms)
bash scripts/monitor.sh slow-queries --threshold 100

# Connection stats
bash scripts/monitor.sh connections

# Disk usage per database
bash scripts/monitor.sh disk-usage
```

### Workflow 5: User & Security Management

```bash
# Create admin user
bash scripts/manage.sh create-user --db admin --user dbadmin --role root --pass "$ADMIN_PASS"

# Create read-only user
bash scripts/manage.sh create-user --db myapp --user reader --role read --pass "$READ_PASS"

# List users
bash scripts/manage.sh list-users --db myapp

# Drop user
bash scripts/manage.sh drop-user --db myapp --user olduser

# Enable authentication
bash scripts/manage.sh enable-auth
```

### Workflow 6: Index Management

```bash
# List indexes for a collection
bash scripts/manage.sh indexes --db myapp --collection users

# Create index
bash scripts/manage.sh create-index --db myapp --collection users --field email --unique

# Create compound index
bash scripts/manage.sh create-index --db myapp --collection orders --fields '{"customer_id":1,"created_at":-1}'

# Drop index
bash scripts/manage.sh drop-index --db myapp --collection users --index email_1
```

## Scheduled Backup (Cron)

```bash
# Add nightly backup at 2 AM
bash scripts/setup-cron.sh --schedule "0 2 * * *" --db myapp --compress --s3 s3://my-bucket/backups/ --retention 30

# This creates a crontab entry:
# 0 2 * * * /path/to/scripts/backup.sh --db myapp --compress --s3 s3://my-bucket/backups/ --retention 30 >> /var/log/mongo-backup.log 2>&1
```

## Configuration

### Environment Variables

```bash
# MongoDB connection (defaults to localhost:27017)
export MONGO_HOST="localhost"
export MONGO_PORT="27017"
export MONGO_USER="admin"
export MONGO_PASS="your-password"
export MONGO_AUTH_DB="admin"

# Backup settings
export MONGO_BACKUP_DIR="/backups/mongo"
export MONGO_BACKUP_S3=""  # s3://bucket/path/
export MONGO_BACKUP_RETENTION=30  # days

# Monitoring
export MONGO_ALERT_CONNECTIONS=100  # alert threshold
export MONGO_ALERT_MEMORY_MB=4096  # alert threshold

# Telegram alerts (optional)
export TELEGRAM_BOT_TOKEN="your-token"
export TELEGRAM_CHAT_ID="your-chat-id"
```

### Config File

```yaml
# config.yaml
connection:
  host: localhost
  port: 27017
  auth:
    user: admin
    password: "${MONGO_PASS}"
    authDB: admin

backup:
  dir: /backups/mongo
  compress: true
  s3: ""
  retention: 30  # days

monitoring:
  interval: 60  # seconds
  alerts:
    connections: 100
    memory_mb: 4096
    disk_percent: 85
  notify:
    - type: telegram
      chat_id: "${TELEGRAM_CHAT_ID}"
```

## Replica Set Setup

```bash
# Initialize a 3-node replica set
bash scripts/manage.sh init-replica \
  --name rs0 \
  --members "mongo1:27017,mongo2:27017,mongo3:27017"

# Check replica set status
bash scripts/monitor.sh replica-status

# Step down primary
bash scripts/manage.sh step-down
```

## Troubleshooting

### Issue: "mongosh: command not found"

```bash
# Re-run installer
bash scripts/install.sh --version 8.0
# Or install mongosh separately
npm install -g mongosh
```

### Issue: Authentication failed

```bash
# Check if auth is enabled
grep -i "authorization" /etc/mongod.conf
# Connect without auth to create initial user
mongosh --eval 'db.createUser({user:"admin",pwd:"pass",roles:["root"]})' admin
```

### Issue: Connection refused

```bash
# Check if MongoDB is running
systemctl status mongod
# Check listening port
ss -tlnp | grep 27017
# Check logs
tail -50 /var/log/mongodb/mongod.log
```

### Issue: Backup fails with "not authorized"

```bash
# Ensure backup user has correct role
mongosh admin --eval 'db.grantRolesToUser("backupuser", ["backup", "readAnyDatabase"])'
```

### Issue: High memory usage

```bash
# Check WiredTiger cache size
bash scripts/monitor.sh status
# Limit cache (add to mongod.conf)
# storage:
#   wiredTiger:
#     engineConfig:
#       cacheSizeGB: 2
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `mongosh` (installed by install.sh)
- `mongodump` / `mongorestore` (installed by install.sh)
- `mongoexport` / `mongoimport` (installed by install.sh)
- Optional: `aws` CLI (for S3 backups)
- Optional: `jq` (for JSON output formatting)
