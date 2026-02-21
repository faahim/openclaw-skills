---
name: cloudflare-dns
description: >-
  Manage Cloudflare DNS records, zones, and cache from the command line. List, create, update, delete DNS records and purge cache.
categories: [dev-tools, automation]
dependencies: [curl, jq]
---

# Cloudflare DNS Manager

## What This Does

Manage your Cloudflare DNS records without touching the dashboard. List zones, add/update/delete DNS records (A, AAAA, CNAME, MX, TXT, etc.), check propagation, and purge cache — all from your terminal.

**Example:** "Add an A record pointing api.example.com to 1.2.3.4, proxied through Cloudflare."

## Quick Start (2 minutes)

### 1. Set Credentials

```bash
# Get your API token from https://dash.cloudflare.com/profile/api-tokens
# Required permissions: Zone:DNS:Edit, Zone:Zone:Read
export CF_API_TOKEN="your-cloudflare-api-token"

# Or use Global API Key (legacy)
# export CF_API_KEY="your-global-api-key"
# export CF_EMAIL="your@email.com"
```

### 2. List Your Zones

```bash
bash scripts/cf-dns.sh zones
```

Output:
```
ZONE ID                              NAME              STATUS
a1b2c3d4e5f6...                      example.com       active
f6e5d4c3b2a1...                      mysite.org        active
```

### 3. List DNS Records

```bash
bash scripts/cf-dns.sh list example.com
```

Output:
```
TYPE   NAME                    CONTENT          TTL    PROXIED
A      example.com             93.184.216.34    auto   ✅
CNAME  www.example.com         example.com      auto   ✅
MX     example.com             mail.example.com 3600   ❌
TXT    example.com             v=spf1 ...       auto   ❌
```

## Core Workflows

### Workflow 1: Add a DNS Record

```bash
# Add A record
bash scripts/cf-dns.sh add example.com A api 1.2.3.4

# Add A record with proxy enabled
bash scripts/cf-dns.sh add example.com A api 1.2.3.4 --proxied

# Add CNAME
bash scripts/cf-dns.sh add example.com CNAME www example.com --proxied

# Add MX record with priority
bash scripts/cf-dns.sh add example.com MX @ mail.example.com --priority 10

# Add TXT record (SPF, DKIM, etc.)
bash scripts/cf-dns.sh add example.com TXT @ "v=spf1 include:_spf.google.com ~all"
```

### Workflow 2: Update a DNS Record

```bash
# Update A record content
bash scripts/cf-dns.sh update example.com A api 5.6.7.8

# Toggle proxy on/off
bash scripts/cf-dns.sh update example.com A api 5.6.7.8 --proxied
bash scripts/cf-dns.sh update example.com A api 5.6.7.8 --no-proxy

# Update TTL
bash scripts/cf-dns.sh update example.com A api 5.6.7.8 --ttl 3600
```

### Workflow 3: Delete a DNS Record

```bash
# Delete by name and type
bash scripts/cf-dns.sh delete example.com A api

# Delete with confirmation prompt
bash scripts/cf-dns.sh delete example.com CNAME www
```

### Workflow 4: Purge Cache

```bash
# Purge everything
bash scripts/cf-dns.sh purge example.com --all

# Purge specific URLs
bash scripts/cf-dns.sh purge example.com --urls "https://example.com/style.css,https://example.com/app.js"

# Purge by tag
bash scripts/cf-dns.sh purge example.com --tags "header-v2,footer-v2"
```

### Workflow 5: Export/Import Records

```bash
# Export all records to JSON
bash scripts/cf-dns.sh export example.com > dns-backup.json

# Import records from JSON
bash scripts/cf-dns.sh import example.com dns-backup.json

# Export as BIND zone file
bash scripts/cf-dns.sh export example.com --format bind > example.com.zone
```

### Workflow 6: Check DNS Propagation

```bash
# Check if a record has propagated
bash scripts/cf-dns.sh check example.com A api

# Output:
# Checking api.example.com (A record)...
# Google DNS (8.8.8.8):     1.2.3.4 ✅
# Cloudflare (1.1.1.1):     1.2.3.4 ✅
# OpenDNS (208.67.222.222): 1.2.3.4 ✅
# Quad9 (9.9.9.9):          1.2.3.4 ✅
```

## Configuration

### Environment Variables

```bash
# API Token (recommended)
export CF_API_TOKEN="your-token"

# OR Global API Key (legacy)
export CF_API_KEY="your-global-api-key"
export CF_EMAIL="your@email.com"

# Optional: Default zone
export CF_DEFAULT_ZONE="example.com"

# Optional: Default TTL (1 = auto)
export CF_DEFAULT_TTL="1"
```

### Supported Record Types

- `A` — IPv4 address
- `AAAA` — IPv6 address
- `CNAME` — Canonical name (alias)
- `MX` — Mail exchange (use --priority)
- `TXT` — Text record (SPF, DKIM, DMARC, etc.)
- `NS` — Nameserver
- `SRV` — Service record
- `CAA` — Certificate Authority Authorization

## Advanced Usage

### Batch Operations

```bash
# Add multiple records from a file
# records.txt format: TYPE NAME CONTENT [--proxied] [--ttl N]
cat records.txt | while read line; do
  bash scripts/cf-dns.sh add example.com $line
done
```

### Integration with OpenClaw Cron

```bash
# Dynamic DNS: Update A record with current IP every 5 minutes
# Great for home servers with dynamic IP
bash scripts/cf-dns.sh dyndns example.com home
```

### Zone Analytics

```bash
# Get zone analytics (requests, bandwidth, threats)
bash scripts/cf-dns.sh analytics example.com --period 24h
```

## Troubleshooting

### Issue: "Authentication error"

**Fix:** Check your API token has the right permissions:
- Zone → DNS → Edit
- Zone → Zone → Read

```bash
# Test authentication
bash scripts/cf-dns.sh whoami
```

### Issue: "Record already exists"

Cloudflare doesn't allow duplicate records of the same type+name. Use `update` instead of `add`.

### Issue: "Proxied not available for this record type"

Only A, AAAA, and CNAME records can be proxied. MX, TXT, NS records cannot.

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests to Cloudflare API)
- `jq` (JSON parsing)
- `dig` (DNS propagation checks — optional, usually pre-installed)
