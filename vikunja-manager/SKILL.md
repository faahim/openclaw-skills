---
name: vikunja-manager
description: >-
  Install, configure, and manage a self-hosted Vikunja task/project management server with Kanban boards, lists, and CalDAV sync.
categories: [productivity, automation]
dependencies: [docker, curl, jq]
---

# Vikunja Manager

## What This Does

Deploy and manage a self-hosted **Vikunja** instance — a powerful open-source task and project management tool. Supports Kanban boards, Gantt charts, CalDAV sync, file attachments, labels, priorities, reminders, and team collaboration. Replace Todoist/Trello/Notion boards with something you own.

**Example:** "Set up a Vikunja server on port 3456, create projects via API, back up the database, and sync tasks with your calendar app."

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Ensure Docker is installed
which docker || curl -fsSL https://get.docker.com | sh

# Ensure docker compose is available
docker compose version || echo "Install docker compose plugin"
```

### 2. Deploy Vikunja

```bash
# Create working directory
mkdir -p ~/vikunja && cd ~/vikunja

# Generate config
cat > docker-compose.yml << 'COMPOSE'
services:
  vikunja:
    image: vikunja/vikunja:latest
    container_name: vikunja
    restart: unless-stopped
    ports:
      - "3456:3456"
    volumes:
      - ./files:/app/vikunja/files
      - ./db:/db
    environment:
      VIKUNJA_SERVICE_JWTSECRET: "$(openssl rand -hex 32)"
      VIKUNJA_SERVICE_PUBLICURL: "http://localhost:3456"
      VIKUNJA_DATABASE_TYPE: "sqlite"
      VIKUNJA_DATABASE_PATH: "/db/vikunja.db"
      VIKUNJA_SERVICE_ENABLEREGISTRATION: "true"
      VIKUNJA_MAILER_ENABLED: "false"
COMPOSE

# Start the server
docker compose up -d

echo "✅ Vikunja running at http://localhost:3456"
echo "Create your account at the web UI, then disable registration if desired."
```

### 3. Create Admin Account

```bash
# Open the web UI and register, OR use the API:
curl -s -X POST http://localhost:3456/api/v1/register \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"changeme123!","email":"admin@local.host"}' | jq .
```

## Core Workflows

### Workflow 1: Deploy with Custom Domain (Reverse Proxy)

```bash
# Set public URL for your domain
cd ~/vikunja

# Update environment
sed -i 's|VIKUNJA_SERVICE_PUBLICURL:.*|VIKUNJA_SERVICE_PUBLICURL: "https://tasks.yourdomain.com"|' docker-compose.yml

docker compose up -d --force-recreate
```

### Workflow 2: API — Create Projects & Tasks

```bash
# Login and get token
TOKEN=$(curl -s -X POST http://localhost:3456/api/v1/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"changeme123!"}' | jq -r '.token')

# Create a project
curl -s -X PUT http://localhost:3456/api/v1/projects \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"title":"My Project","description":"Managed by OpenClaw"}' | jq .

# List projects
curl -s http://localhost:3456/api/v1/projects \
  -H "Authorization: Bearer $TOKEN" | jq '.[].title'

# Create a task in project (replace PROJECT_ID)
PROJECT_ID=1
curl -s -X PUT "http://localhost:3456/api/v1/projects/$PROJECT_ID/tasks" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Review pull requests",
    "priority": 3,
    "due_date": "2026-03-10T17:00:00Z",
    "labels": [{"title":"dev"}]
  }' | jq .
```

### Workflow 3: Backup & Restore

```bash
# Backup database
cd ~/vikunja
docker compose stop
cp db/vikunja.db "db/vikunja-backup-$(date +%Y%m%d).db"
tar czf "vikunja-backup-$(date +%Y%m%d).tar.gz" db/ files/
docker compose start

echo "✅ Backup saved"

# Restore from backup
# docker compose stop
# tar xzf vikunja-backup-YYYYMMDD.tar.gz
# docker compose start
```

### Workflow 4: CalDAV Sync

Connect your calendar app (Thunderbird, Apple Calendar, DAVx5 on Android):

```
CalDAV URL: http://localhost:3456/dav/principals/admin/
Username: admin
Password: changeme123!
```

Tasks and due dates sync bidirectionally with any CalDAV client.

### Workflow 5: Enable Email Notifications

```bash
cd ~/vikunja
cat >> docker-compose.yml << 'EOF'
    # Add to vikunja service environment:
    # VIKUNJA_MAILER_ENABLED: "true"
    # VIKUNJA_MAILER_HOST: "smtp.gmail.com"
    # VIKUNJA_MAILER_PORT: "587"
    # VIKUNJA_MAILER_USERNAME: "you@gmail.com"
    # VIKUNJA_MAILER_PASSWORD: "app-password"
    # VIKUNJA_MAILER_FROMEMAIL: "you@gmail.com"
