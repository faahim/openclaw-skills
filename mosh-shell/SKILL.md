---
name: mosh-shell
description: >-
  Install and configure Mosh (Mobile Shell) for persistent, roaming-friendly SSH connections that survive network changes and high latency.
categories: [dev-tools, communication]
dependencies: [mosh, ufw/iptables]
---

# Mosh — Mobile Shell Manager

## What This Does

Mosh (Mobile Shell) replaces SSH for interactive sessions. It handles intermittent connectivity, roaming between networks (WiFi → cellular → new WiFi), and high-latency links without dropping your session. Unlike SSH, mosh uses UDP and provides instant local echo — you see your keystrokes immediately even on a 500ms connection.

**Example:** "Install mosh on server + client, open firewall ports, connect from a laptop that switches between WiFi and cellular without losing your terminal session."

## Quick Start (3 minutes)

### 1. Install Mosh (Server)

```bash
# Detect OS and install
bash scripts/install.sh --server

# Output:
# ✅ Detected: Ubuntu 22.04
# ✅ Installing mosh...
# ✅ Mosh 1.4.0 installed
# ✅ Firewall: opened UDP 60000-60010
# ✅ Server ready — connect with: mosh user@this-host
```

### 2. Install Mosh (Client)

```bash
# On your local machine
bash scripts/install.sh --client

# Output:
# ✅ Mosh client installed
# ✅ Ready to connect: mosh user@server-ip
```

### 3. Connect

```bash
# Basic connection (replaces ssh)
mosh user@server-ip

# With specific SSH port
mosh --ssh="ssh -p 2222" user@server-ip

# With custom mosh port range
mosh -p 60001 user@server-ip
```

## Core Workflows

### Workflow 1: Install on Server + Open Firewall

**Use case:** Set up a remote server to accept mosh connections

```bash
bash scripts/install.sh --server --ports 60000-60010

# What it does:
# 1. Installs mosh via package manager
# 2. Opens UDP ports 60000-60010 (ufw/iptables/firewalld)
# 3. Verifies mosh-server is accessible
# 4. Prints connection command
```

**Output:**
```
[2026-03-07 02:53:00] ✅ mosh 1.4.0 installed
[2026-03-07 02:53:01] ✅ Firewall: UDP 60000:60010 ALLOW
[2026-03-07 02:53:01] ✅ mosh-server binary: /usr/bin/mosh-server
[2026-03-07 02:53:01]
Connect with:
  mosh user@203.0.113.50
  mosh --ssh="ssh -p 22 -i ~/.ssh/key" user@203.0.113.50
```

### Workflow 2: Multi-Server Setup

**Use case:** Install mosh across multiple servers at once

```bash
bash scripts/install.sh --server --hosts hosts.txt

# hosts.txt format (one per line):
# user@server1.example.com
# user@server2.example.com
# root@10.0.0.5
```

**Output:**
```
[1/3] user@server1.example.com — ✅ mosh installed, firewall opened
[2/3] user@server2.example.com — ✅ mosh installed, firewall opened
[3/3] root@10.0.0.5 — ✅ mosh installed, firewall opened
```

### Workflow 3: Connection Profiles

**Use case:** Save frequently-used mosh connections

```bash
# Save a profile
bash scripts/connect.sh --save prod --host user@prod.example.com --ssh-port 2222 --key ~/.ssh/prod_key

# Connect using profile
bash scripts/connect.sh prod

# List saved profiles
bash scripts/connect.sh --list
```

### Workflow 4: Diagnose Connection Issues

**Use case:** Troubleshoot why mosh isn't connecting

```bash
bash scripts/diagnose.sh user@server-ip

# Output:
# [1] SSH connection: ✅ OK (port 22)
# [2] mosh-server installed: ✅ /usr/bin/mosh-server (1.4.0)
# [3] UDP port 60001: ✅ OPEN
# [4] Locale (server): ✅ en_US.UTF-8
# [5] Locale (client): ✅ en_US.UTF-8
# Result: All checks passed — mosh should work
```

Or if there's an issue:
```
# [3] UDP port 60001: ❌ BLOCKED
# Fix: Run on server: sudo ufw allow 60000:60010/udp
```

