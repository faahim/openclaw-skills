# Listing Copy: Gatus Health Dashboard

## Metadata
- **Type:** Skill
- **Name:** gatus-health-dashboard
- **Display Name:** Gatus Health Dashboard
- **Categories:** [automation, dev-tools]
- **Price:** $15
- **Dependencies:** [bash, curl, docker, jq]
- **Icon:** 🏥

## Tagline
Monitor endpoints, APIs & services — Beautiful status page with multi-channel alerts

## Description

Your services go down at 3am. You find out at 9am from angry users. Manual monitoring doesn't scale, and enterprise tools cost $50-200/month for basic checks.

Gatus Health Dashboard sets up a complete health monitoring system in 5 minutes. Monitor HTTP endpoints, APIs, DNS, TCP ports, and SSL certificates — all from a self-hosted dashboard with zero ongoing costs. Get instant alerts via Telegram, Slack, Discord, PagerDuty, or email when anything fails.

**What you get:**
- 🌐 Beautiful self-hosted status page for your services
- ⏱️ Monitor HTTP, DNS, TCP, ICMP, and SSL certificates
- 🔔 Multi-channel alerts (Telegram, Slack, Discord, PagerDuty, email)
- 📊 Response time tracking and uptime history
- 🔐 SSL certificate expiry monitoring
- 🐳 One-command Docker setup or native binary install
- 🗃️ Persistent storage (SQLite or PostgreSQL)
- 🔧 Full management scripts (add endpoints, validate config, backup)

Perfect for developers, sysadmins, and indie hackers who need reliable service monitoring without monthly fees or vendor lock-in.

## Quick Start Preview

```bash
# Start monitoring in 60 seconds
bash scripts/setup.sh --init
docker run -d --name gatus -p 8080:8080 \
  -v ~/.config/gatus/config.yaml:/config/config.yaml \
  twinproduction/gatus:latest

# Open http://localhost:8080 — your status page is live!
```

## Core Capabilities

1. HTTP endpoint monitoring — Check status codes, response bodies, response times
2. API health checks — Validate JSON responses match expected values
3. SSL certificate monitoring — Alert before certificates expire
4. DNS resolution checks — Verify DNS records resolve correctly
5. TCP/ICMP connectivity — Monitor database ports, ping servers
6. Multi-channel alerting — Telegram, Slack, Discord, PagerDuty, email, webhooks
7. Beautiful status page — Public-facing dashboard with uptime history
8. Configurable thresholds — Set failure/success thresholds before alerting
9. Maintenance windows — Suppress alerts during scheduled maintenance
10. Persistent history — SQLite or PostgreSQL storage for trend analysis
11. Docker & native install — One-command setup either way
12. Config management — Add/list/validate endpoints via CLI scripts
