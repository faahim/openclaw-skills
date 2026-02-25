---
name: mysql-manager
description: >-
  Install, configure, tune, backup, and manage MySQL/MariaDB databases from your agent.
categories: [dev-tools, data]
dependencies: [bash, mysql-client, mysqldump]
---

# MySQL Manager

## What This Does

Automates MySQL/MariaDB database administration — installation, user management, performance tuning, automated backups, and health monitoring. No more memorizing SQL grant syntax or tuning buffer pool sizes by hand.

**Example:** "Install MariaDB, create a production database with a dedicated user, tune for 2GB RAM, set up nightly compressed backups to /backups."

## Quick Start (5 minutes)

### 1. Install MySQL/MariaDB

```bash
bash scripts/install.sh mariadb
# Or: bash scripts/install.sh mysql
```

### 2. Create a Database + User

```bash
bash scripts/manage.sh create-db myapp
bash scripts/manage.sh create-user myapp_user 'SecurePass123!' myapp
```

### 3. Run Health Check

```bash
bash scripts/health.sh
```

## Core Workflows

### Workflow 1: Fresh Server Setup

**Use case:** Set up a production-ready MySQL/MariaDB from scratch.

```bash
# Install MariaDB
bash scripts/install.sh mariadb

# Secure installation (remove test db, anonymous users)
bash scripts/manage.sh secure

# Create application database and user
bash scripts/manage.sh create-db production_app
bash scripts/manage.sh create-user app_user 'StrongP@ss99!' production_app

# Tune for available RAM (auto-detects)
bash scripts/tune.sh auto
```

### Workflow 2: Automated Backups

**Use case:** Nightly compressed backups with 7-day retention.

```bash
# Backup all databases
bash scripts/backup.sh --all --compress --dir /var/backups/mysql

# Backup specific database
bash scripts/backup.sh --db production_app --compress --dir /var/backups/mysql

# Set up cron for nightly backups (2 AM, keep 7 days)
bash scripts/backup.sh --schedule --time "0 2 * * *" --retain 7 --dir /var/backups/mysql
```

### Workflow 3: Performance Tuning

**Use case:** Optimize MySQL for your server's resources.

```bash
# Auto-tune based on available RAM and workload
bash scripts/tune.sh auto

# Tune for specific workload type
bash scripts/tune.sh --type oltp --ram 4G
bash scripts/tune.sh --type olap --ram 8G
bash scripts/tune.sh --type mixed --ram 2G

# Show current settings vs recommended
bash scripts/tune.sh --diff
```

### Workflow 4: User Management

```bash
# List all users
bash scripts/manage.sh list-users

# Create read-only user
bash scripts/manage.sh create-user readonly_user 'Pass123!' mydb --readonly

# Grant full access
bash scripts/manage.sh create-user admin_user 'Pass123!' mydb --full

# Revoke user access
bash scripts/manage.sh drop-user old_user

# Reset password
bash scripts/manage.sh reset-password app_user 'NewPass456!'
```

### Workflow 5: Health Monitoring

```bash
# Full health check (connections, slow queries, replication, disk)
bash scripts/health.sh

# Check specific metrics
bash scripts/health.sh --connections
bash scripts/health.sh --slow-queries
bash scripts/health.sh --replication
bash scripts/health.sh --disk

# Output as JSON (for piping to alerts)
bash scripts/health.sh --json
```

### Workflow 6: Database Operations

```bash
# List all databases with sizes
bash scripts/manage.sh list-dbs

# Show table sizes for a database
bash scripts/manage.sh table-sizes mydb

# Clone a database (for staging)
bash scripts/manage.sh clone-db production_app staging_app

# Drop a database (with confirmation)
bash scripts/manage.sh drop-db old_database

# Run a SQL file
bash scripts/manage.sh run-sql mydb /path/to/migration.sql

# Export schema only (no data)
bash scripts/manage.sh export-schema mydb > schema.sql
```

## Configuration

### Credentials File

```bash
# scripts/manage.sh uses ~/.my.cnf for auth (created during install)
# Format:
cat ~/.my.cnf
# [client]
# user=root
# password=YOUR_ROOT_PASSWORD
# socket=/var/run/mysqld/mysqld.sock
```

### Environment Variables

```bash
# Override defaults
export MYSQL_HOST="localhost"
export MYSQL_PORT="3306"
export MYSQL_USER="root"
export MYSQL_PASSWORD="your_password"
export BACKUP_DIR="/var/backups/mysql"
export BACKUP_RETAIN_DAYS=7
```

## Advanced Usage

### Replication Setup

```bash
# Configure as primary
bash scripts/manage.sh replication-primary --server-id 1

# Configure as replica
bash scripts/manage.sh replication-replica --primary-host 10.0.0.1 --server-id 2
```

### Import Large Databases

```bash
# Import with progress indicator
bash scripts/manage.sh import mydb /path/to/dump.sql.gz

# Import with optimizations (disable keys, autocommit off)
bash scripts/manage.sh import mydb /path/to/dump.sql --fast
```

### Slow Query Analysis

```bash
# Enable slow query log
bash scripts/manage.sh slow-log enable --threshold 2

# Analyze slow query log
bash scripts/health.sh --slow-queries --top 20

# Disable slow query log
bash scripts/manage.sh slow-log disable
```

## Troubleshooting

### Issue: "Access denied for user 'root'@'localhost'"

**Fix:**
```bash
# Reset root password
sudo bash scripts/manage.sh reset-root
```

### Issue: "Too many connections"

**Fix:**
```bash
# Check current connections
bash scripts/health.sh --connections

# Increase max connections
bash scripts/tune.sh --max-connections 500
```

### Issue: "InnoDB buffer pool too small"

**Fix:**
```bash
# Auto-tune will fix this
bash scripts/tune.sh auto
```

### Issue: Backup fails with large databases

**Fix:**
```bash
# Use single-transaction for InnoDB (no lock)
bash scripts/backup.sh --db mydb --single-transaction --compress
```

## Dependencies

- `bash` (4.0+)
- `mysql-client` or `mariadb-client` (installed by install.sh)
- `mysqldump` (bundled with client)
- `gzip` (for compressed backups)
- `bc` (for tuning calculations)
- Optional: `pv` (progress bars for imports)
