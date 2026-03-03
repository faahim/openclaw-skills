---
name: cockpit-manager
description: >-
  Install and manage Cockpit — a web-based Linux server administration console
  with real-time system monitoring, terminal access, and service management.
categories: [automation, dev-tools]
dependencies: [bash, systemctl]
---

# Cockpit Web Console Manager

## What This Does

Cockpit is a lightweight, web-based server administration tool built into most Linux distros. It provides a real-time dashboard for monitoring CPU, memory, disk, network, managing services, viewing logs, and accessing a terminal — all from your browser. This skill installs, configures, and manages Cockpit on your server.

**Example:** "Install Cockpit on my Ubuntu server, enable HTTPS on port 9090, and add the machines dashboard for multi-server management."

## Quick Start (5 minutes)

### 1. Install Cockpit

```bash
bash scripts/install.sh
```

This auto-detects your distro (Ubuntu/Debian, RHEL/CentOS/Fedora, Arch, SUSE) and installs Cockpit with recommended packages.

### 2. Access the Dashboard

```bash
bash scripts/status.sh
```

Output:
```
✅ Cockpit is running
🌐 Dashboard: https://your-server:9090
🔒 SSL: Self-signed certificate (auto-generated)
📊 Uptime: 2 days, 4 hours
```

Open `https://<your-server-ip>:9090` in your browser. Log in with your Linux user credentials.

### 3. Install Additional Modules

```bash
# Add all recommended modules
bash scripts/modules.sh install all

# Or install specific modules
bash scripts/modules.sh install machines    # Virtual machine management
bash scripts/modules.sh install podman      # Container management
bash scripts/modules.sh install pcp         # Performance Co-Pilot metrics
bash scripts/modules.sh install storaged    # Storage management
bash scripts/modules.sh install networkmanager  # Network configuration
```

## Core Workflows

### Workflow 1: Fresh Server Setup

**Use case:** Set up Cockpit on a new server with all modules

```bash
# Install Cockpit + all modules
bash scripts/install.sh --full

# Configure custom port (default: 9090)
bash scripts/configure.sh --port 443

# Restrict access to specific IPs
bash scripts/configure.sh --allow-from "192.168.1.0/24,10.0.0.0/8"

# Enable auto-start
bash scripts/configure.sh --enable-autostart
```

### Workflow 2: Multi-Server Dashboard

**Use case:** Manage multiple servers from one Cockpit instance

```bash
# On the main server, add remote hosts
bash scripts/machines.sh add worker-1 192.168.1.101 --user admin
bash scripts/machines.sh add worker-2 192.168.1.102 --user admin
bash scripts/machines.sh add db-server 192.168.1.200 --user dbadmin

# List connected machines
bash scripts/machines.sh list

# Output:
# ┌────────────┬────────────────┬────────┬──────────┐
# │ Name       │ Address        │ Status │ User     │
# ├────────────┼────────────────┼────────┼──────────┤
# │ main       │ localhost      │ ✅ Up  │ root     │
# │ worker-1   │ 192.168.1.101  │ ✅ Up  │ admin    │
# │ worker-2   │ 192.168.1.102  │ ✅ Up  │ admin    │
# │ db-server  │ 192.168.1.200  │ ⚠️ Down │ dbadmin  │
# └────────────┴────────────────┴────────┴──────────┘
```

### Workflow 3: Custom SSL Certificate

**Use case:** Use a real SSL certificate instead of self-signed

```bash
# Install Let's Encrypt cert for Cockpit
bash scripts/configure.sh --ssl-cert /etc/letsencrypt/live/server.example.com/fullchain.pem \
                          --ssl-key /etc/letsencrypt/live/server.example.com/privkey.pem

# Or generate a self-signed cert with custom domain
bash scripts/configure.sh --generate-ssl server.example.com
```

### Workflow 4: Module Management

**Use case:** List, install, remove Cockpit modules

```bash
# List available modules
bash scripts/modules.sh list

# Output:
# ┌──────────────────┬───────────┬──────────────────────────────────┐
# │ Module           │ Status    │ Description                      │
# ├──────────────────┼───────────┼──────────────────────────────────┤
# │ cockpit-system   │ ✅ Installed │ System overview & services     │
# │ cockpit-ws       │ ✅ Installed │ Web server                     │
# │ cockpit-machines │ ❌ Not installed │ Virtual machine management │
# │ cockpit-podman   │ ❌ Not installed │ Podman containers          │
# │ cockpit-pcp      │ ❌ Not installed │ Performance metrics        │
# │ cockpit-storaged │ ✅ Installed │ Storage management             │
# │ cockpit-networkmanager │ ✅ Installed │ Network configuration   │
# └──────────────────┴───────────┴──────────────────────────────────┘

# Install a module
bash scripts/modules.sh install machines

# Remove a module
bash scripts/modules.sh remove pcp
```

