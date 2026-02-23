---
name: n8n-workflow-automation
description: >-
  Deploy and manage n8n — a self-hosted workflow automation platform with 400+ integrations.
categories: [automation, productivity]
dependencies: [docker, bash, curl]
---

# n8n Workflow Automation

## What This Does

Deploy n8n — a self-hosted, open-source workflow automation platform (like Zapier, but free and private). Connect 400+ services, build visual workflows, trigger on webhooks/schedules/events. Runs entirely on your machine via Docker.

**Example:** "Auto-post new RSS items to Slack, save attachments to S3, and log everything to a Google Sheet — all without writing code."

## Quick Start (5 minutes)

### 1. Check Prerequisites

```bash
# Verify Docker is installed
docker --version || { echo "❌ Docker required. Install: https://docs.docker.com/get-docker/"; exit 1; }

# Verify Docker Compose
docker compose version 2>/dev/null || docker-compose --version || { echo "❌ Docker Compose required"; exit 1; }
```

### 2. Deploy n8n

```bash
# One-command deploy with persistent data
bash scripts/deploy.sh

# n8n will be available at http://localhost:5678
# First visit: create your admin account
```

### 3. Verify It's Running

```bash
bash scripts/status.sh
# Output:
# ✅ n8n is running at http://localhost:5678
# 📊 Version: 1.x.x
# 💾 Data: /home/clawd/.n8n (persistent)
# ⏱️ Uptime: 2 minutes
```

## Core Workflows

### Workflow 1: Deploy n8n (Fresh Install)

```bash
bash scripts/deploy.sh
```

Deploys n8n with:
- Persistent SQLite database at `~/.n8n`
- Webhook support enabled
- Timezone set to system timezone
- Auto-restart on reboot

### Workflow 2: Deploy with PostgreSQL (Production)

```bash
bash scripts/deploy.sh --postgres
```

Deploys n8n + PostgreSQL for production workloads:
- PostgreSQL for reliable data storage
- Connection pooling
- Automatic backups via pg_dump

### Workflow 3: Update n8n

```bash
bash scripts/update.sh
# Pulls latest image, recreates container, preserves data
```

### Workflow 4: Backup & Restore

```bash
# Export all workflows to JSON
bash scripts/backup.sh --output ~/n8n-backup-$(date +%Y%m%d).json

# Restore from backup
bash scripts/backup.sh --restore ~/n8n-backup-20260223.json
```

### Workflow 5: Import a Workflow Template

```bash
# Import a workflow from JSON file
bash scripts/import-workflow.sh examples/rss-to-slack.json

# Import from n8n community URL
bash scripts/import-workflow.sh --url "https://n8n.io/workflows/1234"
```

### Workflow 6: Configure Reverse Proxy (HTTPS)

```bash
# Deploy with Caddy reverse proxy for automatic HTTPS
bash scripts/deploy.sh --domain n8n.yourdomain.com --https

# This sets up:
# - Caddy reverse proxy with auto-SSL
# - n8n accessible at https://n8n.yourdomain.com
# - Webhook URL auto-configured
```

### Workflow 7: Stop / Start / Restart

```bash
bash scripts/control.sh stop
bash scripts/control.sh start
bash scripts/control.sh restart
bash scripts/control.sh logs        # Tail logs
bash scripts/control.sh logs 100    # Last 100 lines
```

## Configuration

### Environment Variables

```bash
# Core settings (set in .env or export)
export N8N_PORT=5678                          # Web UI port
export N8N_PROTOCOL=http                       # http or https
export N8N_HOST=localhost                       # Hostname
export N8N_ENCRYPTION_KEY="your-secret-key"    # Encrypt credentials (IMPORTANT)
export GENERIC_TIMEZONE="UTC"                  # Timezone

# Webhook settings
export WEBHOOK_URL="https://n8n.yourdomain.com"  # External webhook URL
export N8N_WEBHOOK_TUNNEL_URL=""               # If using tunnel (ngrok/cloudflared)

# Execution settings
export EXECUTIONS_DATA_PRUNE=true              # Auto-delete old executions
export EXECUTIONS_DATA_MAX_AGE=168             # Keep 7 days (hours)

# Email (for error notifications)
export N8N_EMAIL_MODE=smtp
export N8N_SMTP_HOST=smtp.gmail.com
export N8N_SMTP_PORT=587
export N8N_SMTP_USER=your@email.com
export N8N_SMTP_PASS=your-app-password
export N8N_SMTP_SENDER=your@email.com
```

