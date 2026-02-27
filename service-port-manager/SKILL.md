---
name: service-port-manager
description: >-
  Scan, list, and manage local service ports. Find what's listening, kill rogue processes, detect conflicts, and configure firewall rules.
categories: [security, dev-tools]
dependencies: [bash, ss, lsof, ufw]
---

# Service Port Manager

## What This Does

Manage which services are listening on which ports on your machine. Scan for open ports, find port conflicts, kill processes hogging ports, and configure firewall rules — all from simple commands.

**Example:** "Show me everything listening on port 3000, kill it, then block that port in the firewall."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# These are pre-installed on most Linux systems
which ss lsof && echo "Ready!" || echo "Install: sudo apt-get install iproute2 lsof"
```

### 2. Scan All Listening Ports

```bash
bash scripts/portman.sh scan
```

**Output:**
```
PORT   PROTO  PID    PROCESS          USER      STATE
22     tcp    1234   sshd             root      LISTEN
80     tcp    5678   nginx            www-data  LISTEN
3000   tcp    9012   node             clawd     LISTEN
5432   tcp    3456   postgres         postgres  LISTEN
```

### 3. Check a Specific Port

```bash
bash scripts/portman.sh check 3000
```

**Output:**
```
✅ Port 3000 is in use
  PID: 9012
  Process: node /app/server.js
  User: clawd
  Started: 2026-02-27 08:00:12
  Connections: 3 active
```

## Core Workflows

### Workflow 1: Scan All Listening Ports

```bash
bash scripts/portman.sh scan
```

Options:
```bash
# TCP only
bash scripts/portman.sh scan --tcp

# UDP only
bash scripts/portman.sh scan --udp

# Include non-listening (established connections)
bash scripts/portman.sh scan --all

# Filter by user
bash scripts/portman.sh scan --user postgres

# JSON output
bash scripts/portman.sh scan --json
```

### Workflow 2: Check if Port is Available

```bash
bash scripts/portman.sh check 8080
```

**If available:**
```
✅ Port 8080 is free — safe to use
```

**If in use:**
```
❌ Port 8080 is in use
  PID: 1234
  Process: node
  User: clawd
```

### Workflow 3: Find and Kill Process on Port

```bash
# Find what's on port 3000
bash scripts/portman.sh check 3000

# Kill it
bash scripts/portman.sh kill 3000

# Force kill
bash scripts/portman.sh kill 3000 --force
```

**Output:**
```
🔪 Killing PID 9012 (node) on port 3000...
✅ Port 3000 is now free
```

### Workflow 4: Detect Port Conflicts

```bash
bash scripts/portman.sh conflicts
```

**Output:**
```
⚠️  Port conflicts detected:

Port 8080:
  PID 1234 — nginx (user: www-data)
  PID 5678 — node (user: clawd)

Port 3000:
  PID 9012 — node (user: clawd)
  PID 9013 — node (user: clawd)
```

### Workflow 5: Firewall Management (UFW)

```bash
# Show current firewall rules
bash scripts/portman.sh firewall status

# Allow a port
bash scripts/portman.sh firewall allow 8080

# Allow port for specific IP
bash scripts/portman.sh firewall allow 22 --from 192.168.1.0/24

# Block a port
bash scripts/portman.sh firewall deny 3306

# Remove a rule
bash scripts/portman.sh firewall remove 8080
```

### Workflow 6: Watch Port Activity

```bash
# Monitor connections on port 80 in real-time
bash scripts/portman.sh watch 80

# Output refreshes every 2 seconds:
# [08:53:01] Port 80 — 12 connections (8 ESTABLISHED, 3 TIME_WAIT, 1 SYN_RECV)
# [08:53:03] Port 80 — 14 connections (10 ESTABLISHED, 3 TIME_WAIT, 1 SYN_RECV)
```

### Workflow 7: Port Range Scan

```bash
# Check a range of ports
bash scripts/portman.sh range 8000-9000
```

**Output:**
```
Scanning ports 8000-9000...
  8080  ✅ nginx (PID 1234)
  8443  ✅ node (PID 5678)
  8888  ✅ jupyter (PID 9012)
  3 ports in use, 998 free
```

### Workflow 8: Export Port Report

```bash
# Generate a full port report
bash scripts/portman.sh report

# Save as JSON
bash scripts/portman.sh report --json > port-report.json

# Save as CSV
bash scripts/portman.sh report --csv > port-report.csv
```

## Advanced Usage

### Common Port Check

```bash
# Check all common service ports at once
bash scripts/portman.sh common
```

**Output:**
```
Common Service Ports:
  22  (SSH)        ✅ sshd
  80  (HTTP)       ❌ free
  443 (HTTPS)      ❌ free
  3000 (Dev)       ✅ node
  3306 (MySQL)     ❌ free
  5432 (Postgres)  ✅ postgres
  6379 (Redis)     ✅ redis-server
  8080 (Alt HTTP)  ❌ free
  27017 (MongoDB)  ❌ free
```

### Security Audit

```bash
# Check for potentially dangerous open ports
bash scripts/portman.sh audit
```

**Output:**
```
🔒 Security Audit:
  ⚠️  Port 22 (SSH) is open to all interfaces (0.0.0.0)
  ⚠️  Port 3306 (MySQL) is open to all interfaces — should be 127.0.0.1
  ✅ Port 5432 (Postgres) is bound to 127.0.0.1 only
  ✅ Port 6379 (Redis) is bound to 127.0.0.1 only

Recommendations:
  1. Bind MySQL to 127.0.0.1 in /etc/mysql/mysql.conf.d/mysqld.cnf
  2. Consider using UFW to restrict SSH access
```

### Integration with OpenClaw Cron

```bash
# Add to OpenClaw cron — check for unexpected ports every hour
# In your cron config:
# payload: "Run: bash /path/to/scripts/portman.sh audit --quiet"
# If output contains warnings, alert via Telegram
```

## Troubleshooting

### Issue: "Permission denied" on scan

**Fix:** Some scans need root to see all processes:
```bash
sudo bash scripts/portman.sh scan
```

### Issue: "lsof: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install lsof

# RHEL/CentOS
sudo yum install lsof
```

### Issue: UFW not available

**Fix:**
```bash
# Install UFW
sudo apt-get install ufw

# Enable UFW (careful — this activates the firewall!)
sudo ufw enable
```

### Issue: Can't kill process on port

**Try force kill:**
```bash
bash scripts/portman.sh kill 3000 --force
```

Or manually:
```bash
sudo kill -9 $(lsof -t -i:3000)
```

## Dependencies

- `bash` (4.0+)
- `ss` (iproute2 — pre-installed on most Linux)
- `lsof` (pre-installed on most Linux/Mac)
- `ufw` (optional — for firewall management)
- `awk`, `grep`, `sort` (standard Unix tools)
