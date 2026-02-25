# Listing Copy: MySQL Manager

## Metadata
- **Type:** Skill
- **Name:** mysql-manager
- **Display Name:** MySQL Manager
- **Categories:** [dev-tools, data]
- **Price:** $12
- **Dependencies:** [bash, mysql-client, mysqldump]
- **Icon:** 🐬

## Tagline

Install, tune, backup, and manage MySQL/MariaDB — zero SQL memorization required

## Description

Managing MySQL shouldn't require memorizing GRANT syntax or googling innodb_buffer_pool_size calculations for the hundredth time. MySQL Manager handles the full lifecycle of your database — from installation to daily backups to performance tuning.

MySQL Manager installs MySQL or MariaDB on any Linux distro, auto-tunes InnoDB settings for your available RAM and workload type (OLTP, OLAP, or mixed), manages users with proper permissions, runs compressed backups on schedule with automatic rotation, and monitors health metrics including connections, slow queries, replication lag, and disk usage.

**What it does:**
- 🐬 One-command install for MySQL or MariaDB (Ubuntu, Debian, CentOS, Arch, Alpine)
- ⚡ Auto-tune performance settings based on RAM and workload type
- 👤 Create, drop, and manage database users with proper grants
- 💾 Automated compressed backups with cron scheduling and retention
- 🏥 Health checks: connections, buffer pool, QPS, slow queries, disk, replication
- 📊 Current vs recommended settings diff view
- 🔄 Database cloning, schema export, fast imports with progress bars
- 🔗 Replication setup (primary/replica) in one command

Perfect for developers deploying apps, sysadmins managing database servers, and indie hackers who need MySQL running without the DBA overhead.

## Quick Start Preview

```bash
# Install MariaDB
bash scripts/install.sh mariadb

# Create database + user
bash scripts/manage.sh create-db myapp
bash scripts/manage.sh create-user app_user 'Pass123!' myapp

# Auto-tune for your server
bash scripts/tune.sh auto

# Set up nightly backups
bash scripts/backup.sh --schedule --time '0 2 * * *' --retain 7
```

## Core Capabilities

1. One-command installation — MariaDB or MySQL on any major Linux distro
2. Auto-tuning — Calculates optimal InnoDB buffer pool, connections, caches from RAM
3. User management — Create, drop, reset passwords with proper GRANT syntax
4. Automated backups — Compressed dumps, cron scheduling, retention policies
5. Health monitoring — Connections, QPS, buffer pool, slow queries, disk usage
6. Replication setup — Configure primary/replica in one command
7. Database cloning — Copy production to staging with one command
8. Fast imports — Optimized bulk loading with progress bars
9. Slow query analysis — Enable logging, find top offenders
10. JSON output — Health metrics as JSON for alerting pipelines
11. Security hardening — Remove test databases, anonymous users, remote root
12. Schema export — Dump structure without data for migrations

## Dependencies
- `bash` (4.0+)
- `mysql-client` or `mariadb-client`
- `mysqldump`
- `gzip`
- `bc`
- Optional: `pv` (progress bars)

## Installation Time
**5 minutes** — Run install script, done.

## Pricing Justification

**Why $12:**
- Comparable hosted tools: $20-100/month (PlanetScale, RDS)
- DBA consulting: $100+/hour
- One-time payment covers install + tune + backup + monitor
- Medium complexity: 4 scripts, OS detection, workload-based tuning