EOF

echo "Edit docker-compose.yml to uncomment and fill in SMTP settings, then:"
echo "docker compose up -d --force-recreate"
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VIKUNJA_SERVICE_PUBLICURL` | `http://localhost:3456` | Public-facing URL |
| `VIKUNJA_SERVICE_ENABLEREGISTRATION` | `true` | Allow new signups |
| `VIKUNJA_DATABASE_TYPE` | `sqlite` | `sqlite` or `postgres` or `mysql` |
| `VIKUNJA_SERVICE_JWTSECRET` | (random) | JWT signing secret |
| `VIKUNJA_MAILER_ENABLED` | `false` | Enable email notifications |
| `VIKUNJA_SERVICE_MAXAVATARSIZE` | `1024` | Max avatar size in bytes |

### PostgreSQL Setup (Production)

```yaml
services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: vikunja
      POSTGRES_PASSWORD: supersecret
      POSTGRES_DB: vikunja
    volumes:
      - ./pgdata:/var/lib/postgresql/data

  vikunja:
    image: vikunja/vikunja:latest
    restart: unless-stopped
    ports:
      - "3456:3456"
    depends_on:
      - db
    environment:
      VIKUNJA_DATABASE_TYPE: "postgres"
      VIKUNJA_DATABASE_HOST: "db"
      VIKUNJA_DATABASE_USER: "vikunja"
      VIKUNJA_DATABASE_PASSWORD: "supersecret"
      VIKUNJA_DATABASE_DATABASE: "vikunja"
      VIKUNJA_SERVICE_JWTSECRET: "your-secret-here"
      VIKUNJA_SERVICE_PUBLICURL: "https://tasks.yourdomain.com"
    volumes:
      - ./files:/app/vikunja/files
```

## Management Commands

```bash
# Status check
docker ps --filter name=vikunja --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# View logs
docker logs vikunja --tail 50

# Update to latest version
cd ~/vikunja && docker compose pull && docker compose up -d

# Stop
docker compose -f ~/vikunja/docker-compose.yml stop

# Restart
docker compose -f ~/vikunja/docker-compose.yml restart

# Full cleanup (WARNING: deletes data)
# docker compose -f ~/vikunja/docker-compose.yml down -v
```

## Advanced Usage

### Run as OpenClaw Cron (Daily Backup)

```bash
# Backup Vikunja database daily at 2 AM
0 2 * * * cd ~/vikunja && docker compose exec -T vikunja sh -c "cp /db/vikunja.db /db/vikunja-daily.db" 2>/dev/null
```

### Disable Registration After Setup

```bash
cd ~/vikunja
sed -i 's|VIKUNJA_SERVICE_ENABLEREGISTRATION:.*|VIKUNJA_SERVICE_ENABLEREGISTRATION: "false"|' docker-compose.yml
docker compose up -d --force-recreate
```

### OpenID Connect (SSO)

```bash
# Add to environment in docker-compose.yml:
# VIKUNJA_AUTH_OPENID_ENABLED: "true"
# VIKUNJA_AUTH_OPENID_PROVIDERS: '[{"name":"provider","authurl":"https://auth.example.com","clientid":"vikunja","clientsecret":"secret"}]'
```

## Troubleshooting

### Issue: "port 3456 already in use"

**Fix:** Change the port mapping:
```bash
sed -i 's|3456:3456|3457:3456|' ~/vikunja/docker-compose.yml
docker compose up -d
```

### Issue: Permission denied on volumes

**Fix:**
```bash
sudo chown -R 1000:1000 ~/vikunja/files ~/vikunja/db
```

### Issue: CalDAV not connecting

**Check:**
1. Ensure `VIKUNJA_SERVICE_PUBLICURL` matches the URL you're using
2. Some CalDAV clients need trailing slash: `http://host:3456/dav/principals/username/`
3. Check logs: `docker logs vikunja | grep -i dav`

## Dependencies

- `docker` (with compose plugin)
- `curl` (API calls)
- `jq` (JSON parsing)
- `openssl` (secret generation)
