---
name: headscale-manager
description: >-
  Install and manage Headscale — self-hosted Tailscale coordination server. Control your own mesh VPN without relying on Tailscale's cloud.
categories: [security, automation]
dependencies: [bash, curl, jq, systemd]
---

# Headscale Manager

## What This Does

Headscale is an open-source, self-hosted implementation of the Tailscale control server. This skill installs, configures, and manages Headscale so you can run your own private mesh VPN — no Tailscale account needed. Manage users, register nodes, configure routes, and monitor your network from the CLI.

**Example:** "Set up a private mesh VPN for 10 devices across 3 locations, all traffic encrypted, no cloud dependency."

## Quick Start (10 minutes)

### 1. Install Headscale

```bash
bash scripts/install.sh
```

This detects your OS/architecture, downloads the latest Headscale binary, creates a systemd service, and generates a default config.

### 2. Configure

```bash
# Edit the config — at minimum set your server URL
sudo nano /etc/headscale/config.yaml
# Change server_url to your public IP or domain:
#   server_url: https://headscale.example.com:443
# Or for LAN-only:
#   server_url: http://YOUR_IP:8080
```

### 3. Start Headscale

```bash
sudo systemctl enable --now headscale
sudo systemctl status headscale
```

### 4. Create a User & Register a Node

```bash
# Create a user (namespace)
headscale users create myuser

# Generate a pre-auth key for easy node registration
headscale preauthkeys create --user myuser --reusable --expiration 24h

# On the client device, use Tailscale client to connect:
# tailscale up --login-server http://YOUR_IP:8080 --authkey <key>
```

## Core Workflows

### Workflow 1: Install & Bootstrap

**Use case:** Fresh server, want a private VPN

```bash
# Install headscale
bash scripts/install.sh

# Create first user
headscale users create admin

# Generate auth key
headscale preauthkeys create --user admin --reusable --expiration 720h

# Print connection instructions
echo "On each device, run:"
echo "  tailscale up --login-server http://$(hostname -I | awk '{print $1}'):8080 --authkey YOUR_KEY"
```

### Workflow 2: Manage Users

```bash
# List users
headscale users list

# Create user
headscale users create devteam

# Rename user
headscale users rename oldname newname

# Delete user (removes all their nodes)
headscale users destroy username
```

### Workflow 3: Manage Nodes

```bash
# List all registered nodes
headscale nodes list

# Register a node manually (if not using pre-auth keys)
headscale nodes register --user myuser --key nodekey:abc123...

# Delete a node
headscale nodes delete --identifier 1

# Rename a node
headscale nodes rename --identifier 1 newname

# Tag a node
headscale nodes tag --identifier 1 --tags tag:server
```

### Workflow 4: Routes & Exit Nodes

```bash
# List advertised routes
headscale routes list

# Enable a route (e.g., subnet routing)
headscale routes enable --route 1

# Disable a route
headscale routes disable --route 1

# To set up an exit node, on the client:
# tailscale up --login-server http://YOUR_IP:8080 --advertise-exit-node
# Then enable it:
headscale routes enable --route <exit-node-route-id>
```

### Workflow 5: Pre-Auth Keys

```bash
# List keys for a user
headscale preauthkeys list --user myuser

# Create a single-use key (expires in 1 hour)
headscale preauthkeys create --user myuser --expiration 1h

# Create a reusable key (for auto-provisioning)
headscale preauthkeys create --user myuser --reusable --expiration 720h

# Create an ephemeral key (nodes auto-delete when disconnected)
headscale preauthkeys create --user myuser --reusable --ephemeral --expiration 24h
```

### Workflow 6: API Keys (for automation)

```bash
# Create an API key
headscale apikeys create --expiration 90d

# List API keys
headscale apikeys list

# Expire (revoke) an API key
headscale apikeys expire --prefix <prefix>
```

### Workflow 7: ACLs (Access Control)

```bash
# Edit ACL policy
sudo nano /etc/headscale/acl.yaml

# Example ACL policy:
cat << 'EOF' > /etc/headscale/acl.yaml
---
acls:
  - action: accept
    src:
      - group:admin
    dst:
      - "*:*"
  - action: accept
    src:
      - group:dev
    dst:
      - tag:server:22,80,443
groups:
  admin:
    - admin
  dev:
    - devteam
EOF

# Restart to apply
sudo systemctl restart headscale
```

### Workflow 8: Status & Monitoring

```bash
# Check service status
sudo systemctl status headscale

# View logs
sudo journalctl -u headscale -f --no-pager -n 50

# List all nodes with their status
headscale nodes list -o json | jq '.[] | {name, user, online: .online, last_seen: .last_seen, ip: .ip_addresses}'

# Check which nodes are online
headscale nodes list -o json | jq '[.[] | select(.online == true)] | length' 
```