## Configuration

### Firewall Ports

Mosh uses UDP ports 60000-61000 by default. Each connection uses one port.

```bash
# Open specific range (recommended: 10 ports = 10 concurrent sessions)
bash scripts/install.sh --server --ports 60000-60010

# For single-user server (1 port is enough)
bash scripts/install.sh --server --ports 60000-60000
```

### Environment Variables

```bash
# Custom mosh port range
export MOSH_SERVER_PORT=60001

# Custom locale (must match server)
export LC_ALL=en_US.UTF-8

# Prediction display mode: always, adaptive, never
export MOSH_PREDICTION_DISPLAY=adaptive

# Escape key (default: Ctrl+^)
export MOSH_ESCAPE_KEY='~'
```

### SSH Config Integration

Mosh uses your existing `~/.ssh/config`:

```
Host prod
    HostName prod.example.com
    User deploy
    Port 2222
    IdentityFile ~/.ssh/prod_key

# Then just:
# mosh prod
```

## Advanced Usage

### Tmux + Mosh (Recommended)

```bash
# Connect and auto-attach tmux
mosh user@server -- tmux new-session -A -s main

# This gives you:
# - Mosh: survives network changes
# - Tmux: survives mosh disconnects, multiple windows
```

### Port Forwarding with Mosh

Mosh doesn't support port forwarding natively. Use SSH tunnel alongside:

```bash
# Start SSH tunnel in background
ssh -f -N -L 8080:localhost:8080 user@server

# Then connect with mosh for interactive use
mosh user@server
```

### Mosh with Jump Hosts

```bash
# Through a bastion/jump host
mosh --ssh="ssh -J bastion@jump.example.com" user@internal-server
```

### Reduce Bandwidth (Slow Connections)

```bash
# Disable prediction display (less bandwidth)
MOSH_PREDICTION_DISPLAY=never mosh user@server

# Use with compression
mosh --ssh="ssh -C" user@server
```

## Troubleshooting

### Issue: "mosh-server: command not found"

**Fix:**
```bash
# The server needs mosh installed too
ssh user@server 'bash scripts/install.sh --server'

# Or manually:
ssh user@server 'sudo apt-get install -y mosh'  # Debian/Ubuntu
ssh user@server 'sudo yum install -y mosh'       # RHEL/CentOS
ssh user@server 'brew install mosh'               # macOS
```

### Issue: "Connection timed out" (firewall blocking UDP)

**Fix:**
```bash
# Check if UDP ports are open
bash scripts/diagnose.sh user@server

# Open ports manually:
# UFW
sudo ufw allow 60000:60010/udp

# iptables
sudo iptables -A INPUT -p udp --dport 60000:60010 -j ACCEPT

# firewalld
sudo firewall-cmd --add-port=60000-60010/udp --permanent
sudo firewall-cmd --reload
```

### Issue: "locale: Cannot set LC_ALL" 

**Fix:**
```bash
# On server, ensure locale is generated
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

# Or use C.UTF-8 (always available)
mosh --ssh="ssh" user@server -- env LANG=C.UTF-8 bash
```

### Issue: Mosh session stuck / zombie

**Fix:**
```bash
# List running mosh-server processes
ssh user@server 'ps aux | grep mosh-server'

# Kill specific zombie session
ssh user@server 'kill <PID>'

# Kill all mosh sessions for a user
ssh user@server 'pkill -u $(whoami) mosh-server'
```

## Mosh vs SSH Comparison

| Feature | SSH | Mosh |
|---------|-----|------|
| Protocol | TCP | UDP + SSP |
| Survives network change | ❌ | ✅ |
| Survives sleep/hibernate | ❌ | ✅ |
| Local echo (instant keystrokes) | ❌ | ✅ |
| Port forwarding | ✅ | ❌ (use SSH alongside) |
| X11 forwarding | ✅ | ❌ |
| File transfer (scp/sftp) | ✅ | ❌ (use SSH) |
| Works on high latency | Sluggish | Smooth |

## Dependencies

- `mosh` (client + server)
- `ssh` (used for initial handshake)
- `ufw` / `iptables` / `firewalld` (firewall config)
- `locale` (UTF-8 locale required)
