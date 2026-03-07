---
name: nocodb-manager
description: >-
  Install, configure, and manage NocoDB — the open-source Airtable alternative that turns any database into a smart spreadsheet.
categories: [data, productivity]
dependencies: [docker, curl, jq]
---

# NocoDB Manager

## What This Does

Deploys and manages [NocoDB](https://github.com/nocodb/nocodb) — a self-hosted Airtable alternative with 50k+ GitHub stars. Turn any MySQL, PostgreSQL, or SQLite database into a collaborative spreadsheet with REST APIs, automations, and views (Grid, Gallery, Kanban, Form, Calendar).

**Example:** "Deploy NocoDB with PostgreSQL backend, create a project tracker table via API, set up automated backups."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Ensure Docker is installed
which docker || curl -fsSL https://get.docker.com | sh

# Ensure jq is available
which jq || sudo apt-get install -y jq
```

### 2. Deploy NocoDB

```bash
bash scripts/deploy.sh
# Starts NocoDB on port 8080 with SQLite (simplest setup)
# Output:
# ✅ NocoDB running at http://localhost:8080
# 📧 Admin signup: http://localhost:8080/#/signup
```

### 3. Deploy with PostgreSQL (Production)

```bash
bash scripts/deploy.sh --backend postgres --port 8080
# Deploys NocoDB + PostgreSQL in Docker Compose
# Output:
# ✅ NocoDB running at http://localhost:8080
# 🐘 PostgreSQL on port 5432
```

## Core Workflows

### Workflow 1: Deploy NocoDB (SQLite — Quick Start)

```bash
bash scripts/deploy.sh
```

Starts a single Docker container with SQLite. Good for personal use and testing.

### Workflow 2: Deploy with PostgreSQL (Production)

```bash
bash scripts/deploy.sh --backend postgres --port 8080 --data-dir /opt/nocodb
```

Creates a `docker-compose.yml` with NocoDB + PostgreSQL. Data persisted to host volume.

### Workflow 3: Deploy with MySQL

```bash
bash scripts/deploy.sh --backend mysql --port 8080
```

### Workflow 4: Create Tables via API

```bash
# Set your NocoDB URL and auth token
export NOCODB_URL="http://localhost:8080"
export NOCODB_TOKEN="your-api-token"

# Create a new table
bash scripts/api.sh create-table \
  --base "My Project" \
  --name "Tasks" \
  --columns '[
    {"title": "Title", "uidt": "SingleLineText"},
    {"title": "Status", "uidt": "SingleSelect", "dtxp": "Todo,In Progress,Done"},
    {"title": "Priority", "uidt": "SingleSelect", "dtxp": "Low,Medium,High"},
    {"title": "Due Date", "uidt": "Date"},
    {"title": "Assignee", "uidt": "SingleLineText"}
  ]'
```

### Workflow 5: Insert Records via API

```bash
bash scripts/api.sh insert-rows \
  --table "Tasks" \
  --rows '[
    {"Title": "Fix login bug", "Status": "In Progress", "Priority": "High"},
    {"Title": "Update docs", "Status": "Todo", "Priority": "Medium"}
  ]'
```

### Workflow 6: Query Records

```bash
# List all records
bash scripts/api.sh list-rows --table "Tasks"

# Filter records
bash scripts/api.sh list-rows --table "Tasks" --where "(Status,eq,In Progress)"

# Sort records
bash scripts/api.sh list-rows --table "Tasks" --sort "-Priority"
```

### Workflow 7: Backup NocoDB Data

```bash
bash scripts/backup.sh --output /backups/nocodb-$(date +%Y%m%d).tar.gz
# Exports database + uploaded files
```

### Workflow 8: Restore from Backup

```bash
bash scripts/backup.sh --restore /backups/nocodb-20260307.tar.gz
```

### Workflow 9: Update NocoDB

```bash
bash scripts/update.sh
# Pulls latest image, restarts with zero downtime
```

### Workflow 10: Health Check

```bash
bash scripts/health.sh
# Output:
# ✅ NocoDB: Running (v0.260.0)
# ✅ Database: Connected (PostgreSQL 16)
# ✅ Uptime: 14d 3h 22m
# ✅ Tables: 12 | Records: 4,832 | Bases: 3
# 💾 Disk: 1.2 GB used
```

## Configuration

### Environment Variables

```bash
# NocoDB settings
export NC_PORT=8080                    # Port to run on
export NC_DB="pg://localhost:5432?u=nc_user&p=secret&d=nocodb"  # Database URL
export NC_AUTH_JWT_SECRET="your-jwt-secret"  # JWT secret for auth
export NC_PUBLIC_URL="https://nocodb.example.com"  # Public URL (for email invites)

# SMTP for email notifications
export NC_SMTP_FROM="noreply@example.com"
export NC_SMTP_HOST="smtp.gmail.com"
export NC_SMTP_PORT=587
export NC_SMTP_USERNAME="user@gmail.com"
export NC_SMTP_PASSWORD="app-password"

# S3 for file attachments (optional)
export NC_S3_BUCKET_NAME="nocodb-attachments"
export NC_S3_REGION="us-east-1"
export NC_S3_ACCESS_KEY="AKIA..."
export NC_S3_ACCESS_SECRET="..."
```

### Reverse Proxy (Nginx)

```nginx
server {
    listen 80;
    server_name nocodb.example.com;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## Advanced Usage

### Run as Systemd Service

```bash
bash scripts/deploy.sh --systemd --backend postgres
# Creates /etc/systemd/system/nocodb.service
# Auto-starts on boot
```

### Automated Daily Backups

```bash
# Add to crontab
bash scripts/backup.sh --schedule daily --keep 7 --output /backups/nocodb/
# Creates cron job: daily backup, keeps last 7
```

### Connect External Database

```bash
# Point NocoDB at an existing database to get instant spreadsheet UI
bash scripts/deploy.sh --external-db "pg://host:5432?u=user&p=pass&d=mydb"
```

### API Token Management

```bash
# Generate API token
bash scripts/api.sh create-token --name "automation"

# List tokens
bash scripts/api.sh list-tokens

# Revoke token
bash scripts/api.sh revoke-token --name "automation"
```

## Troubleshooting

### Issue: "Port 8080 already in use"

```bash
# Use a different port
bash scripts/deploy.sh --port 8081

# Or find what's using 8080
sudo lsof -i :8080
```

### Issue: "Database connection failed"

```bash
# Check database is running
docker ps | grep postgres

# Check connection string
bash scripts/health.sh --verbose
```

### Issue: NocoDB won't start after update

```bash
# Check logs
docker logs nocodb --tail 50

# Roll back to previous version
bash scripts/update.sh --rollback
```

### Issue: Slow performance with large tables

```bash
# Check resource usage
bash scripts/health.sh --resources

# Increase memory limit
bash scripts/deploy.sh --memory 2g --restart
```

## Dependencies

- `docker` (20.10+) — Container runtime
- `docker-compose` (v2) — Multi-container orchestration
- `curl` — HTTP requests
- `jq` — JSON parsing
- Optional: `nginx` for reverse proxy
- Optional: `certbot` for SSL
