# Listing Copy: IP Geolocation & Reputation Checker

## Metadata
- **Type:** Skill
- **Name:** ip-geolocation
- **Display Name:** IP Geolocation & Reputation Checker
- **Categories:** [security, dev-tools]
- **Price:** $8
- **Dependencies:** [curl, jq, bash]
- **Icon:** 🌐

## Tagline

Look up any IP — get location, ISP, VPN detection, and abuse reputation instantly

## Description

Suspicious traffic hitting your server? Need to know where an IP is coming from? Manually checking IP lookup sites is tedious, especially when you've got a log full of them.

**IP Geolocation & Reputation Checker** looks up any IP address for geolocation (country, city, coordinates), ISP/organization info, VPN/proxy/Tor detection, and optionally checks abuse reputation via AbuseIPDB. Supports single lookups, bulk file processing, log scanning, and JSON output for scripting.

**What it does:**
- 🌍 Geolocation — Country, city, coordinates, timezone
- 🏢 ISP & org identification — Who owns the IP
- 🕵️ VPN/proxy/Tor detection — Flag suspicious sources
- 🛡️ Abuse reputation scoring — AbuseIPDB integration (optional, free tier)
- 📋 Bulk lookups — Process entire IP lists or log files
- 🔍 Log scanning — Extract IPs from auth/access logs, flag high-risk ones
- 📊 Multiple output formats — Table, JSON, TSV

Perfect for sysadmins investigating suspicious traffic, developers building security tools, and anyone who needs quick IP intelligence.

## Quick Start Preview

```bash
bash scripts/lookup.sh 8.8.8.8

# ╔══════════════════════════════════════════╗
# ║  Location:  Mountain View, California, US
# ║  ISP:       Google LLC
# ║  Proxy:     No
# ║  Hosting:   Yes
# ╚══════════════════════════════════════════╝
```

## Core Capabilities

1. Single IP lookup — Full geolocation report with ISP, org, ASN
2. Bulk processing — Feed a file of IPs, get results in table/TSV/JSON
3. Log scanning — Extract IPs from nginx/auth logs, flag abuse scores above threshold
4. VPN/proxy detection — Identify IPs behind VPNs, proxies, or Tor
5. Abuse reputation — AbuseIPDB integration with confidence scoring
6. Reverse DNS — Optional PTR record lookup
7. WHOIS summary — Optional ownership details
8. Self-check — Look up your own public IP
9. JSON output — Pipe results into other tools
10. Private IP filtering — Auto-skips RFC1918 addresses

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`
- Optional: `host`/`dig` (reverse DNS), `whois`

## Installation Time
**2 minutes** — No installation needed, just run the script
