# Listing Copy: Service Health Dashboard

## Metadata
- **Type:** Skill
- **Name:** service-dashboard
- **Display Name:** Service Health Dashboard
- **Categories:** [automation, dev-tools]
- **Price:** $12
- **Dependencies:** [bash, curl, jq, nc]

## Tagline

Generate a self-hosted status page — monitor HTTP, TCP, DNS, and Docker services

## Description

Checking if your services are up shouldn't require a $20/month SaaS subscription. But manually curling endpoints and eyeballing Docker containers gets old fast.

Service Health Dashboard monitors all your infrastructure — websites, APIs, databases, Docker containers, DNS records — and generates a beautiful, self-contained HTML status page. One bash script, zero external dependencies. Run it via cron every 5 minutes and you've got your own StatusPage.io.

**What it does:**
- 🌐 HTTP checks with status code + body validation
- 🔌 TCP port checks (databases, Redis, custom services)
- 🔍 DNS resolution checks with expected value validation
- 🐳 Docker container health monitoring
- ⚡ Custom command checks (disk space, memory, etc.)
- 🔔 Telegram + Slack/webhook alerts on state changes
- 📊 24-hour uptime percentages from rolling history
- 🎨 Dark/light theme, auto-refresh, mobile-friendly

Perfect for developers, sysadmins, and indie hackers who run their own infrastructure and want monitoring without vendor lock-in.

## Core Capabilities

1. Multi-protocol monitoring — HTTP, TCP, DNS, Docker, custom commands
2. Self-contained HTML dashboard — No JavaScript frameworks, no build step
3. Auto-refresh status page — Updates in-browser without reload
4. State-aware alerts — Only fires on transitions (up→down, down→up)
5. Telegram integration — Instant notifications with recovery alerts
6. Webhook support — Slack, Discord, or any HTTP endpoint
7. Rolling history — JSONL log for uptime calculations
8. Response time tracking — Latency visible per service
9. Cron-ready — Single command, perfect for scheduled execution
10. Multi-environment — Separate configs for prod/staging/dev

## Dependencies
- bash (4.0+), curl, jq, nc (netcat)
- Optional: dig (DNS), docker CLI

## Installation Time
**5 minutes** — Create config, run script