### Workflow 9: Backup & Restore

```bash
# Backup the database and config
bash scripts/backup.sh

# Restore from backup
bash scripts/restore.sh /path/to/backup.tar.gz
```

### Workflow 10: Update Headscale

```bash
# Update to latest version
bash scripts/install.sh --update

# Check current version
headscale version
```

## Configuration

### Config File (`/etc/headscale/config.yaml`)

Key settings to customize:

```yaml
# Server URL — MUST match how clients reach this server
server_url: https://headscale.example.com:443

# Listen address
listen_addr: 0.0.0.0:8080

# Database (SQLite by default, Postgres for production)
database:
  type: sqlite3
  sqlite.path: /var/lib/headscale/db.sqlite

# For PostgreSQL:
# database:
#   type: postgres
#   postgres:
#     host: localhost
#     port: 5432
#     name: headscale
#     user: headscale
#     pass: secret

# DERP (relay servers for NAT traversal)
derp:
  server:
    enabled: true
    region_id: 999
    stun_listen_addr: 0.0.0.0:3478
  urls:
    - https://controlplane.tailscale.com/derpmap/default

# DNS settings pushed to clients
dns:
  nameservers:
    global:
      - 1.1.1.1
      - 9.9.9.9
  magic_dns: true
  base_domain: ts.example.com

# IP prefixes for nodes
prefixes:
  v4: 100.64.0.0/10
  v6: fd7a:115c:a1e0::/48

# Disable automatic check for updates
disable_check_updates: true
```

### Environment Variables

```bash
# Optional: Override config file location
export HEADSCALE_CONFIG=/etc/headscale/config.yaml

# For API access from scripts
export HEADSCALE_API_KEY="your-api-key"
```

## Advanced Usage

### Run Behind Reverse Proxy (Nginx)

```nginx
server {
    listen 443 ssl http2;
    server_name headscale.example.com;

    ssl_certificate /etc/letsencrypt/live/headscale.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/headscale.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
    }
}
```

### Docker Deployment

```bash
docker run -d \
  --name headscale \
  -v /etc/headscale:/etc/headscale \
  -v /var/lib/headscale:/var/lib/headscale \
  -p 8080:8080 \
  -p 9090:9090 \
  -p 3478:3478/udp \
  headscale/headscale:latest \
  serve
```

### Connect Headscale UI (Web Dashboard)

```bash
# Install headscale-ui (optional web interface)
docker run -d \
  --name headscale-ui \
  -p 8443:443 \
  -e HEADSCALE_URL=http://headscale:8080 \
  -e HEADSCALE_API_KEY=your-api-key \
  gurucomputing/headscale-ui:latest
```

### Automated Node Provisioning

```bash
#!/bin/bash
# Auto-provision script for new servers
USER="$1"
KEY=$(headscale preauthkeys create --user "$USER" --reusable --expiration 1h -o json | jq -r '.key')
echo "curl -fsSL https://tailscale.com/install.sh | sh"
echo "tailscale up --login-server https://headscale.example.com --authkey $KEY"
```

## Troubleshooting

### Issue: "Cannot connect to server"

**Check:**
1. Headscale is running: `sudo systemctl status headscale`
2. Port is open: `ss -tlnp | grep 8080`
3. Firewall allows traffic: `sudo ufw allow 8080/tcp` or `sudo iptables -L`
4. `server_url` in config matches your actual address

### Issue: Nodes can't reach each other

**Check:**
1. Both nodes are online: `headscale nodes list`
2. They're in the same user or ACLs allow cross-user traffic
3. DERP relay is working: check logs for DERP connection errors
4. STUN port is open: `sudo ufw allow 3478/udp`

### Issue: "unauthorized" API errors

**Fix:**
```bash
# Create a new API key
headscale apikeys create --expiration 365d
# Use the output key in your API calls
```

### Issue: DNS not working after connecting

**Check:**
1. `magic_dns: true` in config
2. `base_domain` is set
3. Client is using Tailscale DNS: `tailscale status --peers`

### Issue: High memory usage

**Fix:** Switch from SQLite to PostgreSQL for large deployments (50+ nodes):
```yaml
database:
  type: postgres
  postgres:
    host: localhost
    name: headscale
    user: headscale
    pass: your-password
```

## Dependencies

- `bash` (4.0+)
- `curl` (download binary)
- `jq` (JSON parsing for node management)
- `systemd` (service management)
- `tar` (extracting release archives)
- Optional: `docker` (for containerized deployment)
- Optional: `postgresql` (for large-scale deployments)
- Clients: Tailscale client on each device (tailscale.com/download)
