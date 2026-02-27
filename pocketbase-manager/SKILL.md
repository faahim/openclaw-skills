---
name: pocketbase-manager
description: >-
  Install, configure, manage, and backup PocketBase instances with systemd integration and automated backups.
categories: [dev-tools, automation]
dependencies: [bash, curl, jq, systemd]
---

# PocketBase Manager

## What This Does

Install and manage PocketBase — the open-source backend in a single file. Deploy instances, configure systemd services, automate backups, manage collections via the API, and monitor health.

**Example:** "Install PocketBase 0.25, set up as systemd service on port 8090, configure daily backups to S3, check health every 5 minutes."

## Quick Start (5 minutes)

### 1. Install PocketBase

```bash
# Install latest PocketBase (auto-detects OS/arch)
bash scripts/install.sh

# Or install a specific version
bash scripts/install.sh --version 0.25.9

# Verify installation
pocketbase --version
```

### 2. Create & Start an Instance

```bash
# Initialize a new PocketBase instance
bash scripts/manage.sh init --name myapp --port 8090

# Start it (foreground for testing)
bash scripts/manage.sh start --name myapp

# Or install as systemd service (recommended for production)
bash scripts/manage.sh service --name myapp --enable
```

### 3. Set Up Automated Backups

```bash
# Backup to local directory
bash scripts/backup.sh --name myapp --dest /backups/pocketbase

# Backup to S3-compatible storage
bash scripts/backup.sh --name myapp --s3 s3://mybucket/pocketbase-backups

# Schedule daily backups via cron
bash scripts/backup.sh --name myapp --dest /backups/pocketbase --schedule daily
```

## Core Workflows

### Workflow 1: Fresh Deployment

**Use case:** Deploy PocketBase on a fresh VPS

```bash
# Full deployment: install + init + systemd + Caddy reverse proxy
bash scripts/deploy.sh \
  --name myapp \
  --port 8090 \
  --domain api.myapp.com \
  --with-caddy \
  --backup-dest /backups/pocketbase
```

**What it does:**
1. Downloads and installs PocketBase binary
2. Creates data directory at `/opt/pocketbase/myapp`
3. Sets up systemd service with auto-restart
4. Configures Caddy reverse proxy with auto-SSL
5. Sets up daily backup cron job
6. Creates admin account (interactive prompt)

### Workflow 2: Collection Management

**Use case:** Create/list/export collections via API

```bash
# List all collections
bash scripts/api.sh collections list --url http://localhost:8090

# Export collection schema (for version control)
bash scripts/api.sh collections export --url http://localhost:8090 --output schema.json

# Import collection schema
bash scripts/api.sh collections import --url http://localhost:8090 --input schema.json

# Create a collection from JSON
bash scripts/api.sh collections create --url http://localhost:8090 --json '{
  "name": "posts",
  "type": "base",
  "schema": [
    {"name": "title", "type": "text", "required": true},
    {"name": "content", "type": "editor"},
    {"name": "published", "type": "bool"}
  ]
}'
```

### Workflow 3: Health Monitoring

**Use case:** Check if PocketBase instances are healthy

```bash
# Single instance health check
bash scripts/health.sh --url http://localhost:8090

# Monitor all managed instances
bash scripts/health.sh --all

# Output:
# ✅ myapp (http://localhost:8090) — UP (12ms) — DB: 45MB — Records: 12,345
# ✅ staging (http://localhost:8091) — UP (8ms) — DB: 2MB — Records: 234
# ❌ legacy (http://localhost:8092) — DOWN — Last seen: 2h ago
```

### Workflow 4: Backup & Restore

**Use case:** Disaster recovery

```bash
# Create backup with timestamp
bash scripts/backup.sh --name myapp --dest /backups

# List available backups
bash scripts/backup.sh --name myapp --list

# Restore from backup (stops service, replaces data, restarts)
bash scripts/backup.sh --name myapp --restore /backups/myapp-2026-02-27T12-00-00.zip

# Restore from S3
bash scripts/backup.sh --name myapp --restore s3://mybucket/pocketbase-backups/myapp-latest.zip
```

### Workflow 5: Upgrade PocketBase

**Use case:** Upgrade to a new version safely

