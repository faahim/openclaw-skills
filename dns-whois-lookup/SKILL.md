---
name: dns-whois-lookup
description: >-
  Query DNS records, check domain WHOIS data, verify propagation, and diagnose DNS issues from the command line.
categories: [dev-tools, data]
dependencies: [dig, whois, host, bash, jq]
---

# DNS & WHOIS Lookup Tool

## What This Does

Full domain intelligence from the terminal. Query any DNS record type (A, AAAA, MX, TXT, CNAME, NS, SOA, CAA), pull WHOIS registration data, check DNS propagation across multiple nameservers, and diagnose common DNS misconfigurations.

**Example:** "Check all DNS records for example.com, show WHOIS expiry, verify propagation across 8 global DNS servers."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# Most systems already have these. Check:
which dig whois host jq || echo "Install missing tools"

# Ubuntu/Debian
sudo apt-get install -y dnsutils whois jq

# Mac
brew install bind whois jq

# Alpine
apk add bind-tools whois jq
```

### 2. Run Your First Lookup

```bash
bash scripts/dns-lookup.sh example.com

# Output:
# ╔══════════════════════════════════════════╗
# ║  DNS Report: example.com                 ║
# ╚══════════════════════════════════════════╝
#
# ── A Records ──
# 93.184.216.34
#
# ── AAAA Records ──
# 2606:2800:220:1:248:1893:25c8:1946
#
# ── MX Records ──
# (none)
#
# ── NS Records ──
# a.iana-servers.net.
# b.iana-servers.net.
#
# ── TXT Records ──
# "v=spf1 -all"
```

## Core Workflows

### Workflow 1: Full DNS Report

Get all record types for a domain:

```bash
bash scripts/dns-lookup.sh --all example.com
```

Returns: A, AAAA, MX, TXT, CNAME, NS, SOA, CAA records in one report.

### Workflow 2: Specific Record Type

```bash
# MX records only
bash scripts/dns-lookup.sh --type MX gmail.com

# TXT records (SPF, DKIM, DMARC)
bash scripts/dns-lookup.sh --type TXT example.com

# CAA records (Certificate Authority Authorization)
bash scripts/dns-lookup.sh --type CAA example.com
```

### Workflow 3: WHOIS Lookup

```bash
bash scripts/whois-lookup.sh example.com

# Output:
# ── WHOIS: example.com ──
# Registrar:    RESERVED-Internet Assigned Numbers Authority
# Created:      1995-08-14
# Expires:      2025-08-13
# Updated:      2024-08-14
# Status:       clientDeleteProhibited
# Nameservers:  a.iana-servers.net, b.iana-servers.net
```

### Workflow 4: DNS Propagation Check

Check if DNS changes have propagated across global nameservers:

```bash
bash scripts/propagation-check.sh example.com A

# Output:
# ── Propagation Check: example.com (A) ──
# Google (8.8.8.8):         93.184.216.34    ✅
# Cloudflare (1.1.1.1):     93.184.216.34    ✅
# Quad9 (9.9.9.9):          93.184.216.34    ✅
# OpenDNS (208.67.222.222): 93.184.216.34    ✅
# Comodo (8.26.56.26):      93.184.216.34    ✅
# Level3 (4.2.2.1):         93.184.216.34    ✅
# Verisign (64.6.64.6):     93.184.216.34    ✅
# AdGuard (94.140.14.14):   93.184.216.34    ✅
#
# Result: 8/8 consistent ✅ — Fully propagated
```

### Workflow 5: DNS Health Check

Diagnose common DNS issues:

```bash
bash scripts/dns-health.sh example.com

# Output:
# ── DNS Health: example.com ──
# [✅] A record exists
# [✅] AAAA record exists (IPv6 ready)
# [✅] NS records present (2 nameservers)
# [⚠️] No MX records — email won't work
# [✅] SPF record found in TXT
# [⚠️] No DMARC record (_dmarc.example.com)
# [⚠️] No CAA record — any CA can issue certs
# [✅] SOA serial: 2024081400
# [✅] TTL reasonable (86400s)
#
# Score: 6/9 checks passed
# Recommendations:
# - Add MX records if email is needed
# - Add DMARC record: _dmarc.example.com TXT "v=DMARC1; p=reject"
# - Add CAA record to restrict certificate issuance
```

### Workflow 6: Reverse DNS Lookup

```bash
bash scripts/dns-lookup.sh --reverse 93.184.216.34

# Output:
# ── Reverse DNS: 93.184.216.34 ──
# PTR: 93.184.216.34 → example.com
```

### Workflow 7: Compare DNS Across Nameservers

Useful when migrating DNS providers:

```bash
bash scripts/dns-lookup.sh --compare example.com --ns1 8.8.8.8 --ns2 1.1.1.1

# Shows side-by-side comparison of records from each nameserver
```

### Workflow 8: JSON Output

For programmatic use:

```bash
bash scripts/dns-lookup.sh --json example.com

# Output:
# {"domain":"example.com","a":["93.184.216.34"],"aaaa":["2606:2800:220:1:248:1893:25c8:1946"],"mx":[],"ns":["a.iana-servers.net.","b.iana-servers.net."],"txt":["v=spf1 -all"]}
```

## Configuration

### Environment Variables

```bash
# Custom DNS server for queries (default: system resolver)
export DNS_SERVER="8.8.8.8"

# Timeout for queries in seconds (default: 5)
export DNS_TIMEOUT=5

# WHOIS server override (usually auto-detected)
export WHOIS_SERVER=""
```

### Propagation Servers

Edit `scripts/propagation-servers.txt` to customize which DNS servers to check:

```
8.8.8.8       Google
1.1.1.1       Cloudflare
9.9.9.9       Quad9
208.67.222.222 OpenDNS
8.26.56.26    Comodo
4.2.2.1       Level3
64.6.64.6     Verisign
94.140.14.14  AdGuard
```

## Advanced Usage

### Batch Domain Lookup

```bash
# Check multiple domains
cat domains.txt | while read domain; do
  bash scripts/dns-lookup.sh --json "$domain"
done > results.json
```

### Monitor DNS Changes

```bash
# Run periodically to detect unauthorized DNS changes
bash scripts/dns-lookup.sh --json example.com > /tmp/dns-current.json
diff /tmp/dns-baseline.json /tmp/dns-current.json && echo "No changes" || echo "⚠️ DNS changed!"
```

### Email Deliverability Check

```bash
# Check SPF, DKIM, DMARC in one go
bash scripts/dns-health.sh --email example.com

# Checks:
# - SPF record validity
# - DMARC policy
# - Common DKIM selectors (google, default, selector1, selector2)
```

## Troubleshooting

### Issue: "dig: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install dnsutils

# CentOS/RHEL
sudo yum install bind-utils

# Alpine
apk add bind-tools
```

### Issue: "whois: command not found"

```bash
sudo apt-get install whois  # Debian/Ubuntu
brew install whois           # Mac
```

### Issue: Timeout on queries

Increase timeout or try a different DNS server:
```bash
DNS_TIMEOUT=10 DNS_SERVER=1.1.1.1 bash scripts/dns-lookup.sh example.com
```

### Issue: WHOIS rate limited

Some registrars rate-limit WHOIS queries. Wait a few minutes or use a different WHOIS server:
```bash
WHOIS_SERVER="whois.verisign-grs.com" bash scripts/whois-lookup.sh example.com
```

## Dependencies

- `dig` (from bind-utils/dnsutils) — DNS queries
- `whois` — Domain registration data
- `host` — Simple DNS lookups
- `jq` — JSON output formatting
- `bash` (4.0+) — Script runtime
