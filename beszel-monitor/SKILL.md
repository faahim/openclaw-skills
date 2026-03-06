---
name: beszel-monitor
description: >-
  Install and manage Beszel — a lightweight self-hosted server monitoring hub with historical data, Docker stats, and alerts.
categories: [automation, analytics]
dependencies: [docker, curl]
---

# Beszel Server Monitor

## What This Does

Deploy Beszel — a lightweight, self-hosted server monitoring platform that tracks CPU, memory, disk, network, GPU, temperature, and Docker container stats with historical data and configurable alerts. Built on PocketBase, it's far lighter than Prometheus+Grafana stacks while providing a beautiful web dashboard.

**Example:** "Monitor 5 servers with Docker stats, get Telegram alerts when CPU > 80% or disk > 90%, view 30 days of history in a web dashboard."

## Quick Start (5 minutes)

### 1. Deploy Beszel Hub (Docker)

```bash
# Create data directory
mkdir -p /opt/beszel/data

# Run the hub
docker run -d \
  --name beszel-hub \
  --restart unless-stopped \
  -p 8090:8090 \
  -v /opt/beszel/data:/beszel_data \
  henrygd/beszel:latest

echo "✅ Beszel hub running at http://$(hostname -I | awk '{print $1}'):8090"
echo "Open the URL and create your admin account."
```

### 2. Deploy Beszel Agent (on each monitored server)

```bash
# Install agent via official script (recommended)
curl -sL https://get.beszel.dev | bash

# OR run as Docker container
docker run -d \
  --name beszel-agent \
  --restart unless-stopped \
  --network host \
  --pid host \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e KEY="<your-ssh-key-from-hub>" \
  -e PORT=45876 \
  henrygd/beszel-agent:latest
```

### 3. Connect Agent to Hub

1. Open hub dashboard → **Add System**
2. Enter agent hostname/IP and port (default: 45876)
3. Copy the SSH key shown → paste as `KEY` env var when starting agent
4. Agent connects automatically within seconds

## Core Workflows

### Workflow 1: Single Server + Docker Monitoring

**Use case:** Monitor one server with all its Docker containers.

```bash
# On the server, run both hub and agent
# Hub
docker run -d \
  --name beszel-hub \
  --restart unless-stopped \
  -p 8090:8090 \
  -v /opt/beszel/data:/beszel_data \
  henrygd/beszel:latest

# Agent (same machine)
docker run -d \
  --name beszel-agent \
  --restart unless-stopped \
  --network host \
  --pid host \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -e KEY="<ssh-key-from-hub>" \
  -e PORT=45876 \
  henrygd/beszel-agent:latest
```

**Monitored metrics:**
- CPU, memory, swap, load average
- Disk usage & I/O (all partitions)
- Network bandwidth (all interfaces)
- Temperature sensors, GPU usage
- Per-container CPU, memory, network

### Workflow 2: Multi-Server Fleet Monitoring

**Use case:** Central hub monitoring multiple servers.

```bash
# On hub server (e.g., 10.0.0.1)
docker run -d \
  --name beszel-hub \
  --restart unless-stopped \
  -p 8090:8090 \
  -v /opt/beszel/data:/beszel_data \
  henrygd/beszel:latest

# On each remote server, install agent
# Server 2 (10.0.0.2)
ssh user@10.0.0.2 'curl -sL https://get.beszel.dev | bash'

# Server 3 (10.0.0.3)
ssh user@10.0.0.3 'curl -sL https://get.beszel.dev | bash'
```

Then add each server via the hub dashboard.

### Workflow 3: Set Up Alerts

**Use case:** Get notified when resources exceed thresholds.

In the Beszel dashboard:
1. Go to **Settings → Notifications**
2. Add notification target (Telegram, Slack, email, webhook, ntfy, Gotify, etc.)
3. Go to a system → **Alerts** tab
4. Configure thresholds:
   - CPU > 80% for 5 min
   - Memory > 90%
   - Disk > 85%
   - Network > 100 Mbps
   - Temperature > 75°C
   - Container stopped

**Telegram setup:**
```
Bot token: <your-telegram-bot-token>
Chat ID: <your-chat-id>
```

### Workflow 4: Automatic Backups

**Use case:** Back up monitoring data to S3-compatible storage.

In dashboard → **Settings → Backups**:
- Enable automatic backups
- Set schedule (daily recommended)
- Configure S3 bucket (works with AWS S3, MinIO, Backblaze B2, etc.)
- Test backup to verify

### Workflow 5: Binary Install (No Docker)

**Use case:** Run on systems without Docker.

```bash
# Download latest hub binary
curl -sL https://github.com/henrygd/beszel/releases/latest/download/beszel_linux_$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/') \
  -o /usr/local/bin/beszel
chmod +x /usr/local/bin/beszel

# Run hub
beszel serve --http 0.0.0.0:8090 --dir /opt/beszel/data

# Download agent binary
curl -sL https://github.com/henrygd/beszel/releases/latest/download/beszel-agent_linux_$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/') \
  -o /usr/local/bin/beszel-agent
chmod +x /usr/local/bin/beszel-agent

# Run agent
KEY="<ssh-key>" PORT=45876 beszel-agent
```

### Workflow 6: Create Systemd Service

```bash
# Hub service
cat > /etc/systemd/system/beszel-hub.service << 'EOF'
[Unit]
Description=Beszel Hub
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/beszel serve --http 0.0.0.0:8090 --dir /opt/beszel/data
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Agent service
cat > /etc/systemd/system/beszel-agent.service << 'EOF'
[Unit]
Description=Beszel Agent
After=network.target

[Service]
Type=simple
Environment="KEY=<your-ssh-key>"
Environment="PORT=45876"
ExecStart=/usr/local/bin/beszel-agent
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now beszel-hub
systemctl enable --now beszel-agent
```

