# Listing Copy: GoAccess Web Log Analyzer

## Metadata
- **Type:** Skill
- **Name:** goaccess-analytics
- **Display Name:** GoAccess Web Log Analyzer
- **Categories:** [analytics, dev-tools]
- **Price:** $10
- **Dependencies:** [goaccess, bash, curl]
- **Icon:** 📊

## Tagline
Analyze web server logs into real-time HTML dashboards — no third-party services needed

## Description

Checking your web traffic shouldn't require a SaaS subscription or sending your data to third parties. But parsing raw Nginx/Apache logs manually is tedious, error-prone, and tells you nothing useful at a glance.

GoAccess Web Log Analyzer installs and configures GoAccess — the fastest open-source log analyzer (written in C) — to turn your access logs into beautiful, interactive HTML dashboards in seconds. See visitors, top pages, 404s, referrers, countries, bandwidth, and browsers. All processed locally on your server.

**What it does:**
- 📊 One-command HTML dashboard from any access log
- 🔴 Real-time WebSocket dashboard that updates live
- 🌍 Geographic visitor data with GeoIP support
- 📁 Supports Nginx, Apache, CloudFront, Caddy, Squid, IIS, custom formats
- 📅 Scheduled daily/weekly reports via cron
- 📤 JSON and CSV export for piping to other tools
- 🕷️ Bot/crawler filtering
- 🔒 100% local — no data leaves your server

Perfect for developers, sysadmins, and anyone running web servers who wants quick, private analytics without the overhead of Google Analytics or Plausible.

## Quick Start Preview

```bash
# Install GoAccess
bash scripts/install.sh

# Generate HTML dashboard
bash scripts/analyze.sh --log /var/log/nginx/access.log --format COMBINED --html /tmp/report.html

# Or view in terminal
bash scripts/analyze.sh --log /var/log/nginx/access.log --format COMBINED --terminal
```

## Core Capabilities

1. HTML dashboard generation — Self-contained interactive reports with charts
2. Real-time monitoring — Live WebSocket dashboard that updates with each request
3. Multi-format support — Nginx, Apache, CloudFront, Caddy, Squid, IIS, custom
4. GeoIP lookups — See visitor countries and cities
5. Terminal mode — Full analytics in your terminal (ncurses)
6. Scheduled reports — Auto-generate daily/weekly dashboards via cron
7. JSON/CSV export — Pipe analytics data to other tools and dashboards
8. Bot filtering — Exclude crawlers and known bots from reports
9. Compressed log support — Analyze rotated .gz log files
10. Date range filtering — Analyze specific time periods
11. IP exclusion — Filter out internal traffic and IP ranges
12. Zero external dependencies — Runs entirely on your server

## Installation Time
**5 minutes** — Run install script, point at logs, get dashboard
