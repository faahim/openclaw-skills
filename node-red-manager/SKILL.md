---
name: node-red-manager
description: >-
  Install, configure, and manage Node-RED — the visual flow-based automation platform for IoT, APIs, and home automation.
categories: [home, automation]
dependencies: [bash, node, npm, systemctl]
---

# Node-RED Manager

## What This Does

Install and manage [Node-RED](https://nodered.org), the browser-based visual programming tool for wiring together APIs, IoT devices, and online services. This skill handles installation, service management, security hardening, flow backup/restore, and node (palette) management — all from the command line.

**Example:** "Install Node-RED, set up password auth, run as a systemd service, install the Telegram node, and back up my flows nightly."

## Quick Start (5 minutes)

### 1. Install Node-RED

```bash
bash scripts/install.sh
```

This installs Node-RED globally via npm (or uses the official install script on Raspberry Pi/Debian). It also creates a systemd service so Node-RED starts on boot.

### 2. Start Node-RED

```bash
bash scripts/manage.sh start
# Node-RED is now running at http://localhost:1880
```

### 3. Secure with Password

```bash
bash scripts/secure.sh --user admin --pass 'YourSecurePassword'
# Restarts Node-RED with authentication enabled
```

### 4. Open the Editor

Navigate to `http://<your-ip>:1880` in a browser.

## Core Workflows

### Workflow 1: Full Install + Secure Setup

**Use case:** Fresh server, want Node-RED running securely.

```bash
# Install
bash scripts/install.sh

# Set up auth
bash scripts/secure.sh --user admin --pass 'MyStr0ngP@ss!'

# Start as service
bash scripts/manage.sh enable
bash scripts/manage.sh start

# Verify
bash scripts/manage.sh status
```

**Output:**
```
✅ Node-RED is running
   URL: http://localhost:1880
   Auth: enabled (admin)
   Uptime: 12 seconds
   Node.js: v22.x
   Node-RED: v4.x
```

### Workflow 2: Install Palette Nodes

**Use case:** Add nodes for Telegram, Home Assistant, dashboards, etc.

```bash
# Install a single node
bash scripts/palette.sh install node-red-contrib-telegrambot

# Install multiple
bash scripts/palette.sh install node-red-contrib-home-assistant-websocket node-red-dashboard node-red-contrib-cron-plus

# List installed nodes
bash scripts/palette.sh list

# Remove a node
bash scripts/palette.sh remove node-red-contrib-telegrambot
```

### Workflow 3: Backup & Restore Flows

**Use case:** Back up flows before updating, or migrate to another server.

```bash
# Backup current flows + credentials + settings
bash scripts/backup.sh --output ~/node-red-backups/

# Output:
# ✅ Backup saved: ~/node-red-backups/node-red-backup-2026-03-05T15-53-00.tar.gz
#    Includes: flows.json, flows_cred.json, settings.js, package.json

# Restore from backup
bash scripts/backup.sh --restore ~/node-red-backups/node-red-backup-2026-03-05T15-53-00.tar.gz

# Auto-backup via cron (daily at 2am)
bash scripts/backup.sh --schedule "0 2 * * *" --output ~/node-red-backups/ --keep 7
```

### Workflow 4: Update Node-RED

**Use case:** Upgrade to latest version safely.

```bash
# Check current vs available version
bash scripts/manage.sh version

# Output:
# Current: 4.0.5
# Latest:  4.1.0
# Update available!

# Backup first, then update
bash scripts/backup.sh --output ~/node-red-backups/
bash scripts/manage.sh update

# Verify
bash scripts/manage.sh status
```

### Workflow 5: Configure Reverse Proxy (HTTPS)

**Use case:** Expose Node-RED securely behind Nginx/Caddy.

```bash
# Generate Nginx config for Node-RED
bash scripts/proxy.sh --domain nodered.example.com --port 1880

# Output: Nginx config written to /etc/nginx/sites-available/nodered
# Then: Get SSL cert with certbot
```

## Configuration

### Environment Variables

```bash
# Custom port (default: 1880)
export NODE_RED_PORT=1880

# Custom user directory (default: ~/.node-red)
export NODE_RED_DIR="$HOME/.node-red"

# Bind address (default: 0.0.0.0)
export NODE_RED_BIND="127.0.0.1"
```

### Settings File

The main config lives at `~/.node-red/settings.js`. Key settings:

```javascript
module.exports = {
    uiPort: 1880,
    httpAdminRoot: '/admin',
    httpNodeRoot: '/api',
    userDir: '/home/user/.node-red',
    adminAuth: {
        type: "credentials",
        users: [{
            username: "admin",
            password: "$2b$08$...",  // bcrypt hash
            permissions: "*"
        }]
    },
    logging: {
        console: { level: "info", audit: false }
    }
};
```

## Advanced Usage

### Run in Docker

```bash
# If you prefer Docker over native install
bash scripts/install.sh --docker

# Uses: nodered/node-red:latest
# Mounts: ~/.node-red as /data
# Port: 1880
```

### Projects Mode (Git Integration)

```bash
# Enable projects (version-control your flows with git)
bash scripts/manage.sh enable-projects

# Node-RED will restart with Projects feature enabled
# Access via editor: Menu → Projects → New Project
```

### Health Check

```bash
# Quick health check (useful for monitoring)
bash scripts/manage.sh health

# Output:
# ✅ Node-RED: running (PID 12345)
# ✅ Port 1880: listening
# ✅ Memory: 85MB RSS
# ✅ Flows: 3 tabs, 47 nodes
# ✅ Last deploy: 2 hours ago
```

## Troubleshooting

### Issue: "Cannot find module 'node-red'"

**Fix:**
```bash
# Reinstall globally
npm install -g --unsafe-perm node-red

# Or use the official script (Debian/Ubuntu/Pi)
bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered)
```

### Issue: Port 1880 already in use

**Fix:**
```bash
# Find what's using the port
sudo lsof -i :1880

# Change port
export NODE_RED_PORT=1881
bash scripts/manage.sh restart
```

### Issue: Flows not loading after update

**Fix:**
```bash
# Restore from backup
bash scripts/backup.sh --restore ~/node-red-backups/latest.tar.gz

# Or manually fix
cd ~/.node-red
npm install  # reinstall dependencies
bash scripts/manage.sh restart
```

### Issue: "EACCES: permission denied"

**Fix:**
```bash
# Fix npm permissions
sudo chown -R $(whoami) ~/.node-red
sudo chown -R $(whoami) $(npm config get prefix)/lib/node_modules
```

## Key Principles

1. **Service-first** — Always run as systemd service (auto-restart on crash/reboot)
2. **Secure by default** — Auth setup is part of quick start
3. **Backup before change** — Auto-backup before updates
4. **Non-destructive** — Restore always available
5. **Minimal footprint** — ~80MB RAM for typical flows

## Dependencies

- `bash` (4.0+)
- `node` (18+ recommended, 22+ ideal)
- `npm` (comes with node)
- `systemctl` (for service management, optional for Docker mode)
- `curl` (for installation)
- Optional: `docker` (for container mode)
- Optional: `nginx` or `caddy` (for reverse proxy)
