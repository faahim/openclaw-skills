# Listing Copy: Netdata System Monitor

## Metadata
- **Type:** Skill
- **Name:** netdata-monitor
- **Display Name:** Netdata System Monitor
- **Categories:** [automation, analytics]
- **Icon:** 📊
- **Dependencies:** [bash, curl]

## Tagline

Monitor servers in real-time — Install Netdata with dashboards, alerts, and 800+ auto-detected metrics

## Description

Manually checking server health is reactive — by the time you notice a problem, damage is done. You need always-on monitoring with instant alerts, but enterprise tools like Datadog cost hundreds per month.

**Netdata System Monitor** installs and configures Netdata — a powerful open-source monitoring platform — directly from your OpenClaw agent. One command installs it, another configures Telegram/Slack/email alerts. Auto-detects CPU, memory, disk, network, Docker containers, databases, and 800+ services with zero configuration.

**What it does:**
- 📦 One-command install on Ubuntu, Debian, CentOS, Fedora, macOS
- 📊 Real-time web dashboard at port 19999 (1-second granularity)
- 🔔 Alerts via Telegram, Slack, Discord, email, or webhooks
- 🩺 Custom health checks (CPU > 90%? Disk full? Alert!)
- 🐳 Docker, Nginx, MySQL, PostgreSQL, Redis monitoring
- 📈 Prometheus export for Grafana integration
- 🔧 CLI metric queries without leaving the terminal
- ⚡ Performance tuning (history, update frequency)
- 🗑️ Clean uninstall when no longer needed

Perfect for developers, sysadmins, and indie hackers running servers who want enterprise-grade monitoring without the enterprise price tag.

## Core Capabilities

1. Automated installation — Official Netdata installer, works across Linux distros + macOS
2. Multi-channel alerts — Telegram, Slack, Discord, email, webhooks in one command
3. Custom health checks — Define thresholds for any metric (CPU, RAM, disk, custom)
4. Service collector management — Enable monitoring for Docker, Nginx, MySQL, PostgreSQL, Redis
5. CLI metric querying — Get CPU/RAM/disk data without opening a browser
6. Prometheus export — Feed metrics to Grafana dashboards
7. Performance tuning — Control history length and collection frequency
8. Alert testing — Verify notifications work before relying on them
9. Clean uninstall — Remove everything when done
10. Auto-detection — 800+ services discovered without configuration
