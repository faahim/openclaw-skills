# Listing Copy: Status Page

## Metadata
- **Type:** Skill
- **Name:** status-page
- **Display Name:** Status Page
- **Categories:** [automation, dev-tools]
- **Price:** $12
- **Dependencies:** [docker, curl]

## Tagline

Deploy a self-hosted status page — Monitor endpoints, show uptime, alert on downtime

## Description

Manually checking if your services are up doesn't scale. Your users find out about outages before you do, and you're scrambling to check dashboards instead of fixing things.

Status Page deploys [Gatus](https://github.com/TwiN/gatus) — a lightweight, self-hosted monitoring dashboard — in under 5 minutes. Define endpoints in YAML, launch with Docker, and get a public status page with real-time health checks, uptime history, and embeddable badges. No SaaS subscription, no monthly fees.

**What it does:**
- 🌐 Monitor HTTP, TCP, ICMP, and DNS endpoints
- ⏱️ Configurable check intervals (30s to 24h)
- 🔔 Alert via Telegram, Slack, Discord, PagerDuty, email, or webhooks
- 📊 Uptime history with SQLite persistence
- 🔐 SSL certificate expiry monitoring
- 🏷️ Embeddable uptime badges for READMEs
- 📦 One Docker container, zero external dependencies
- ✅ Validate JSON response bodies, not just status codes

Perfect for developers, indie hackers, and teams who want Statuspage.io-level monitoring without the $29+/month price tag.

## Quick Start Preview

```bash
bash scripts/setup.sh init
# Edit ~/status-page/config/config.yaml with your endpoints
bash scripts/setup.sh start
# Dashboard at http://localhost:8080
```

## Core Capabilities

1. HTTP/HTTPS monitoring — Check status codes, response times, body content
2. TCP/ICMP monitoring — Verify database and service connectivity
3. SSL certificate tracking — Alert before certs expire
4. Multi-channel alerting — Telegram, Slack, Discord, PagerDuty, email, webhooks
5. Grouped endpoints — Organize by Production, Staging, Infrastructure, External
6. Uptime badges — Embed SVG badges in GitHub READMEs or docs
7. Response body validation — Assert JSON fields match expected values
8. Persistent history — SQLite storage for uptime trends
9. Docker-based — Single container, easy to deploy anywhere
10. YAML config — Human-readable, version-controllable configuration

## Dependencies
- Docker + Docker Compose
- curl (for health checks)

## Installation Time
**5 minutes** — Init, edit config, start
