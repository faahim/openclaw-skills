---
name: subdomain-finder
description: >-
  Discover subdomains of any domain using multiple enumeration techniques — DNS brute force, certificate transparency logs, and web scraping.
categories: [security, dev-tools]
dependencies: [bash, curl, openssl, jq, dig]
---

# Subdomain Finder

## What This Does

Discovers subdomains of any domain using multiple techniques: certificate transparency logs (crt.sh), DNS brute force with common wordlists, and reverse DNS lookups. Essential for security audits, penetration testing prep, and monitoring your attack surface.

**Example:** "Find all subdomains of example.com — outputs 47 unique subdomains with IP addresses and HTTP status codes."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# All standard Linux tools — nothing extra to install
for cmd in curl dig openssl jq; do
  which $cmd >/dev/null 2>&1 && echo "✅ $cmd" || echo "❌ $cmd — install it"
done
```

### 2. Find Subdomains

```bash
bash scripts/find-subdomains.sh example.com
```

### 3. Full Scan with All Techniques

```bash
bash scripts/find-subdomains.sh example.com --full --resolve --check-http
```

## Core Workflows

### Workflow 1: Quick Certificate Transparency Scan

**Use case:** Fast discovery using public CT logs (crt.sh)

```bash
bash scripts/find-subdomains.sh example.com --method ct
```

**Output:**
```
[CT] Querying crt.sh for example.com...
[CT] Found 23 unique subdomains

mail.example.com
api.example.com
staging.example.com
admin.example.com
dev.example.com
...
```

### Workflow 2: DNS Brute Force

**Use case:** Find subdomains not in CT logs using common names

```bash
bash scripts/find-subdomains.sh example.com --method brute --wordlist scripts/wordlist-top500.txt
```

**Output:**
```
[BRUTE] Testing 500 subdomain names against example.com...
[BRUTE] Found 12 resolving subdomains

www.example.com → 93.184.216.34
mail.example.com → 93.184.216.35
ftp.example.com → 93.184.216.36
...
```

### Workflow 3: Full Scan with HTTP Check

**Use case:** Complete enumeration + verify which subdomains are live

```bash
bash scripts/find-subdomains.sh example.com --full --resolve --check-http --output results.json
```

**Output:**
```
[CT] Querying crt.sh... found 23
[BRUTE] Testing 500 names... found 12
[MERGE] 31 unique subdomains (4 duplicates removed)
[RESOLVE] Resolving IPs...
[HTTP] Checking HTTP status...

RESULTS: 31 subdomains found for example.com

SUBDOMAIN                  IP              HTTP  HTTPS
─────────────────────────────────────────────────────
api.example.com            93.184.216.34   200   200
admin.example.com          93.184.216.35   301   200
staging.example.com        93.184.216.36   403   403
mail.example.com           93.184.216.37   -     -
dev.example.com            93.184.216.38   200   200

Saved to results.json
```

### Workflow 4: Monitor for New Subdomains

**Use case:** Track changes to your attack surface over time

```bash
# First run — saves baseline
bash scripts/find-subdomains.sh example.com --full --output data/baseline.txt

# Later runs — compare and alert on new subdomains
bash scripts/find-subdomains.sh example.com --full --diff data/baseline.txt
```

**Output:**
```
[DIFF] Comparing against baseline (31 known subdomains)...
[NEW] 2 new subdomains detected:
  + test-api.example.com (93.184.216.40)
  + beta.example.com (93.184.216.41)
```

## Configuration

### Environment Variables

```bash
# Optional: Custom DNS resolver (default: 8.8.8.8)
export DNS_RESOLVER="1.1.1.1"

# Optional: HTTP timeout in seconds (default: 5)
export HTTP_TIMEOUT=10

# Optional: Max concurrent DNS queries (default: 20)
export MAX_CONCURRENT=50

# Optional: Telegram alerts for new subdomains
export TELEGRAM_BOT_TOKEN="<your-token>"
export TELEGRAM_CHAT_ID="<your-chat-id>"
```

### Custom Wordlists

```bash
# Use a custom wordlist for brute force
bash scripts/find-subdomains.sh example.com --method brute --wordlist /path/to/wordlist.txt

# Built-in wordlists:
# scripts/wordlist-top500.txt  — 500 most common subdomain names
```

## Advanced Usage

### Run as Cron Job (Attack Surface Monitoring)

```bash
# Check daily for new subdomains
0 6 * * * cd /path/to/skill && bash scripts/find-subdomains.sh yourdomain.com --full --diff data/baseline.txt --alert telegram >> logs/scan.log 2>&1
```

### Multiple Domains

```bash
# Scan multiple domains
for domain in example.com example.org example.net; do
  bash scripts/find-subdomains.sh "$domain" --full --output "data/${domain}.json"
done
```

### JSON Output

```bash
bash scripts/find-subdomains.sh example.com --full --resolve --format json
```

```json
{
  "domain": "example.com",
  "scanned_at": "2026-03-04T01:53:00Z",
  "total": 31,
  "subdomains": [
    {
      "name": "api.example.com",
      "ip": "93.184.216.34",
      "http_status": 200,
      "https_status": 200,
      "source": "ct"
    }
  ]
}
```

## Troubleshooting

### Issue: "dig: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install dnsutils

# Mac
brew install bind
```

### Issue: crt.sh returns empty results

crt.sh may rate-limit. Wait 60 seconds and retry, or use `--method brute` only.

### Issue: Too many false positives in brute force

Use a smaller, curated wordlist:
```bash
bash scripts/find-subdomains.sh example.com --method brute --wordlist scripts/wordlist-top100.txt
```

## Dependencies

- `bash` (4.0+)
- `curl` (HTTP requests + crt.sh API)
- `dig` (DNS resolution, from `dnsutils`/`bind-utils`)
- `jq` (JSON parsing)
- `openssl` (optional — for TLS certificate inspection)
- Optional: `xargs` with `-P` for parallel DNS queries
