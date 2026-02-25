# Listing Copy: SQLite Manager

## Metadata
- **Type:** Skill
- **Name:** sqlite-manager
- **Display Name:** SQLite Manager
- **Categories:** [dev-tools, data]
- **Price:** $10
- **Dependencies:** [sqlite3, bash]

## Tagline
Manage SQLite databases — query, backup, optimize, and export without leaving your terminal

## Description

SQLite is everywhere — your apps, your side projects, your local tools. But managing databases from the command line means remembering obscure PRAGMA commands, writing one-off scripts for backups, and hoping you don't corrupt anything.

SQLite Manager wraps the full database lifecycle into simple, memorable commands. Inspect schemas, run queries, export to CSV/JSON, create hot backups (safe while the database is in use), optimize performance with one command, and get health reports with actionable recommendations.

**What it does:**
- 📊 Database overview — tables, row counts, indexes, sizes at a glance
- 🔍 Schema inspection — table definitions, indexes, column details
- 📤 Export anywhere — CSV, JSON, or SQL dump
- 💾 Hot backup & restore — safe backups even during writes, with compression
- ⚡ One-command optimization — VACUUM + ANALYZE + integrity check
- 🏥 Health reports — spots missing indexes, suggests WAL mode, flags issues
- 📈 Size tracking — monitor database growth over time
- 🔀 Database diff — compare schemas and row counts between two databases

Perfect for developers, indie hackers, and anyone managing SQLite databases who wants reliable tooling without a GUI.

## Quick Start Preview

```bash
# Database overview
bash scripts/sqlite-mgr.sh info myapp.db

# Run a query
bash scripts/sqlite-mgr.sh query myapp.db "SELECT * FROM users LIMIT 10"

# Full optimization
bash scripts/sqlite-mgr.sh optimize myapp.db

# Hot backup with compression
bash scripts/sqlite-mgr.sh backup myapp.db backups/daily.db.gz --compress
```

## Dependencies
- `sqlite3` (3.x+)
- `bash` (4.0+)
- `gzip` (optional, for compressed backups)
- `jq` (optional, for JSON export)

## Installation Time
**2 minutes** — install sqlite3 if missing, run commands
