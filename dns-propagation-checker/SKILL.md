---
name: dns-propagation-checker
description: >-
  Check DNS record propagation across 20+ global resolvers. Verify A, AAAA, CNAME, MX, TXT, NS records propagated worldwide.
categories: [dev-tools, automation]
dependencies: [bash, dig]
---

# DNS Propagation Checker

## What This Does

After updating DNS records, propagation can take minutes to hours. This tool checks your records against 20+ global DNS resolvers simultaneously — see exactly which resolvers have the new value and which still show stale data.

**Example:** "Check if my new A record for example.com has propagated to Google DNS, Cloudflare, OpenDNS, and 17 more resolvers worldwide."

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
# dig is usually pre-installed. If not:
# Ubuntu/Debian
sudo apt-get install -y dnsutils

# RHEL/CentOS
sudo yum install -y bind-utils

# macOS — already included
```

### 2. Check a Domain

```bash
bash scripts/check.sh example.com A
```

**Output:**
```
DNS Propagation Check: example.com (A)
Expected: (auto-detect from authoritative)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 ✅  8.8.8.8         Google Public DNS         93.184.216.34        12ms
 ✅  8.8.4.4         Google Public DNS 2       93.184.216.34        14ms
 ✅  1.1.1.1         Cloudflare                93.184.216.34         8ms
 ✅  1.0.0.1         Cloudflare 2              93.184.216.34         9ms
 ✅  9.9.9.9         Quad9                     93.184.216.34        18ms
 ✅  208.67.222.222  OpenDNS                   93.184.216.34        22ms
 ❌  156.154.70.1    Neustar                   (old value)          45ms
 ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Propagation: 18/20 resolvers (90%) ██████████████████░░
```

## Core Workflows

### Workflow 1: Check A Record Propagation

```bash
bash scripts/check.sh mysite.com A
```

### Workflow 2: Check Against Expected Value

When you know the new IP/value you're waiting for:

```bash
bash scripts/check.sh mysite.com A --expect 203.0.113.50
```

Only shows ✅ when the resolver returns the expected value.

### Workflow 3: Check MX Records

```bash
bash scripts/check.sh mysite.com MX
```

### Workflow 4: Check TXT Records (SPF, DKIM, DMARC)

```bash
bash scripts/check.sh mysite.com TXT --expect "v=spf1 include:_spf.google.com ~all"
```

### Workflow 5: Check CNAME

```bash
bash scripts/check.sh www.mysite.com CNAME
```

### Workflow 6: Monitor Until Full Propagation

```bash
bash scripts/check.sh mysite.com A --expect 203.0.113.50 --wait --interval 60
```

Checks every 60 seconds until all resolvers return the expected value.

### Workflow 7: Check Specific Subdomains

```bash
bash scripts/check.sh _dmarc.mysite.com TXT
bash scripts/check.sh mail.mysite.com A
```

### Workflow 8: JSON Output for Scripting

```bash
bash scripts/check.sh mysite.com A --json
```

```json
{
  "domain": "mysite.com",
  "record_type": "A",
  "checked_at": "2026-03-05T21:53:00Z",
  "propagation_pct": 90,
  "results": [
    {"resolver": "8.8.8.8", "name": "Google", "value": "203.0.113.50", "match": true, "latency_ms": 12},
    ...
  ]
}
```

## Configuration

### Custom Resolvers

Create `resolvers.conf` to override defaults:

```bash
# resolvers.conf — one per line: IP|Name
8.8.8.8|Google Public DNS
1.1.1.1|Cloudflare
9.9.9.9|Quad9
208.67.222.222|OpenDNS
# Add your own:
10.0.0.1|Internal DNS
```

```bash
bash scripts/check.sh mysite.com A --resolvers resolvers.conf
```

### Environment Variables

```bash
# Timeout per resolver query (default: 3 seconds)
export DNS_TIMEOUT=5

# Parallel queries (default: 5)
export DNS_PARALLEL=10
```

## Advanced Usage

### Compare Authoritative vs Public

```bash
bash scripts/check.sh mysite.com A --show-auth
```

Shows the authoritative nameserver's answer alongside public resolver results.

### Export Results

```bash
# CSV
bash scripts/check.sh mysite.com A --csv > results.csv

# JSON
bash scripts/check.sh mysite.com A --json > results.json
```

### Batch Check Multiple Domains

```bash
cat domains.txt | while read domain; do
  bash scripts/check.sh "$domain" A --json
done
```

## Troubleshooting

### Issue: "dig: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install -y dnsutils

# RHEL/CentOS/Fedora
sudo yum install -y bind-utils

# Alpine
apk add bind-tools
```

### Issue: Timeouts on some resolvers

Increase timeout:
```bash
DNS_TIMEOUT=10 bash scripts/check.sh mysite.com A
```

### Issue: "SERVFAIL" from a resolver

The resolver itself has an issue reaching the authoritative server. This is normal — some resolvers may have temporary connectivity issues.

## Global Resolvers (Built-in)

| Resolver | Provider | Location |
|----------|----------|----------|
| 8.8.8.8 | Google | Global Anycast |
| 8.8.4.4 | Google | Global Anycast |
| 1.1.1.1 | Cloudflare | Global Anycast |
| 1.0.0.1 | Cloudflare | Global Anycast |
| 9.9.9.9 | Quad9 | Global Anycast |
| 149.112.112.112 | Quad9 Secondary | Global Anycast |
| 208.67.222.222 | OpenDNS | US |
| 208.67.220.220 | OpenDNS Secondary | US |
| 156.154.70.1 | Neustar/UltraDNS | US |
| 156.154.71.1 | Neustar Secondary | US |
| 185.228.168.9 | CleanBrowsing | EU |
| 185.228.169.9 | CleanBrowsing Secondary | EU |
| 76.76.2.0 | Control D | CA |
| 76.76.10.0 | Control D Secondary | CA |
| 94.140.14.14 | AdGuard DNS | EU |
| 94.140.15.15 | AdGuard Secondary | EU |
| 77.88.8.8 | Yandex DNS | RU |
| 77.88.8.1 | Yandex Secondary | RU |
| 180.76.76.76 | Baidu DNS | CN |
| 223.5.5.5 | Alibaba DNS | CN |

## Dependencies

- `bash` (4.0+)
- `dig` (from bind-utils / dnsutils)
- Optional: `jq` (for JSON formatting)