```bash
# Check current vs latest version
bash scripts/manage.sh version --name myapp

# Upgrade with automatic backup
bash scripts/manage.sh upgrade --name myapp

# What it does:
# 1. Creates backup of current data
# 2. Downloads new PocketBase binary
# 3. Stops service
# 4. Replaces binary
# 5. Runs migrations
# 6. Restarts service
# 7. Verifies health
```

## Configuration

### Instance Config

Each instance is stored at `/opt/pocketbase/<name>/`:

```
/opt/pocketbase/myapp/
├── pocketbase          # Binary (symlink to /usr/local/bin/pocketbase)
├── pb_data/            # Database and uploads
├── pb_migrations/      # Migration files
├── pb_hooks/           # JS hooks (optional)
└── config.yaml         # Instance config (our addition)
```

### config.yaml

```yaml
# /opt/pocketbase/myapp/config.yaml
name: myapp
port: 8090
host: 0.0.0.0
data_dir: /opt/pocketbase/myapp/pb_data
backup:
  enabled: true
  schedule: "0 2 * * *"  # Daily at 2am
  dest: /backups/pocketbase
  retention: 30  # days
  s3:
    bucket: ""
    prefix: ""
    endpoint: ""  # For non-AWS S3 (MinIO, Backblaze, etc.)
```

### Environment Variables

```bash
# Admin API token (for scripted operations)
export PB_ADMIN_TOKEN="<your-admin-token>"

# Default PocketBase URL
export PB_URL="http://localhost:8090"

# S3 credentials (for cloud backups)
export AWS_ACCESS_KEY_ID="<key>"
export AWS_SECRET_ACCESS_KEY="<secret>"
export AWS_DEFAULT_REGION="us-east-1"
```

## Advanced Usage

### Run Multiple Instances

```bash
# Create instances on different ports
bash scripts/manage.sh init --name api-prod --port 8090
bash scripts/manage.sh init --name api-staging --port 8091
bash scripts/manage.sh init --name api-dev --port 8092

# Enable all as services
bash scripts/manage.sh service --name api-prod --enable
bash scripts/manage.sh service --name api-staging --enable

# List all instances
bash scripts/manage.sh list
# NAME         PORT  STATUS   DB_SIZE  UPTIME
# api-prod     8090  running  45MB     12d 3h
# api-staging  8091  running  2MB      5d 1h
# api-dev      8092  stopped  512KB    -
```

### Schema Version Control

```bash
# Export schema to JSON (commit to git)
bash scripts/api.sh collections export --url http://localhost:8090 > schema.json
git add schema.json && git commit -m "Update PB schema"

# Apply schema to another instance (staging → prod)
bash scripts/api.sh collections import \
  --url http://prod:8090 \
  --input schema.json \
  --admin-token "$PB_ADMIN_TOKEN"
```

### Logs & Debugging

```bash
# View service logs
bash scripts/manage.sh logs --name myapp --lines 100

# Follow logs in real-time
bash scripts/manage.sh logs --name myapp --follow

# Check request stats
bash scripts/api.sh stats --url http://localhost:8090
```

## Troubleshooting

### Issue: "permission denied" on install

**Fix:**
```bash
sudo bash scripts/install.sh
```

### Issue: Port already in use

**Fix:**
```bash
# Check what's using the port
sudo lsof -i :8090

# Use a different port
bash scripts/manage.sh init --name myapp --port 8091
```

### Issue: Service won't start

**Check:**
```bash
# View systemd status
sudo systemctl status pocketbase-myapp

# Check logs
sudo journalctl -u pocketbase-myapp -n 50

# Common fix: permissions on data directory
sudo chown -R pocketbase:pocketbase /opt/pocketbase/myapp
```

### Issue: Backup fails to S3

**Check:**
1. AWS credentials: `aws sts get-caller-identity`
2. Bucket access: `aws s3 ls s3://mybucket/`
3. awscli installed: `which aws || pip install awscli`

## Dependencies

- `bash` (4.0+)
- `curl` (download binary, API calls)
- `jq` (JSON parsing)
- `systemd` (service management, Linux only)
- Optional: `aws` CLI (S3 backups)
- Optional: `caddy` (reverse proxy with auto-SSL)
