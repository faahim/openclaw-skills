# Listing Copy: Glances System Dashboard

## Metadata
- **Type:** Skill
- **Name:** glances-dashboard
- **Display Name:** Glances System Dashboard
- **Categories:** [automation, analytics]
- **Price:** $10
- **Dependencies:** [python3, pip]
- **Icon:** 📊

## Tagline

Monitor CPU, RAM, disk, Docker & more — real-time web dashboard in 5 minutes

## Description

Manually SSH-ing into servers to check `top` and `df` is the stone age of system monitoring. You need a dashboard that shows everything at a glance — CPU, memory, disk, network, Docker containers, processes — with alerts when things go wrong.

**Glances System Dashboard** installs and configures [Glances](https://github.com/nicolargo/glances) (56k+ GitHub stars) as your always-on monitoring solution. One script installs it, another starts the web dashboard, and a third sets it up as a systemd service that survives reboots.

**What you get:**
- 📊 Real-time web dashboard accessible from any browser
- 🐳 Docker container monitoring (CPU, memory, network per container)
- ⚠️ Configurable alerts (CPU > 90%, disk > 85%, etc.)
- 📡 REST API for programmatic access to all system metrics
- 📤 Export to Prometheus, InfluxDB, or CSV
- 🖥️ Client-server mode for multi-server monitoring
- 🔧 Systemd service for always-on monitoring
- 📸 Quick JSON snapshots for one-time checks

**No external services, no monthly fees.** Runs entirely on your machine.

## Core Capabilities

1. Web dashboard — Browser-based real-time system monitoring on any port
2. Docker monitoring — Per-container CPU, memory, network, and block I/O stats
3. Alert thresholds — Configurable warnings for CPU, memory, disk, swap, and load
4. REST API — Full JSON API for every metric (integrate with anything)
5. Prometheus export — Expose /metrics endpoint for Grafana dashboards
6. Systemd service — Auto-start on boot, runs in background
7. Client-server mode — Monitor multiple servers from one machine
8. System snapshots — One-time JSON dump of all system stats
9. Process monitoring — Top processes by CPU or memory, sortable
10. Network monitoring — Per-interface bandwidth, hide Docker virtual interfaces

## Installation Time
**5 minutes** — One install script, one run command
