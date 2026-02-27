# Listing Copy: Litestream Replication

## Metadata
- **Type:** Skill
- **Name:** litestream-replication
- **Display Name:** Litestream Replication
- **Categories:** [data, automation]
- **Price:** $12
- **Dependencies:** [litestream, sqlite3]
- **Icon:** 💾

## Tagline

Continuously replicate SQLite to S3 — disaster recovery in seconds, not hours.

## Description

SQLite is incredible until your server dies and takes your database with it. Manual backups are unreliable, cron-based dumps miss writes between snapshots, and setting up Postgres replication is overkill for most apps.

Litestream Replication sets up continuous, real-time replication of your SQLite databases to any S3-compatible storage — AWS S3, Backblaze B2, MinIO, or DigitalOcean Spaces. Every write streams to your cloud storage within one second. Restore to any point in time within your retention window.

**What it does:**
- 💾 Continuous replication — every SQLite write streams to S3 in real-time
- ⏰ Point-in-time restore — recover to any moment in your retention window
- 🔄 Auto-restore on deploy — containers start fresh by pulling latest backup
- 📊 Multi-database support — replicate multiple SQLite files simultaneously
- 🌍 Multi-replica — send to multiple S3 buckets for geo-redundancy
- 🏥 Health monitoring — verify replica integrity automatically
- ⚡ Zero-downtime — runs alongside your app with no locks or pauses
- 🐳 Docker-ready — includes Dockerfile patterns for containerized apps

Perfect for indie developers, side projects, and production apps using SQLite (Litestream, Turso, LibSQL, PocketBase, Bun, etc.).

## Quick Start Preview

```bash
# Install litestream
bash scripts/install.sh

# Configure (edit S3 credentials and database path)
cp scripts/config-template.yml /etc/litestream.yml

# Start replicating
litestream replicate -config /etc/litestream.yml

# Restore from backup
litestream restore -config /etc/litestream.yml /path/to/db.db
```

## Core Capabilities

1. Real-time WAL streaming — sub-second replication to S3-compatible storage
2. Point-in-time recovery — restore to any timestamp within retention window
3. Multi-provider support — AWS S3, Backblaze B2, MinIO, DigitalOcean Spaces, Google Cloud Storage
4. Systemd integration — run as a managed service with auto-restart
5. Docker patterns — auto-restore on container start, replicate during runtime
6. Multi-database — replicate multiple SQLite files from one config
7. Geo-redundancy — replicate to multiple buckets in different regions
8. Integrity verification — periodic automated checks that replicas are valid
9. Health monitoring — scripts to verify process, config, and replica status
10. Configurable retention — keep WAL segments for hours, days, or months

## Dependencies
- `litestream` (v0.3.13+) — installed by scripts/install.sh
- `sqlite3` (for verification)
- S3-compatible storage account

## Installation Time
**5 minutes** — install binary, configure YAML, start service
