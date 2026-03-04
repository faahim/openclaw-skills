# Listing Copy: Monit Manager

## Metadata
- **Type:** Skill
- **Name:** monit-manager
- **Display Name:** Monit Manager
- **Categories:** [automation, dev-tools]
- **Price:** $10
- **Icon:** 🔄
- **Dependencies:** [monit, bash, curl]

## Tagline

Auto-restart crashed services — Lightweight process supervision with Monit

## Description

Services crash. Databases run out of memory. Web servers hang. By the time you notice, your users have already left.

**Monit Manager** installs and configures Monit, the battle-tested process supervisor that automatically monitors your services and restarts them when they fail. No agents, no cloud dashboards, no monthly fees — just a 2MB daemon that watches everything and fixes problems before you wake up.

**What it does:**
- 🔄 Auto-restart crashed processes within 30 seconds
- 🌐 HTTP health checks — verify services actually respond, not just run
- 📊 Monitor CPU, memory, disk, and swap usage
- 🔐 Detect unauthorized file changes (config tampering)
- 🔔 Alert via email, Slack webhook, or any HTTP endpoint
- 🖥️ Optional web dashboard on port 2812
- ⚡ Uses <2MB RAM — negligible overhead

**Perfect for:** Developers running production services, sysadmins managing servers, indie hackers who can't afford Datadog but need reliability.

## Quick Start Preview

```bash
# Install Monit
bash scripts/install.sh

# Monitor nginx with auto-restart
bash scripts/add-service.sh --name nginx \
  --pidfile /var/run/nginx.pid \
  --start "systemctl start nginx" \
  --stop "systemctl stop nginx" \
  --check-url "http://localhost:80"

# Check status
sudo monit summary
```

## Core Capabilities

1. Process monitoring — Watch services by PID file or process name matching
2. Auto-restart — Crashed services restart automatically within one check cycle
3. HTTP health checks — Verify services respond correctly, not just exist
4. System resources — Monitor CPU, memory, disk, swap, and load average
5. File integrity — Detect checksum, permission, or ownership changes
6. Escalation — After N failed restarts, stop retrying and alert
7. Email alerts — SMTP-based notifications on any event
8. Webhook alerts — Send to Slack, Discord, PagerDuty, or custom endpoints
9. Web UI — Browser dashboard showing all monitored services
10. Multi-distro — Works on Ubuntu, Debian, CentOS, Fedora, Alpine, Arch

## Dependencies
- `monit` (auto-installed by scripts)
- `bash` (4.0+)
- `curl` (for webhook alerts)

## Installation Time
**5 minutes** — Run install script, add your first service