## Configuration

### Environment Variables (Agent)

```bash
# Required
KEY="<ssh-public-key-from-hub>"    # SSH key for hub connection
PORT=45876                          # Agent listening port

# Optional
DOCKER_HOST="/var/run/docker.sock"  # Custom Docker socket path
FILESYSTEM="/dev/sda1"              # Monitor specific filesystem
EXTRA_FILESYSTEMS="/dev/sdb1,/dev/sdc1"  # Additional filesystems
NICS="eth0,wlan0"                   # Specific network interfaces
GPU="true"                          # Enable GPU monitoring
SENSORS="true"                      # Enable temperature sensors
```

### Environment Variables (Hub)

```bash
# Default admin
BESZEL_ADMIN_EMAIL="admin@example.com"
BESZEL_ADMIN_PASSWORD="changeme"

# SMTP (for email alerts)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USERNAME="user@gmail.com"
SMTP_PASSWORD="app-password"
```

### Docker Compose (Recommended for Production)

```yaml
# docker-compose.yml
version: '3'
services:
  beszel-hub:
    image: henrygd/beszel:latest
    container_name: beszel-hub
    restart: unless-stopped
    ports:
      - "8090:8090"
    volumes:
      - ./data:/beszel_data
    environment:
      - TZ=UTC

  beszel-agent:
    image: henrygd/beszel-agent:latest
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    pid: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - KEY=${BESZEL_KEY}
      - PORT=45876
```

```bash
# Start
docker compose up -d

# View logs
docker compose logs -f
```

## Advanced Usage

### Reverse Proxy with Nginx

```nginx
server {
    listen 443 ssl;
    server_name beszel.yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/beszel.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/beszel.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### OAuth/OIDC Setup

In dashboard → **Settings → Auth Providers**:
- Google, GitHub, Microsoft, Apple, Discord, OIDC
- Password auth can be disabled after OAuth configured

### API Access

```bash
# Authenticate
TOKEN=$(curl -s http://localhost:8090/api/admins/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity":"admin@example.com","password":"yourpassword"}' \
  | jq -r '.token')

# List systems
curl -s http://localhost:8090/api/collections/systems/records \
  -H "Authorization: $TOKEN" | jq .

# Get system metrics
curl -s "http://localhost:8090/api/collections/system_stats/records?filter=system='SYSTEM_ID'" \
  -H "Authorization: $TOKEN" | jq .
```

### Multi-User Setup

1. Hub admin creates user accounts
2. Admin assigns systems to users
3. Each user sees only their assigned systems
4. Users can configure their own alerts

## Monitoring Check Script

```bash
#!/bin/bash
# Check if Beszel hub and agent are running

echo "=== Beszel Status ==="

# Check hub
if docker ps --format '{{.Names}}' | grep -q beszel-hub; then
  echo "✅ Hub: Running"
  echo "   URL: http://$(hostname -I | awk '{print $1}'):8090"
else
  echo "❌ Hub: Not running"
fi

# Check agent
if docker ps --format '{{.Names}}' | grep -q beszel-agent; then
  echo "✅ Agent: Running"
elif systemctl is-active --quiet beszel-agent 2>/dev/null; then
  echo "✅ Agent: Running (systemd)"
else
  echo "❌ Agent: Not running"
fi

# Check hub health
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8090/api/health 2>/dev/null)
if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ Hub API: Healthy"
else
  echo "❌ Hub API: Unhealthy (HTTP $HTTP_CODE)"
fi
```

## Troubleshooting

### Agent not connecting to hub

**Check:**
1. SSH key matches: `echo $KEY` on agent matches key shown in hub
2. Port accessible: `nc -zv <hub-ip> 8090`
3. Agent port open: `ss -tlnp | grep 45876`
4. Firewall allows port 45876: `ufw allow 45876` or `firewall-cmd --add-port=45876/tcp`

### Docker stats not showing

**Check:**
1. Docker socket mounted: `-v /var/run/docker.sock:/var/run/docker.sock:ro`
2. Agent has read access to socket
3. For Podman: mount `/run/podman/podman.sock` instead

### High memory usage

Beszel is designed to be lightweight (~50MB RAM for hub, ~15MB for agent). If higher:
1. Check data retention settings
2. Reduce monitored metrics if not needed
3. Ensure automatic cleanup is enabled

### GPU not detected

```bash
# Nvidia: ensure nvidia-smi is available
nvidia-smi

# AMD: ensure rocm-smi is available
rocm-smi

# Set GPU=true env var on agent
```

## Why Beszel vs Alternatives

| Feature | Beszel | Prometheus+Grafana | Netdata | Uptime Kuma |
|---------|--------|-------------------|---------|-------------|
| RAM usage | ~50MB | ~500MB+ | ~300MB | ~100MB |
| Setup time | 5 min | 30+ min | 10 min | 5 min |
| Docker stats | ✅ | Plugin needed | ✅ | ❌ |
| Historical data | ✅ | ✅ | Limited free | ❌ |
| Alerts | ✅ | ✅ | ✅ | ✅ |
| Multi-user | ✅ | ✅ | ❌ | ❌ |
| OAuth/OIDC | ✅ | Plugin | ❌ | ❌ |
| S3 backups | ✅ | Manual | ❌ | ❌ |
| Binary size | ~15MB | ~200MB+ | ~100MB | ~80MB |

## Dependencies

- `docker` (recommended) OR direct binary download
- `curl` (for installation)
- Optional: `docker-compose` for production deployments
- Optional: Nginx/Caddy for reverse proxy + SSL
