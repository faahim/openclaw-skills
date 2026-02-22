# Listing Copy: API Monitor

## Metadata
- **Type:** Skill
- **Name:** api-monitor
- **Display Name:** API Monitor
- **Categories:** [automation, dev-tools]
- **Price:** $12
- **Dependencies:** [bash, curl, jq]

## Tagline
Monitor API endpoints — Get instant alerts on downtime, slow responses, and broken payloads.

## Description

Your APIs go down at 3am and you find out from angry users at 9am. Manual health checks don't scale past two endpoints, and enterprise monitoring tools cost $50+/month for what should be a simple bash script.

API Monitor pings your endpoints on schedule, validates HTTP status codes and JSON response bodies, tracks latency percentiles, and fires alerts to Telegram or Slack the moment something breaks. Retries before alerting (no false positives), cools down on persistent failures (no spam), and sends recovery notifications when services come back.

**What it does:**
- ✅ Monitor unlimited REST API endpoints
- ⏱️ Track response times with P95/P99 latency stats
- 🔍 Validate JSON responses against expected schemas or paths
- 🔔 Instant alerts via Telegram, Slack, or custom webhooks
- 🔄 Smart retries (2x by default) to avoid false positives
- 🔐 SSL certificate expiry monitoring
- 📊 Latency history and trend analysis
- 🛡️ Alert cooldown + escalation (no spam)
- ✅ Recovery notifications when services come back
- ⚡ Cron-friendly: runs once, checks all, exits

Perfect for developers, DevOps engineers, and indie hackers who need reliable API monitoring without Pingdom pricing.
