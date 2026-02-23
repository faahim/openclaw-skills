# Listing Copy: HAProxy Load Balancer Manager

## Metadata
- **Type:** Skill
- **Name:** haproxy-manager
- **Display Name:** HAProxy Load Balancer Manager
- **Categories:** [dev-tools, automation]
- **Price:** $15
- **Dependencies:** [haproxy, bash, curl, openssl, jq]

## Tagline

"Install and manage HAProxy load balancing — SSL termination, health checks, and live stats in minutes"

## Description

Running multiple app servers but sending all traffic to one? Manually editing HAProxy configs is error-prone and slow. One typo and your site goes down.

HAProxy Load Balancer Manager handles the entire lifecycle: install HAProxy on any Linux distro, add backends with a single command, configure SSL termination, set up health checks, and monitor everything through a real-time stats dashboard. Config is generated from a clean JSON state file — no manual editing.

**What it does:**
- 🔧 One-command install on Ubuntu/Debian/RHEL/Alpine/Arch
- ⚖️ HTTP & TCP load balancing (round-robin, least-connections)
- 🔐 SSL termination with cert management
- ❤️ Automatic health checks (HTTP path or TCP)
- 📊 Real-time stats dashboard with per-server metrics
- 🔄 Zero-downtime server add/drain
- 🛡️ Rate limiting per IP
- 🍪 Sticky sessions for stateful apps
- 💾 Config backups and validation
- ✅ Generate → validate → reload workflow

Perfect for developers and sysadmins running multiple services who need reliable load balancing without the complexity of Kubernetes or cloud-specific solutions.

## Quick Start Preview

```bash
# Install
bash scripts/install.sh

# Add backend
bash scripts/manage.sh add-backend --name myapp --servers "app1:8080,app2:8080" --port 80 --health-check "/healthz"

# Apply & start
bash scripts/manage.sh apply
sudo systemctl reload haproxy
```

## Core Capabilities

1. Auto-install — Detects OS and installs HAProxy 2.x with dependencies
2. Backend management — Add/remove/drain servers with one command
3. HTTP load balancing — Round-robin, least-connections, source-based
4. TCP load balancing — Databases, Redis, any TCP service
5. SSL termination — Combine cert+key, terminate at HAProxy
6. Health checks — HTTP path checks or TCP connectivity, configurable intervals
7. Stats dashboard — Real-time metrics, admin controls, auto-refresh
8. Rate limiting — Per-IP request limits to prevent abuse
9. Sticky sessions — Cookie-based session persistence
10. Config validation — Syntax check before reload, auto-backup
11. Zero-downtime ops — Drain servers gracefully, reload without dropping connections
12. State-driven — JSON state file generates config deterministically

## Installation Time
**5 minutes** — Run install script, add backend, apply

## Pricing Justification

**Why $15:**
- HAProxy is enterprise-grade (used by GitHub, Stack Overflow, Reddit)
- Comparable managed load balancers: $18-50/month (AWS ALB, DigitalOcean LB)
- One-time payment, unlimited backends and servers
- Complexity: High (install + config gen + SSL + health checks + stats)
