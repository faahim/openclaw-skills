# Listing Copy: NocoDB Manager

## Metadata
- **Type:** Skill
- **Name:** nocodb-manager
- **Display Name:** NocoDB Manager
- **Categories:** [data, productivity]
- **Price:** $12
- **Icon:** 📊
- **Dependencies:** [docker, curl, jq]

## Tagline

Deploy and manage NocoDB — turn any database into a smart spreadsheet with REST APIs

## Description

Manually setting up database-backed spreadsheet tools means juggling Docker configs, database connections, and API integrations. Most teams end up paying $20+/month for Airtable when they could self-host for free.

NocoDB Manager deploys and manages NocoDB — the open-source Airtable alternative with 50k+ GitHub stars. One command gives you a full spreadsheet UI with Grid, Gallery, Kanban, Form, and Calendar views, plus a complete REST API. No monthly fees, your data stays on your server.

**What it does:**
- 🚀 One-command deploy with SQLite, PostgreSQL, or MySQL backends
- 📊 Full REST API client for tables, records, and token management
- 💾 Automated backups with scheduling and rotation
- 🔄 Zero-downtime updates with rollback support
- 🏥 Health checks for containers, database, and disk usage
- ⚙️ Systemd service integration for production deployments
- 🔗 Connect to existing databases for instant spreadsheet UI

Perfect for developers and teams who want Airtable-like functionality without vendor lock-in or recurring costs.

## Quick Start Preview

```bash
# Deploy NocoDB with PostgreSQL
bash scripts/deploy.sh --backend postgres

# Output:
# ✅ NocoDB running at http://localhost:8080
# 🐘 PostgreSQL on port 5432
# 📧 Admin signup: http://localhost:8080/#/signup
```

## Core Capabilities

1. One-command deployment — SQLite, PostgreSQL, or MySQL backends
2. REST API client — Create tables, insert/query/update records from CLI
3. External database connection — Point at existing DB for instant spreadsheet UI
4. Automated backups — Daily/weekly with configurable retention
5. One-click restore — Restore from any backup with data + config
6. Zero-downtime updates — Pull latest image, restart, auto-rollback on failure
7. Health monitoring — Container status, database connectivity, disk usage
8. Systemd integration — Auto-start on boot, proper service management
9. Docker Compose — Multi-service orchestration for production setups
10. Token management — Create, list, and revoke API tokens

## Dependencies
- `docker` (20.10+)
- `docker-compose` (v2)
- `curl`
- `jq`

## Installation Time
**5 minutes** — Run deploy script, access web UI
