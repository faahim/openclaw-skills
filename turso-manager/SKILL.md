---
name: turso-manager
description: >-
  Install, configure, and manage Turso (libSQL) databases from the command line.
  Create databases, manage auth tokens, sync replicas, run queries, backup and restore.
categories: [dev-tools, data]
dependencies: [curl, bash]
---

# Turso Database Manager

## What This Does

Manage Turso (libSQL) edge databases directly from your terminal. Create and destroy databases, manage groups and replicas, generate auth tokens, run SQL queries, create local backups, and monitor database usage — all without leaving the command line.

**Example:** "Create a new Turso database in the SJC region, generate a read-only auth token, run a schema migration, and back up the database locally."

## Quick Start (5 minutes)

### 1. Install Turso CLI

```bash
bash scripts/install.sh
```

### 2. Authenticate

```bash
turso auth login
# Opens browser for authentication
# Or use token: export TURSO_API_TOKEN="your-api-token"
```

### 3. Create Your First Database

```bash
bash scripts/turso-manage.sh create myapp-db --group default
```

## Core Workflows

### Workflow 1: Create a Database

```bash
bash scripts/turso-manage.sh create <db-name> [--group <group>] [--region <region>]

# Examples:
bash scripts/turso-manage.sh create myapp-prod --region sjc
bash scripts/turso-manage.sh create myapp-staging --group staging
```

**Output:**
```
✅ Database 'myapp-prod' created
   URL: libsql://myapp-prod-username.turso.io
   Region: sjc (San Jose)
```

### Workflow 2: List & Inspect Databases

```bash
# List all databases
bash scripts/turso-manage.sh list

# Show database details
bash scripts/turso-manage.sh info <db-name>

# Show database usage stats
bash scripts/turso-manage.sh usage <db-name>
```

**Output:**
```
📊 Database: myapp-prod
   URL: libsql://myapp-prod-username.turso.io
   Group: default
   Regions: sjc
   Size: 2.4 MB
   Rows read (30d): 145,230
   Rows written (30d): 12,450
```

### Workflow 3: Generate Auth Tokens

```bash
# Full access token
bash scripts/turso-manage.sh token <db-name>

# Read-only token
bash scripts/turso-manage.sh token <db-name> --read-only

# Token with expiration
bash scripts/turso-manage.sh token <db-name> --expiration 7d
```

**Output:**
```
🔑 Auth token for 'myapp-prod':
   eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9...
   
   Permissions: full-access
   Expires: 2026-03-13T22:00:00Z
   
   Set in your app:
   TURSO_DATABASE_URL=libsql://myapp-prod-username.turso.io
   TURSO_AUTH_TOKEN=eyJhbGciOiJFZERTQSIs...
```

### Workflow 4: Run SQL Queries

```bash
# Interactive shell
bash scripts/turso-manage.sh shell <db-name>

# Execute a query
bash scripts/turso-manage.sh query <db-name> "SELECT * FROM users LIMIT 10"

# Run a migration file
bash scripts/turso-manage.sh migrate <db-name> --file schema.sql
```

**Output:**
```
┌────┬──────────┬─────────────────────┐
│ id │ name     │ email               │
├────┼──────────┼─────────────────────┤
│ 1  │ Alice    │ alice@example.com   │
│ 2  │ Bob      │ bob@example.com     │
└────┴──────────┴─────────────────────┘
2 rows returned (12ms)
```

### Workflow 5: Backup & Restore

```bash
# Backup database to local SQLite file
bash scripts/turso-manage.sh backup <db-name> [--output backups/]

# Restore from local backup
bash scripts/turso-manage.sh restore <db-name> --from backups/myapp-prod-2026-03-06.db
```

**Output:**
```
💾 Backup complete: backups/myapp-prod-2026-03-06.db (2.4 MB)
   Tables: 8
   Total rows: 15,230
```

### Workflow 6: Manage Groups & Replicas

```bash
# Create a group with primary region
bash scripts/turso-manage.sh group-create prod-group --region sjc

# Add replica regions
bash scripts/turso-manage.sh group-add-region prod-group --region ams
bash scripts/turso-manage.sh group-add-region prod-group --region nrt

# List groups
bash scripts/turso-manage.sh group-list
```

**Output:**
```
📍 Group: prod-group
   Primary: sjc (San Jose)
   Replicas: ams (Amsterdam), nrt (Tokyo)
   Databases: myapp-prod, myapp-staging
```

### Workflow 7: Destroy Database

```bash
# Destroy with confirmation
bash scripts/turso-manage.sh destroy <db-name>

# Force destroy (no prompt)
bash scripts/turso-manage.sh destroy <db-name> --yes
```

## Configuration

### Environment Variables

```bash
# API token (alternative to `turso auth login`)
export TURSO_API_TOKEN="your-api-token"

# Default organization
export TURSO_ORG="your-org-name"

# Default group for new databases
export TURSO_DEFAULT_GROUP="default"

# Default backup directory
export TURSO_BACKUP_DIR="$HOME/.turso-backups"
```

### Config File (~/.turso-manager.conf)

```bash
# Default settings
DEFAULT_GROUP=default
DEFAULT_REGION=sjc
BACKUP_DIR=$HOME/.turso-backups
BACKUP_RETENTION_DAYS=30
AUTO_BACKUP=false
```

## Advanced Usage

### Scheduled Backups via Cron

```bash
# Daily backup of all databases at 2 AM
bash scripts/turso-manage.sh setup-cron --interval daily --time "02:00"

# This adds to crontab:
# 0 2 * * * /path/to/scripts/turso-manage.sh backup-all --output ~/.turso-backups/
```

### Database Cloning

```bash
# Clone production to staging
bash scripts/turso-manage.sh clone myapp-prod myapp-staging-new
```

### Batch Operations

```bash
# Backup all databases
bash scripts/turso-manage.sh backup-all --output backups/

# List all databases with usage
bash scripts/turso-manage.sh list --usage
```

### Connection String Helper

```bash
# Generate .env file for your app
bash scripts/turso-manage.sh env <db-name> >> .env

# Output:
# TURSO_DATABASE_URL=libsql://myapp-prod-username.turso.io
# TURSO_AUTH_TOKEN=eyJhbGci...
```

## Troubleshooting

### Issue: "turso: command not found"

**Fix:**
```bash
bash scripts/install.sh
# Or manually:
curl -sSfL https://get.tur.so/install.sh | bash
```

### Issue: "Authentication required"

**Fix:**
```bash
turso auth login
# Or set token:
export TURSO_API_TOKEN="your-token"
```

### Issue: "Database not found"

**Check:**
```bash
bash scripts/turso-manage.sh list
# Verify the database name and organization
```

### Issue: Backup fails with large database

**Fix:** Use streaming backup:
```bash
bash scripts/turso-manage.sh backup <db-name> --stream
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `turso` CLI (installed by scripts/install.sh)
- Optional: `jq` (for JSON output formatting)
- Optional: `sqlite3` (for local backup inspection)
