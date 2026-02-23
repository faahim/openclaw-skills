# Listing Copy: Prometheus Monitor

## Metadata
- **Type:** Skill
- **Name:** prometheus-monitor
- **Display Name:** Prometheus Monitor
- **Categories:** [automation, analytics]
- **Icon:** 📊
- **Dependencies:** [bash, curl, tar, systemd]

## Tagline

Monitor servers with Prometheus + Node Exporter — alerts via Telegram when things go wrong.

## Description

Running servers without monitoring is flying blind. By the time you notice something's wrong — disk full, memory leak, service crashed — your users already know.

**Prometheus Monitor** installs a complete Prometheus + Node Exporter stack on any Linux server with a single command. No Docker, no complex setup — just native systemd services. Track CPU, memory, disk, network, and 500+ system metrics across all your servers. Set up Telegram alerts for when things go sideways.

**What you get:**
- ✅ One-command install: Prometheus + Node Exporter + Alertmanager
- 📊 500+ system metrics out of the box (CPU, RAM, disk, network, load)
- 🔔 Telegram alerts for critical events (disk full, service down, high CPU)
- 🌐 Monitor multiple servers from one Prometheus instance
- 📈 Built-in PromQL queries for instant system health checks
- 🔐 SSL certificate and service health monitoring
- ⚙️ Pre-configured alert rules (customize thresholds easily)
- 🗑️ Clean uninstall script

**Perfect for** developers, sysadmins, and indie hackers running their own infrastructure — VPS, homelab, or cloud servers.

## Quick Start Preview

```bash
# Install everything
sudo bash scripts/install.sh

# Check status
bash scripts/status.sh
# ✅ prometheus | localhost:9090 — UP
# ✅ node | localhost:9100 (local) — UP
# CPU: 12.3%  MEM: 45.2%  DISK: 61.8%
```

## Core Capabilities

1. Automated installation — Downloads correct binaries for your architecture (amd64/arm64)
2. Systemd integration — Runs as proper services with auto-restart
3. Node Exporter — 500+ Linux metrics (CPU, memory, disk, network, processes)
4. Alert rules — Pre-built rules for common issues (disk full, high CPU, instance down)
5. Telegram notifications — Instant alerts when thresholds are breached
6. Multi-server — Monitor unlimited remote servers from one Prometheus
7. PromQL queries — Ready-to-use queries for system health
8. Target management — Easy add/remove of monitoring targets
9. Config validation — Validates YAML before reloading
10. Clean uninstall — Remove everything with one command
