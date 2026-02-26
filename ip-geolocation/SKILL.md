---
name: ip-geolocation
description: >-
  Look up IP addresses for geolocation, ISP info, VPN/proxy detection, and abuse reputation checks.
categories: [security, dev-tools]
dependencies: [curl, jq, bash]
---

# IP Geolocation & Reputation Checker

## What This Does

Look up any IP address to find its physical location, ISP, organization, and whether it's a known VPN/proxy/Tor exit node. Optionally check abuse reputation via AbuseIPDB. Useful for investigating suspicious traffic, firewall decisions, and security audits.

**Example:** "Check where 8.8.8.8 is located, who owns it, and if it has abuse reports."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
which curl jq || echo "Install curl and jq first"
```

### 2. Look Up an IP

```bash
bash scripts/lookup.sh 8.8.8.8
```

**Output:**
```
╔══════════════════════════════════════════╗
║  IP Geolocation Report: 8.8.8.8         ║
╠══════════════════════════════════════════╣
║  Location:  Mountain View, California, US
║  Coords:    37.4056, -122.0775
║  Timezone:  America/Los_Angeles
║  ISP:       Google LLC
║  Org:       Google Public DNS
║  AS:        AS15169 Google LLC
║  Mobile:    No
║  Proxy:     No
║  Hosting:   Yes
╚══════════════════════════════════════════╝
```

### 3. (Optional) Enable Abuse Reputation

```bash
# Get free API key at https://www.abuseipdb.com/account/api
export ABUSEIPDB_API_KEY="your-key-here"

bash scripts/lookup.sh --abuse 8.8.8.8
```

## Core Workflows

### Workflow 1: Single IP Lookup

```bash
bash scripts/lookup.sh 1.1.1.1
```

### Workflow 2: Bulk IP Lookup

```bash
# From a file (one IP per line)
bash scripts/lookup.sh --bulk ips.txt

# Output: TSV format for easy parsing
# IP	Country	City	ISP	Proxy	Abuse_Score
```

### Workflow 3: Abuse Reputation Check

```bash
export ABUSEIPDB_API_KEY="your-key"
bash scripts/lookup.sh --abuse 203.0.113.50
```

**Output includes:**
```
║  Abuse Score:    87/100 ⚠️  HIGH RISK
║  Reports:        142 (last 90 days)
║  Last Reported:  2026-02-25
║  Categories:     SSH Brute-Force, Web Spam
```

### Workflow 4: Check Your Own IP

```bash
bash scripts/lookup.sh --self
```

### Workflow 5: Reverse DNS + WHOIS Summary

```bash
bash scripts/lookup.sh --rdns --whois 8.8.8.8
```

**Additional output:**
```
║  Reverse DNS: dns.google
║  WHOIS Org:   Google LLC
║  WHOIS Net:   8.8.8.0/24
```

### Workflow 6: JSON Output (for scripting)

```bash
bash scripts/lookup.sh --json 8.8.8.8
```

Returns raw JSON for piping into other tools.

### Workflow 7: Monitor a Log File for Suspicious IPs

```bash
# Extract unique IPs from nginx access log and check them
bash scripts/lookup.sh --scan /var/log/nginx/access.log --threshold 50
```

Extracts IPs, checks abuse scores, reports any above threshold.

## Configuration

### Environment Variables

```bash
# AbuseIPDB (optional, for reputation checks)
export ABUSEIPDB_API_KEY="your-key"

# Rate limiting (ip-api.com free tier: 45 req/min)
export IP_LOOKUP_DELAY="1.5"  # seconds between requests for bulk

# Output format
export IP_OUTPUT_FORMAT="table"  # table, json, tsv
```

## Advanced Usage

### Pipe from Other Tools

```bash
# Check IPs from fail2ban jail
fail2ban-client status sshd | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
  bash scripts/lookup.sh --bulk -

# Check IPs from auth.log
grep "Failed password" /var/log/auth.log | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
  sort -u | bash scripts/lookup.sh --bulk -
```

### Cron: Daily Suspicious IP Report

```bash
# Add to crontab
0 8 * * * bash /path/to/scripts/lookup.sh --scan /var/log/auth.log --threshold 30 --report /tmp/ip-report.txt
```

## Troubleshooting

### Issue: "Rate limit exceeded"

**Fix:** ip-api.com free tier allows 45 requests/minute. For bulk lookups, the script auto-throttles. If you hit limits:
```bash
export IP_LOOKUP_DELAY="2"  # increase delay
```

### Issue: Private IP addresses

The script auto-detects RFC1918 addresses (10.x, 172.16-31.x, 192.168.x) and skips them.

### Issue: AbuseIPDB returns 401

**Fix:** Check your API key: `echo $ABUSEIPDB_API_KEY`
Free tier: 1000 checks/day.

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests)
- `jq` (JSON parsing)
- Optional: `host` or `dig` (reverse DNS)
- Optional: `whois` (WHOIS lookups)
