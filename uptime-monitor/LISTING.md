# Listing: Uptime Monitor

## Metadata
- **Name:** uptime-monitor
- **Display Name:** Uptime Monitor
- **Categories:** automation, dev-tools
- **Icon:** 📡
- **Dependencies:** curl, jq, openssl, bash

## Tagline
Monitor URLs and APIs — Get instant alerts when services go down

## Description

Manually checking if your sites are up is tedious. By the time you notice downtime, you've already lost users and revenue. You need automated monitoring — without paying $10-50/month for a SaaS tool.

**Uptime Monitor** pings your URLs and APIs on a schedule, checks HTTP status, validates response bodies, monitors SSL certificate expiry, and alerts you instantly via Telegram, Slack webhooks, email, or custom scripts. No external services, no monthly fees — it runs entirely in your OpenClaw agent.

**What it does:**
- 📡 Monitor unlimited URLs and API endpoints
- ⏱️ Configurable check intervals (every 30 seconds to 24 hours)
- 🔔 Multi-channel alerts: Telegram, webhooks, email, custom scripts
- 🔐 SSL certificate expiry monitoring with configurable warning threshold
- 📊 Response body validation (check if API returns expected JSON)
- 🧠 Smart deduplication — alerts once per incident, notifies on recovery
- 📋 JSON config for managing multiple monitors
- 🔄 Auto-rotating log files
- ⚡ One-shot mode for cron jobs + continuous daemon mode

Perfect for developers, sysadmins, and indie hackers who need reliable uptime monitoring without the enterprise complexity.

## Core Capabilities
1. HTTP status monitoring — Check any URL, alert on non-2xx responses
2. Response body validation — Verify API responses contain expected content
3. SSL certificate tracking — Warn before certs expire
4. Telegram alerts — Instant notifications via bot
5. Webhook alerts — Push to Slack, Discord, or any webhook endpoint
6. Email alerts — SMTP-based email notifications
7. Smart deduplication — No alert spam, configurable failure threshold
8. Recovery notifications — Know when services come back up
9. Multi-target config — Monitor dozens of URLs from one JSON file
10. Daemon mode — Run in background, log to file with auto-rotation
11. One-shot mode — Perfect for cron/agent scheduled checks
12. Machine-readable output — JSON output for agent automation
