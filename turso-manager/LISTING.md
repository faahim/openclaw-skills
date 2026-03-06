# Listing Copy: Turso Manager

## Metadata
- **Type:** Skill
- **Name:** turso-manager
- **Display Name:** Turso Database Manager
- **Categories:** [dev-tools, data]
- **Icon:** 🗄️
- **Dependencies:** [curl, bash]

## Tagline

Manage Turso edge databases — Create, query, backup, and replicate from your terminal

## Description

Managing Turso databases across environments means juggling CLI commands, remembering token flags, and manually running backups. Miss a backup before a migration and you're in trouble.

Turso Database Manager wraps the Turso CLI into a streamlined workflow. Create databases, generate scoped auth tokens, run SQL queries and migrations, clone databases between environments, and schedule automatic backups — all through a single script.

**What it does:**
- 🗄️ Create, list, inspect, clone, and destroy databases
- 🔑 Generate full-access or read-only auth tokens with expiration
- 📝 Run SQL queries, migrations, and interactive shells
- 📍 Manage groups and replica regions for edge distribution
- 💾 Backup to local SQLite, restore from dumps, schedule via cron
- 🔧 Generate .env connection strings for your apps

**Who it's for:** Developers using Turso/libSQL who want fast, scriptable database management without context-switching to a web dashboard.

## Quick Start Preview

```bash
# Create a database
bash scripts/turso-manage.sh create myapp --region sjc

# Generate a read-only token
bash scripts/turso-manage.sh token myapp --read-only --expiration 30d

# Run a query
bash scripts/turso-manage.sh query myapp "SELECT count(*) FROM users"

# Backup
bash scripts/turso-manage.sh backup myapp --output ./backups/
```

## Core Capabilities

1. Database lifecycle — Create, clone, inspect, and destroy databases
2. Auth token management — Generate scoped tokens with read-only and expiration options
3. SQL execution — Run queries, migrations, and interactive shells
4. Edge replication — Manage groups and add replica regions worldwide
5. Automated backups — Schedule daily/hourly backups with retention cleanup
6. Clone databases — Copy production to staging in one command
7. .env generation — Output connection strings ready for your app
8. Usage monitoring — Inspect row reads/writes and database size
9. Cron integration — Set up scheduled backups with one command
10. Local restore — Restore from SQL dumps or SQLite binary backups

## Dependencies
- `bash` (4.0+)
- `curl` (for Turso CLI installation)
- `turso` CLI (installed by included script)
- Optional: `jq`, `sqlite3`

## Installation Time
**5 minutes** — Run installer, authenticate, start managing databases
