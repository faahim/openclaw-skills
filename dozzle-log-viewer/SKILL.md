---
name: dozzle-log-viewer
description: >-
  Deploy and manage Dozzle — a lightweight, real-time Docker container log viewer with a beautiful web UI.
categories: [dev-tools, automation]
dependencies: [docker, bash, curl]
---

# Dozzle Log Viewer

## What This Does

Dozzle is a lightweight, real-time log viewer for Docker containers. It streams logs directly from the Docker socket with zero storage overhead — no database, no indexing, just live logs in a clean web UI. This skill installs, configures, and manages Dozzle on your system.

**Example:** "Deploy Dozzle, access all container logs at `http://localhost:8080`, filter by container, search logs in real-time."

## Quick Start (2 minutes)

### 1. Check Docker Is Running

```bash
docker info > /dev/null 2>&1 || echo "ERROR: Docker is not running. Install Docker first."
```

### 2. Deploy Dozzle

```bash
bash scripts/deploy.sh
```

This launches Dozzle on port **8080** with read-only Docker socket access.

### 3. Open the UI

```bash
echo "Open: http://$(hostname -I | awk '{print $1}'):8080"
# Or locally: http://localhost:8080
```

## Core Workflows

### Workflow 1: Basic Deployment

**Use case:** View all container logs in real-time

```bash
bash scripts/deploy.sh
# Dozzle is now running at http://localhost:8080
```

### Workflow 2: Deploy with Authentication

**Use case:** Protect Dozzle with username/password

```bash
bash scripts/deploy.sh --auth --user admin --password yourpassword
```

### Workflow 3: Deploy on Custom Port

**Use case:** Port 8080 is already in use

```bash
bash scripts/deploy.sh --port 9090
```

### Workflow 4: Deploy with Remote Docker Hosts

**Use case:** Monitor containers across multiple Docker hosts

```bash
# Create agents config
cat > /tmp/dozzle-agents.yml << 'EOF'
remote-hosts:
  - name: production
    url: tcp://prod-server:2375
  - name: staging
    url: tcp://staging-server:2375
EOF

bash scripts/deploy.sh --agents /tmp/dozzle-agents.yml
```

### Workflow 5: Update Dozzle

```bash
bash scripts/update.sh
```

### Workflow 6: Check Status

```bash
bash scripts/status.sh
```

### Workflow 7: View Logs of Dozzle Itself

```bash
docker logs dozzle --tail 50 -f
```

### Workflow 8: Remove Dozzle

```bash
bash scripts/remove.sh
```

## Configuration

### Environment Variables

```bash
# Port (default: 8080)
DOZZLE_PORT=8080

# Log level (debug, info, warn, error)
DOZZLE_LEVEL=info

# Filter containers by label
DOZZLE_FILTER="name=myapp"

# Base path (for reverse proxy)
DOZZLE_BASE=/logs

# No analytics
DOZZLE_NO_ANALYTICS=true

# Hostname label
DOZZLE_HOSTNAME=my-server
```

### Docker Compose

For persistent deployments, use the generated `docker-compose.yml`:

```yaml
services:
  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - DOZZLE_LEVEL=info
      - DOZZLE_NO_ANALYTICS=true
```

### Authentication Setup

```bash
# Generate password hash
HASH=$(docker run --rm amir20/dozzle:latest generate admin --password yourpassword)

# Create users file
mkdir -p /opt/dozzle/data
echo "$HASH" > /opt/dozzle/data/users.yml

# Deploy with auth volume
bash scripts/deploy.sh --auth-file /opt/dozzle/data/users.yml
```

## Advanced Usage

### Behind Nginx Reverse Proxy

```nginx
location /logs/ {
    proxy_pass http://localhost:8080/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
}
```

Deploy with base path:
```bash
DOZZLE_BASE=/logs bash scripts/deploy.sh
```

### Filter Specific Containers

```bash
# Only show containers with specific name pattern
DOZZLE_FILTER="name=myapp" bash scripts/deploy.sh

# Only show containers with specific label
DOZZLE_FILTER="label=environment=production" bash scripts/deploy.sh
```

### Monitoring Multiple Hosts with Docker Swarm

```bash
bash scripts/deploy.sh --swarm
```

## Troubleshooting

### Issue: "permission denied" on Docker socket

**Fix:**
```bash
# Add your user to the docker group
sudo usermod -aG docker $USER
# Log out and back in, then retry
```

### Issue: Dozzle can't connect to remote hosts

**Check:**
1. Remote Docker daemon exposes TCP: `dockerd -H tcp://0.0.0.0:2375`
2. Firewall allows port 2375
3. Use TLS for production: `tcp://host:2376` with certs

### Issue: Container not showing up

**Check:**
1. Container is running: `docker ps`
2. No filter is excluding it: check `DOZZLE_FILTER`
3. Dozzle has Docker socket access: `docker exec dozzle ls /var/run/docker.sock`

### Issue: WebSocket errors in browser

**Fix:** If behind a reverse proxy, ensure WebSocket upgrade headers are set (see Nginx config above).

## Key Principles

1. **Zero storage** — Dozzle streams from Docker, no disk usage
2. **Read-only** — Docker socket mounted as read-only for security
3. **Lightweight** — ~10MB image, minimal CPU/RAM
4. **Real-time** — WebSocket-based live streaming
5. **Auto-restart** — Uses `unless-stopped` restart policy

## Dependencies

- `docker` (Docker Engine 20.10+)
- `bash` (4.0+)
- `curl` (for health checks)
- Optional: `docker-compose` (for compose deployments)