## Configuration

### Main Config File

Cockpit's config lives at `/etc/cockpit/cockpit.conf`:

```ini
[WebService]
# Custom port (default 9090)
Port = 9090

# Restrict origins
Origins = https://server.example.com

# SSL certificate paths
Certificate = /etc/cockpit/ws-certs.d/server.cert
Key = /etc/cockpit/ws-certs.d/server.key

# Session timeout (minutes)
IdleTimeout = 15

# Max start instances
MaxStartInstances = 10

[Session]
# Ban time after failed logins (seconds)
Banner = /etc/cockpit/issue.cockpit

[Log]
# Log level: *=info, *=debug
Fatal = *
```

### Configure via Script

```bash
# Set port
bash scripts/configure.sh --port 9090

# Set idle timeout (minutes)
bash scripts/configure.sh --idle-timeout 30

# Restrict to local network
bash scripts/configure.sh --allow-from "192.168.0.0/16"

# Set custom banner
bash scripts/configure.sh --banner "Authorized access only"

# View current config
bash scripts/configure.sh --show
```

## Advanced Usage

### Run Behind Reverse Proxy (Nginx)

```bash
# Generate Nginx config for Cockpit
bash scripts/configure.sh --proxy-config nginx > /etc/nginx/sites-available/cockpit

# Output Nginx config:
# server {
#     listen 443 ssl;
#     server_name cockpit.example.com;
#     
#     location / {
#         proxy_pass https://127.0.0.1:9090;
#         proxy_set_header Host $host;
#         proxy_set_header X-Forwarded-Proto $scheme;
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade $http_upgrade;
#         proxy_set_header Connection "upgrade";
#     }
# }
```

### Backup & Restore Configuration

```bash
# Backup all Cockpit configs
bash scripts/configure.sh --backup /tmp/cockpit-backup.tar.gz

# Restore configs
bash scripts/configure.sh --restore /tmp/cockpit-backup.tar.gz
```

### Health Check

```bash
bash scripts/status.sh --full

# Output:
# Cockpit Web Console Status
# ══════════════════════════
# Service:    ✅ Active (running)
# Port:       9090
# SSL:        ✅ Valid (expires 2027-03-03)
# Uptime:     5 days, 12 hours
# CPU Usage:  < 1%
# Memory:     42 MB
# Active Sessions: 1
# 
# Installed Modules:
#   ✅ cockpit-system
#   ✅ cockpit-ws
#   ✅ cockpit-storaged
#   ✅ cockpit-networkmanager
#   ✅ cockpit-machines
# 
# Recent Logins:
#   2026-03-03 02:15 — admin (192.168.1.10)
#   2026-03-02 18:30 — admin (192.168.1.10)
```

## Troubleshooting

### Issue: Cannot access port 9090

**Fix:**
```bash
# Check if firewall is blocking
sudo ufw status | grep 9090
# If not listed:
sudo ufw allow 9090/tcp

# Or for firewalld:
sudo firewall-cmd --add-service=cockpit --permanent
sudo firewall-cmd --reload
```

### Issue: "Permission denied" on login

**Fix:** Ensure your user is in the `cockpit-ws` group or has sudo access:
```bash
sudo usermod -aG sudo yourusername
# Then restart cockpit
sudo systemctl restart cockpit
```

### Issue: WebSocket connection errors behind proxy

**Fix:** Ensure your reverse proxy supports WebSocket upgrades:
```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

### Issue: Self-signed certificate warning

**Fix:** Either install a real cert or add an exception in your browser:
```bash
bash scripts/configure.sh --ssl-cert /path/to/cert.pem --ssl-key /path/to/key.pem
```

## Dependencies

- `bash` (4.0+)
- `systemctl` (systemd-based Linux)
- `apt-get` / `dnf` / `yum` / `pacman` (package manager)
- Optional: `ufw` or `firewalld` (firewall management)
- Optional: `openssl` (certificate generation)
