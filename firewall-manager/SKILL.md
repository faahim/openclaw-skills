---
name: firewall-manager
description: >-
  Install, configure, and manage UFW/iptables firewall rules. Harden servers, open ports safely, audit rules, and block threats.
categories: [security, automation]
dependencies: [bash, ufw]
---

# Firewall Manager

## What This Does

Automates Linux firewall management using UFW (Uncomplicated Firewall) with iptables fallback. Install UFW, configure default policies, manage port rules, set up rate limiting, audit existing rules, and harden your server — all through executable commands.

**Example:** "Install UFW, deny all incoming, allow SSH + HTTP + HTTPS, enable rate limiting on SSH, and generate a security audit report."

## Quick Start (5 minutes)

### 1. Install & Enable UFW

```bash
bash scripts/firewall.sh install
```

This will:
- Install UFW if not present
- Set default deny incoming, allow outgoing
- Enable UFW with SSH allowed (so you don't lock yourself out)

### 2. Check Current Status

```bash
bash scripts/firewall.sh status
```

Output:
```
🔥 Firewall Status: active
Default: deny (incoming), allow (outgoing), disabled (routed)

# Rules:
[ 1] 22/tcp    ALLOW IN    Anywhere    (SSH)
```

### 3. Open a Port

```bash
bash scripts/firewall.sh allow 80    # HTTP
bash scripts/firewall.sh allow 443   # HTTPS
bash scripts/firewall.sh allow 3000  # Dev server
```

## Core Workflows

### Workflow 1: Web Server Setup

Open standard web ports with rate limiting on SSH:

```bash
bash scripts/firewall.sh web-server
```

This runs:
```
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw limit 22/tcp    # Rate-limit SSH (6 attempts/30s)
```

### Workflow 2: Block an IP

```bash
bash scripts/firewall.sh block 203.0.113.50
```

Block a subnet:
```bash
bash scripts/firewall.sh block 203.0.113.0/24
```

### Workflow 3: Allow from Specific IP Only

```bash
bash scripts/firewall.sh allow-from 10.0.0.5 22    # SSH from trusted IP only
bash scripts/firewall.sh allow-from 10.0.0.0/24 5432  # Postgres from internal network
```

### Workflow 4: Security Audit

```bash
bash scripts/firewall.sh audit
```

Output:
```
🔍 Firewall Security Audit — 2026-02-22
========================================

Status: ✅ Active
Default incoming: ✅ DENY
Default outgoing: ✅ ALLOW

Open Ports:
  22/tcp  — SSH (rate limited ✅)
  80/tcp  — HTTP
  443/tcp — HTTPS

⚠️  Warnings:
  - No IPv6 rules detected
  - Port 80 open to all (consider HTTPS-only)

Score: 8/10 — Good
```

### Workflow 5: Application Profiles

```bash
# List available app profiles
bash scripts/firewall.sh app-list

# Allow by app name
bash scripts/firewall.sh app-allow "Nginx Full"
bash scripts/firewall.sh app-allow "OpenSSH"
```

### Workflow 6: Port Range

```bash
bash scripts/firewall.sh allow 6000:6007/tcp    # TCP port range
bash scripts/firewall.sh allow 6000:6007/udp    # UDP port range
```

### Workflow 7: Delete a Rule

```bash
# List rules with numbers
bash scripts/firewall.sh status numbered

# Delete by number
bash scripts/firewall.sh delete 3
```

### Workflow 8: Export & Import Rules

```bash
# Export current rules
bash scripts/firewall.sh export > my-rules.conf

# Import rules on another server
bash scripts/firewall.sh import my-rules.conf
```

## Configuration

### Preset Profiles

The skill includes preset profiles for common setups:

```bash
# Web server (HTTP + HTTPS + SSH rate-limited)
bash scripts/firewall.sh preset web-server

# Database server (Postgres/MySQL from internal only)
bash scripts/firewall.sh preset db-server --network 10.0.0.0/24

# Docker host (Docker + SSH + monitoring)
bash scripts/firewall.sh preset docker-host

# Minimal (SSH only, everything else blocked)
bash scripts/firewall.sh preset minimal
```

### Environment Variables

```bash
# Custom SSH port (default: 22)
export FW_SSH_PORT=2222

# Trusted network for internal services
export FW_TRUSTED_NETWORK="10.0.0.0/24"

# Enable logging (default: low)
export FW_LOG_LEVEL="medium"  # off|low|medium|high|full
```

## Advanced Usage

### Rate Limiting

Protect against brute force:

```bash
# Rate limit any port (6 connections per 30 seconds)
bash scripts/firewall.sh limit 22/tcp
bash scripts/firewall.sh limit 3000/tcp
```

### Logging

```bash
# Enable logging
bash scripts/firewall.sh logging medium

# View blocked connections
bash scripts/firewall.sh logs | tail -20
```

### Scheduled Audit via OpenClaw Cron

Set up a daily firewall audit:
```
The agent should run: bash scripts/firewall.sh audit
Schedule: daily at 6am UTC
Alert if score drops below 7/10 or new unexpected ports are open.
```

### Reset Everything

```bash
# Nuclear option — reset all rules
bash scripts/firewall.sh reset
```

## Troubleshooting

### Issue: "ERROR: Could not find a profile matching 'Nginx'"

**Fix:** Install the app first, then UFW picks up its profile:
```bash
sudo apt install nginx
bash scripts/firewall.sh app-list  # Should show Nginx now
```

### Issue: Locked out of SSH

**Fix:** If you have console access:
```bash
sudo ufw allow 22/tcp
sudo ufw enable
```

Prevention: The install command always allows SSH first.

### Issue: Docker bypasses UFW

**Fix:** Docker manipulates iptables directly. Use:
```bash
bash scripts/firewall.sh docker-fix
```
This configures `/etc/docker/daemon.json` with `"iptables": false` and sets up proper UFW rules for Docker.

### Issue: UFW not available (CentOS/RHEL)

The script falls back to `firewalld`:
```bash
bash scripts/firewall.sh install  # Auto-detects and uses firewalld
```

## Dependencies

- `bash` (4.0+)
- `ufw` (Ubuntu/Debian) or `firewalld` (CentOS/RHEL) — auto-installed
- `sudo` access required for firewall changes
- Optional: `jq` for JSON audit output
