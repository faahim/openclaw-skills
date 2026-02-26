# Listing Copy: MongoDB Manager

## Metadata
- **Type:** Skill
- **Name:** mongodb-manager
- **Display Name:** MongoDB Manager
- **Categories:** [dev-tools, data]
- **Price:** $12
- **Dependencies:** [bash, curl, mongosh, mongodump, mongoexport]

## Tagline
Install, backup, monitor, and manage MongoDB — all from bash scripts your agent runs directly.

## Description

Managing MongoDB means juggling installation, user management, backups, restores, index tuning, and monitoring — across different OS flavors. Most guides are 20-step tutorials you have to adapt every time.

MongoDB Manager gives your OpenClaw agent executable scripts that handle the full lifecycle: install MongoDB on Ubuntu/Debian/RHEL, create databases and users, run compressed backups with S3 upload, schedule automated backups via cron, monitor connections and slow queries, manage indexes, and even set up replica sets. No external services, no GUI needed.

**What it does:**
- 📦 One-command install (Ubuntu, Debian, CentOS, RHEL, Amazon Linux)
- 💾 Backup & restore with gzip compression and S3 upload
- 📊 Real-time monitoring: connections, memory, ops, disk usage
- 👥 User management: create, drop, list users with roles
- 📇 Index management: create, drop, list indexes
- 🔗 Replica set initialization and status monitoring
- ⏰ Scheduled backups with retention cleanup
- 🔔 Telegram alerts on backup success/failure
- 📤 Export/import collections as JSON or CSV

Perfect for developers and sysadmins who run MongoDB and want their agent to handle the operational overhead.

## Quick Start Preview

```bash
# Install MongoDB 8.0
bash scripts/install.sh --version 8.0

# Monitor server status
bash scripts/monitor.sh status
# ✅ MongoDB 8.0.4 running (PID 1234)
# 📊 Connections: 5/65536 | Memory: 256MB | Uptime: 3d 12h

# Backup with compression
bash scripts/backup.sh --db myapp --compress
# ✅ Backup saved to /backups/mongo/myapp_2026-02-26.tar.gz (145MB)
```

## Core Capabilities

1. Installation — Auto-detect OS, add official repo, install server + tools
2. Database management — Create, drop, list databases
3. User management — Create users with roles, manage authentication
4. Backup & restore — Full or per-DB, gzip compression, S3 upload
5. Scheduled backups — Cron setup with retention-based cleanup
6. Export/import — JSON and CSV with field selection
7. Performance monitoring — Connections, memory, ops counters, slow queries
8. Disk usage analysis — Per-database size breakdown with visual bars
9. Index management — Create single/compound indexes, unique constraints
10. Replica sets — Initialize, monitor status, step down primary
11. Telegram alerts — Backup success/failure notifications
12. Live dashboard — Real-time terminal monitoring with auto-refresh

## Dependencies
- `bash` (4.0+)
- `curl` (for installation)
- `mongosh`, `mongodump`, `mongorestore`, `mongoexport`, `mongoimport` (installed by install.sh)
- Optional: `aws` CLI (S3 backups), `jq` (JSON formatting)

## Installation Time
5 minutes — run install.sh, start managing
