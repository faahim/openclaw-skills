# Listing Copy: Subdomain Finder

## Metadata
- **Type:** Skill
- **Name:** subdomain-finder
- **Display Name:** Subdomain Finder
- **Categories:** [security, dev-tools]
- **Price:** $10
- **Dependencies:** [bash, curl, dig, jq, openssl]

## Tagline

"Discover subdomains using CT logs & DNS brute force — map your attack surface in seconds"

## Description

You can't secure what you don't know exists. Shadow subdomains — forgotten staging servers, exposed admin panels, legacy APIs — are the #1 entry point for attackers. Most teams don't even know half their subdomains.

Subdomain Finder enumerates subdomains using multiple techniques: certificate transparency logs (crt.sh), DNS brute force with a curated 500-name wordlist, and IP resolution. No external services to sign up for, no API keys needed — it runs entirely with standard Linux tools.

**What it does:**
- 🔍 Certificate transparency scan via crt.sh API
- 🔨 DNS brute force with customizable wordlists
- 🌐 IP resolution + HTTP/HTTPS status checks
- 📊 JSON or text output for reporting
- 🔔 Baseline diffing — detect NEW subdomains over time
- 📱 Telegram alerts when new subdomains appear
- ⚡ Fast parallel DNS queries

Perfect for security researchers, pentesters, sysadmins, and developers who want to monitor their organization's attack surface without paying for expensive reconnaissance tools.

## Quick Start Preview

```bash
# Find all subdomains of a domain
bash scripts/find-subdomains.sh example.com --full --resolve --check-http

# Output:
# [CT] Found 23 subdomains via certificate transparency
# [BRUTE] Found 12 via DNS brute force
# [MERGE] 31 unique subdomains
#
# SUBDOMAIN                  IP              HTTP  HTTPS
# api.example.com            93.184.216.34   200   200
# admin.example.com          93.184.216.35   301   200
# staging.example.com        93.184.216.36   403   403
```

## Core Capabilities

1. CT log enumeration — Query crt.sh for all certificates issued to a domain
2. DNS brute force — Test 500+ common subdomain names against DNS
3. IP resolution — Resolve each subdomain to its IP address
4. HTTP probing — Check which subdomains respond on port 80/443
5. Baseline diffing — Compare scans over time, detect new subdomains
6. Telegram alerting — Get notified when new subdomains appear
7. JSON export — Machine-readable output for integration with other tools
8. Custom wordlists — Bring your own subdomain name lists
9. Parallel queries — Fast scanning with configurable concurrency
10. Zero dependencies — Uses standard Linux tools (curl, dig, jq)

## Dependencies
- `bash` (4.0+)
- `curl`
- `dig` (from `dnsutils`)
- `jq`
- `openssl` (optional)

## Installation Time
**2 minutes** — No installation needed, just run the script
