---
name: goaccess-analytics
description: >-
  Install and run GoAccess to parse web server logs into real-time HTML dashboards and terminal reports.
categories: [analytics, dev-tools]
dependencies: [goaccess, bash, curl]
---

# GoAccess Web Log Analyzer

## What This Does

Installs GoAccess — the fastest open-source web log analyzer — and configures it to parse Apache, Nginx, or custom access logs into beautiful real-time HTML dashboards or terminal reports. See visitor stats, top pages, referrers, 404s, geo data, and bandwidth usage without shipping logs to any third-party service.

**Example:** "Parse last week's Nginx access log, generate an HTML dashboard showing top pages, visitor countries, and 404 errors."

## Quick Start (5 minutes)

### 1. Install GoAccess

```bash
bash scripts/install.sh
```

This auto-detects your OS (Debian/Ubuntu, RHEL/CentOS, Alpine, macOS) and installs GoAccess with GeoIP support.

### 2. Generate HTML Dashboard

```bash
bash scripts/analyze.sh --log /var/log/nginx/access.log --format COMBINED --html /tmp/report.html
```

### 3. Terminal Report (No Browser Needed)

```bash
bash scripts/analyze.sh --log /var/log/nginx/access.log --format COMBINED --terminal
```

### 4. Real-Time Dashboard (WebSocket)

```bash
bash scripts/analyze.sh --log /var/log/nginx/access.log --format COMBINED --realtime --port 7890
# Open http://your-server:7890 in a browser
```

## Core Workflows

### Workflow 1: One-Shot HTML Report

**Use case:** Generate a static HTML dashboard from access logs.

```bash
bash scripts/analyze.sh \
  --log /var/log/nginx/access.log \
  --format COMBINED \
  --html /var/www/html/stats.html
```

**Output:** Self-contained HTML file with interactive charts:
- Unique visitors per day
- Requested files (top pages)
- Static requests (CSS/JS/images)
- 404 Not Found URLs
- Visitor hostnames/IPs
- Operating systems & browsers
- Referring sites & URLs
- HTTP status codes
- Geographic location (if GeoIP configured)
- Bandwidth consumption

### Workflow 2: Filter by Date Range

**Use case:** Analyze logs from a specific period.

```bash
# Last 7 days only
bash scripts/analyze.sh \
  --log /var/log/nginx/access.log \
  --format COMBINED \
  --html /tmp/weekly.html \
  --date-range "$(date -d '7 days ago' +%d/%b/%Y)-$(date +%d/%b/%Y)"
```

### Workflow 3: Multiple Log Files

**Use case:** Analyze rotated/compressed logs together.

```bash
# Combine current + rotated logs
zcat /var/log/nginx/access.log.*.gz | cat - /var/log/nginx/access.log | \
  bash scripts/analyze.sh --stdin --format COMBINED --html /tmp/full-report.html
```

### Workflow 4: Apache Logs

```bash
bash scripts/analyze.sh \
  --log /var/log/apache2/access.log \
  --format COMBINED \
  --html /tmp/apache-stats.html
```

### Workflow 5: Custom Log Format

**Use case:** Parse non-standard logs (CloudFront, custom apps, etc.)

```bash
bash scripts/analyze.sh \
  --log /var/log/myapp/access.log \
  --log-format '%h %^[%d:%t %^] "%r" %s %b "%R" "%u"' \
  --date-format '%d/%b/%Y' \
  --time-format '%H:%M:%S' \
  --html /tmp/custom-report.html
```

### Workflow 6: Real-Time Monitoring

**Use case:** Live dashboard that updates as new requests come in.

```bash
bash scripts/analyze.sh \
  --log /var/log/nginx/access.log \
  --format COMBINED \
  --realtime \
  --port 7890 \
  --ws-url wss://your-domain.com:7890
```

### Workflow 7: JSON/CSV Export

**Use case:** Pipe analytics data to other tools.

```bash
# JSON output
bash scripts/analyze.sh \
  --log /var/log/nginx/access.log \
  --format COMBINED \
  --json /tmp/stats.json

# CSV output
bash scripts/analyze.sh \
  --log /var/log/nginx/access.log \
  --format COMBINED \
  --csv /tmp/stats.csv
```

### Workflow 8: Scheduled Daily Reports

**Use case:** Auto-generate daily HTML reports via cron.

```bash
bash scripts/setup-cron.sh \
  --log /var/log/nginx/access.log \
  --format COMBINED \
  --output-dir /var/www/html/analytics \
  --schedule daily
```

This creates a cron job that generates date-stamped reports: `analytics-2026-02-25.html`

## Configuration

### Predefined Log Formats

| Format | Description | Works With |
|--------|-------------|------------|
| `COMBINED` | Apache/Nginx Combined Log Format | Most web servers |
| `COMMON` | Apache Common Log Format | Apache default |
| `VCOMBINED` | Combined + virtual host | Multi-domain servers |
| `CLOUDFRONT` | AWS CloudFront logs | CloudFront CDN |
| `SQUID` | Squid proxy logs | Squid proxy |
| `W3C` | IIS W3C Extended Log Format | IIS servers |
| `CADDY` | Caddy JSON log format | Caddy server |

### GeoIP Configuration

```bash
# Install GeoIP database (free MaxMind GeoLite2)
bash scripts/install-geoip.sh

# Then use with analyze:
bash scripts/analyze.sh \
  --log /var/log/nginx/access.log \
  --format COMBINED \
  --geoip \
  --html /tmp/geo-report.html
```

### Exclude Patterns

```bash
# Exclude bots and crawlers
bash scripts/analyze.sh \
  --log /var/log/nginx/access.log \
  --format COMBINED \
  --exclude-ip "10.0.0.0-10.255.255.255" \
  --ignore-crawlers \
  --html /tmp/clean-report.html
```

## Troubleshooting

### Issue: "Unable to open log file" / Permission denied

**Fix:**
```bash
# Run with sudo or add user to adm group
sudo usermod -aG adm $(whoami)
# Or copy the log
sudo cp /var/log/nginx/access.log /tmp/access.log && chmod 644 /tmp/access.log
```

### Issue: "Unknown log format"

**Fix:** Specify the format explicitly:
```bash
# Check what format your server uses
head -1 /var/log/nginx/access.log
# Then pick matching format or define custom --log-format
```

### Issue: GoAccess shows 0 visitors

**Check:**
1. Log file has data: `wc -l /var/log/nginx/access.log`
2. Format matches: try `--format COMBINED` vs `--format COMMON`
3. Date format matches: check if logs use non-standard dates

### Issue: No GeoIP data

**Fix:** Install GeoIP database:
```bash
bash scripts/install-geoip.sh
```

## Dependencies

- `goaccess` (installed by scripts/install.sh)
- `bash` (4.0+)
- `curl` (for GeoIP database download)
- Optional: `zcat` (for compressed log analysis)
- Optional: MaxMind GeoLite2 database (free, for geographic data)

## Key Principles

1. **Privacy-first** — All processing happens locally, no data leaves your server
2. **Fast** — GoAccess is written in C, processes millions of log lines in seconds
3. **Flexible** — Supports any log format with custom patterns
4. **No dependencies** — HTML reports are self-contained, no JavaScript frameworks
