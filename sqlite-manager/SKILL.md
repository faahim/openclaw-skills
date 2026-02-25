---
name: sqlite-manager
description: >-
  Manage SQLite databases — query, inspect schemas, backup, restore, optimize, and export data from the command line.
categories: [dev-tools, data]
dependencies: [sqlite3, bash]
---

# SQLite Manager

## What This Does

Manage SQLite databases without leaving your terminal. Inspect schemas, run queries, backup/restore databases, optimize performance, export to CSV/JSON, and monitor database health. No GUI needed — your OpenClaw agent handles it all.

**Example:** "Show me all tables in my app.db, export the users table to CSV, then vacuum and optimize it."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Check if sqlite3 is installed
which sqlite3 || sudo apt-get install -y sqlite3

# Verify version (3.x required)
sqlite3 --version
```

### 2. Inspect a Database

```bash
bash scripts/sqlite-mgr.sh info /path/to/database.db
```

**Output:**
```
📊 Database: database.db
   Size: 2.4 MB
   Tables: 5
   Indexes: 8
   WAL mode: ON

Tables:
  users          — 1,247 rows (3 indexes)
  posts          — 8,932 rows (2 indexes)
  comments       — 24,510 rows (2 indexes)
  tags           — 156 rows (1 index)
  sessions       — 89 rows (0 indexes)
```

### 3. Run a Query

```bash
bash scripts/sqlite-mgr.sh query /path/to/database.db "SELECT * FROM users LIMIT 5"
```

## Core Workflows

### Workflow 1: Database Info & Schema Inspection

```bash
# Full database overview
bash scripts/sqlite-mgr.sh info myapp.db

# Show schema for a specific table
bash scripts/sqlite-mgr.sh schema myapp.db users

# List all indexes
bash scripts/sqlite-mgr.sh indexes myapp.db
```

**Output (schema):**
```
📋 Table: users
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  name TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  is_active INTEGER DEFAULT 1
);

Indexes:
  idx_users_email — UNIQUE (email)
  idx_users_active — (is_active)

Row count: 1,247
```

### Workflow 2: Query & Export

```bash
# Run any SQL query
bash scripts/sqlite-mgr.sh query myapp.db "SELECT name, email FROM users WHERE is_active = 1"

# Export table to CSV
bash scripts/sqlite-mgr.sh export myapp.db users csv > users.csv

# Export query results to JSON
bash scripts/sqlite-mgr.sh export myapp.db "SELECT * FROM users WHERE created_at > '2026-01-01'" json > recent_users.json

# Export entire database schema as SQL
bash scripts/sqlite-mgr.sh dump-schema myapp.db > schema.sql
```

### Workflow 3: Backup & Restore

```bash
# Hot backup (safe even while database is in use)
bash scripts/sqlite-mgr.sh backup myapp.db backups/myapp-2026-02-25.db

# Backup with compression
bash scripts/sqlite-mgr.sh backup myapp.db backups/myapp-2026-02-25.db.gz --compress

# Restore from backup
bash scripts/sqlite-mgr.sh restore backups/myapp-2026-02-25.db myapp.db

# Restore from compressed backup
bash scripts/sqlite-mgr.sh restore backups/myapp-2026-02-25.db.gz myapp.db --decompress
```

### Workflow 4: Optimize & Maintain

```bash
# VACUUM — reclaim unused space
bash scripts/sqlite-mgr.sh vacuum myapp.db

# Analyze — update query planner statistics
bash scripts/sqlite-mgr.sh analyze myapp.db

# Integrity check
bash scripts/sqlite-mgr.sh check myapp.db

# Full optimization (vacuum + analyze + integrity check)
bash scripts/sqlite-mgr.sh optimize myapp.db

# Enable WAL mode for better concurrency
bash scripts/sqlite-mgr.sh wal myapp.db on
```

**Output (optimize):**
```
🔧 Optimizing myapp.db...
  ✅ Integrity check: OK
  ✅ VACUUM: 2.4 MB → 2.1 MB (saved 300 KB)
  ✅ ANALYZE: Statistics updated for 5 tables
  ✅ WAL mode: already enabled
Done in 1.2s
```

### Workflow 5: Health Report

```bash
# Generate health report
bash scripts/sqlite-mgr.sh health myapp.db
```

**Output:**
```
🏥 Health Report: myapp.db

Storage:
  File size: 2.1 MB
  Freelist pages: 0 (after vacuum)
  Page size: 4096 bytes

Performance:
  Journal mode: WAL ✅
  Auto-vacuum: NONE ⚠️ (consider enabling)
  Cache size: 2000 pages

Tables (5):
  users       — 1,247 rows, 3 idx ✅
  posts       — 8,932 rows, 2 idx ✅
  comments    — 24,510 rows, 2 idx ⚠️ (no index on post_id?)
  tags        — 156 rows, 1 idx ✅
  sessions    — 89 rows, 0 idx ⚠️ (no indexes)

Recommendations:
  1. Add index on comments.post_id for faster joins
  2. Add index on sessions table for lookup queries
  3. Consider enabling auto-vacuum for automatic space reclaim
```

## Advanced Usage

### Scheduled Backups (via cron)

```bash
# Add to crontab — daily backup at 2 AM
echo "0 2 * * * bash /path/to/scripts/sqlite-mgr.sh backup /path/to/myapp.db /backups/myapp-\$(date +\%Y\%m\%d).db --compress" | crontab -

# Weekly optimization
echo "0 3 * * 0 bash /path/to/scripts/sqlite-mgr.sh optimize /path/to/myapp.db" | crontab -
```

### Batch Operations

```bash
# Run SQL from a file
bash scripts/sqlite-mgr.sh exec myapp.db migrations/001_add_column.sql

# Compare two databases
bash scripts/sqlite-mgr.sh diff db1.db db2.db
```

### Monitor Database Growth

```bash
# Show size history (requires previous runs)
bash scripts/sqlite-mgr.sh size-history myapp.db
```

## Troubleshooting

### Issue: "database is locked"

**Fix:** Enable WAL mode for concurrent read/write:
```bash
bash scripts/sqlite-mgr.sh wal myapp.db on
```

### Issue: Database corruption

**Check:**
```bash
bash scripts/sqlite-mgr.sh check myapp.db
```
If integrity fails, restore from backup:
```bash
bash scripts/sqlite-mgr.sh restore backups/latest.db myapp.db
```

### Issue: Slow queries

**Fix:** Run ANALYZE and check for missing indexes:
```bash
bash scripts/sqlite-mgr.sh analyze myapp.db
bash scripts/sqlite-mgr.sh health myapp.db
```

## Dependencies

- `sqlite3` (3.x+)
- `bash` (4.0+)
- `gzip` (for compressed backups, usually pre-installed)
- `jq` (for JSON export, optional)
