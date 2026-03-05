# Listing Copy: SearXNG Search Engine Manager

## Metadata
- **Type:** Skill
- **Name:** searxng-manager
- **Display Name:** SearXNG Search Engine Manager
- **Categories:** [security, automation]
- **Price:** $12
- **Dependencies:** [docker, bash, curl, jq]

## Tagline

Deploy a private, self-hosted search engine — aggregate 70+ engines with zero tracking

## Description

Every search you make on Google, Bing, or DuckDuckGo is tracked, profiled, and monetized. Your search history reveals your health concerns, financial situation, political views, and deepest curiosities. You deserve better.

SearXNG Manager deploys a fully self-hosted, privacy-respecting metasearch engine in under 5 minutes. It aggregates results from 70+ search engines without revealing your identity to any of them. No tracking, no ads, no data collection.

**What it does:**
- 🔒 Deploy SearXNG via Docker or bare-metal in one command
- 🔎 Aggregate results from Google, Bing, DuckDuckGo, Wikipedia, GitHub, arXiv & more
- ⚙️ Manage engines — enable, disable, test, benchmark performance
- 🔄 Auto-update on schedule (daily/weekly/monthly)
- 🌐 Generate Nginx/Caddy reverse proxy configs for public hosting
- 💾 Backup and restore your configuration
- 🖥️ CLI search — query from terminal, get JSON or text results
- 🛡️ Rate limiting, image proxy, safe search built-in

Perfect for privacy-conscious developers, sysadmins running home labs, and anyone who wants to own their search experience.

## Quick Start Preview

```bash
# Deploy with Docker
bash scripts/install.sh --method docker --port 8080

# Search from CLI
bash scripts/manage.sh search "self-hosted privacy tools"

# Manage engines
bash scripts/manage.sh engines enable google bing wikipedia arxiv
bash scripts/manage.sh engines disable yahoo
```

## Core Capabilities

1. One-command Docker deployment — running in under 5 minutes
2. Bare-metal installation — Python virtualenv + systemd service
3. 70+ search engine support — web, images, videos, news, science, IT
4. Engine management — enable/disable/test/benchmark individual engines
5. CLI search — query SearXNG from terminal with JSON or text output
6. Auto-updates — scheduled Docker image pulls (daily/weekly/monthly)
7. Reverse proxy configs — auto-generated Nginx and Caddy configs
8. Backup & restore — one-command config backup and restoration
9. Privacy by default — no tracking, no cookies, no logs
10. Rate limiting — protect public instances from abuse

## Dependencies
- `docker` (recommended) or Python 3.9+
- `bash` (4.0+)
- `curl`, `jq`
- Optional: `nginx` or `caddy` (reverse proxy)

## Installation Time
**5 minutes** with Docker

## Pricing Justification

**Why $12:**
- SearXNG is free, but setting it up correctly takes 30-60 minutes
- This skill automates the entire process: install, configure, manage, update
- Comparable hosted search: $10-50/month (Kagi, Neeva)
- One-time payment, no monthly fees, unlimited use
