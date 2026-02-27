# Listing Copy: Service Port Manager

## Metadata
- **Type:** Skill
- **Name:** service-port-manager
- **Display Name:** Service Port Manager
- **Categories:** [security, dev-tools]
- **Price:** $8
- **Dependencies:** [bash, ss, lsof, ufw]

## Tagline

Scan, manage, and secure local service ports — find what's listening, kill rogue processes, audit security

## Description

Ever wonder what's listening on port 3000? Or why your app won't start because something's already using port 8080? Service Port Manager gives your OpenClaw agent full visibility and control over every port on your machine.

**What it does:** Scan all listening ports, check if specific ports are free, kill processes hogging ports, detect conflicts where multiple services fight over the same port, run security audits to find dangerously exposed databases, and manage UFW firewall rules — all from simple bash commands.

**Key features:**
- 🔍 Scan all listening TCP/UDP ports with PID, process name, user, and bind address
- ✅ Check if a port is available before starting a service
- 🔪 Kill processes on any port (graceful or force)
- ⚠️ Detect port conflicts automatically
- 🔒 Security audit — flags databases bound to 0.0.0.0, checks firewall status
- 🛡️ UFW firewall management — allow, deny, remove rules
- 📊 Export reports as table, JSON, or CSV
- 👁️ Real-time connection monitoring on any port

Perfect for developers, sysadmins, and anyone managing servers who needs quick port visibility without memorizing `ss`, `lsof`, and `ufw` flags.

## Quick Start Preview

```bash
# Scan all listening ports
bash scripts/portman.sh scan

# Check if port 3000 is free
bash scripts/portman.sh check 3000

# Kill whatever's on port 8080
bash scripts/portman.sh kill 8080

# Security audit
bash scripts/portman.sh audit
```

## Core Capabilities

1. Port scanning — List all TCP/UDP listening ports with full process details
2. Port checking — Instantly check if a port is free or occupied
3. Process killing — Kill processes on any port (SIGTERM or SIGKILL)
4. Conflict detection — Find multiple processes competing for the same port
5. Security auditing — Flag databases and services exposed to all interfaces
6. Firewall management — UFW allow/deny/remove with source IP filtering
7. Range scanning — Check an entire port range at once
8. Common ports — Quick status of SSH, HTTP, databases, etc.
9. Real-time monitoring — Watch connection counts on any port
10. Multi-format export — Table, JSON, or CSV output
11. No dependencies — Uses built-in Linux tools (ss, lsof, awk)
12. Automation-ready — JSON output + quiet mode for cron/scripts

## Dependencies
- `bash` (4.0+)
- `ss` (iproute2)
- `lsof`
- `ufw` (optional)

## Installation Time
**1 minute** — No installation needed, uses system tools