### Docker Compose Override

Edit `~/.n8n/docker-compose.override.yml` to customize:

```yaml
services:
  n8n:
    environment:
      - N8N_METRICS=true           # Enable Prometheus metrics
      - N8N_LOG_LEVEL=debug        # debug/info/warn/error
      - N8N_CONCURRENCY=10         # Max parallel executions
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'
```

## Advanced Usage

### Expose Webhooks via Cloudflare Tunnel

```bash
# Install cloudflared (if not installed)
bash scripts/tunnel.sh --install

# Create tunnel to n8n
bash scripts/tunnel.sh --domain n8n.yourdomain.com
# Automatically configures N8N_WEBHOOK_TUNNEL_URL
```

### Set Up n8n as a Cron Replacement

n8n can replace complex crontab setups. Create a "Cron" trigger node in n8n UI:
- Every 5 minutes: `*/5 * * * *`
- Daily at 9am: `0 9 * * *`
- Weekly on Monday: `0 0 * * 1`

### Multi-User Setup

```bash
# Deploy with user management enabled
bash scripts/deploy.sh --multi-user

# This enables:
# - User registration (admin approves)
# - Role-based access (admin/member)
# - Workflow sharing between users
```

### Monitor n8n Health

```bash
# Check if n8n API is responding
bash scripts/health.sh

# Output:
# ✅ API: healthy (response: 45ms)
# ✅ Webhooks: active
# 📊 Workflows: 12 active, 3 inactive
# 📊 Executions (24h): 847 success, 2 errors
# 💾 Disk: 234MB used
```

## Troubleshooting

### Issue: "Port 5678 already in use"

```bash
# Find what's using the port
lsof -i :5678
# Change port
N8N_PORT=5679 bash scripts/deploy.sh
```

### Issue: Webhooks not receiving data

1. Check webhook URL: `bash scripts/status.sh` — verify WEBHOOK_URL
2. Test webhook: `curl -X POST http://localhost:5678/webhook-test/<id> -d '{"test":true}'`
3. Check firewall: `sudo ufw status` — ensure port is open
4. If behind NAT: use `bash scripts/tunnel.sh` for Cloudflare tunnel

### Issue: n8n running slow

```bash
# Check resource usage
docker stats n8n --no-stream

# Prune old executions
bash scripts/maintenance.sh --prune-executions --older-than 72h

# Increase memory limit
# Edit docker-compose.override.yml: memory: 4G
bash scripts/control.sh restart
```

### Issue: Lost encryption key

⚠️ Without the encryption key, saved credentials are unrecoverable.
```bash
# Check current key
docker exec n8n env | grep N8N_ENCRYPTION_KEY

# Always back up your encryption key!
```

## Examples

See `examples/` for ready-to-import workflow templates:
- `rss-to-slack.json` — Post new RSS items to Slack
- `github-to-telegram.json` — Notify on new GitHub issues
- `form-to-sheets.json` — Webhook form submissions to Google Sheets
- `daily-report.json` — Aggregate metrics and email daily summary

## Dependencies

- `docker` (20.10+) with Docker Compose
- `bash` (4.0+)
- `curl` (for API calls and health checks)
- Optional: `cloudflared` (for webhook tunneling)
- Optional: Domain name + DNS (for HTTPS setup)

## Key Principles

1. **Data stays local** — Everything runs on your machine, no cloud dependency
2. **Persistent storage** — Workflows and credentials survive container restarts
3. **Auto-restart** — Container restarts on reboot via Docker restart policy
4. **Encryption** — Credentials encrypted at rest with N8N_ENCRYPTION_KEY
5. **Backups** — Export/import workflows as JSON for easy migration
