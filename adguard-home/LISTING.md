# Listing Copy: AdGuard Home Manager

## Metadata
- **Type:** Skill
- **Name:** adguard-home
- **Display Name:** AdGuard Home Manager
- **Categories:** [home, security]
- **Price:** $12
- **Dependencies:** [curl, jq, bash]
- **Icon:** 🛡️

## Tagline

Install and manage AdGuard Home — network-wide DNS ad-blocker from the CLI

## Description

Tired of ads, trackers, and malware infesting every device on your network? Setting up Pi-hole alternatives shouldn't require a PhD in networking.

**AdGuard Home Manager** installs and manages [AdGuard Home](https://adguard.com/en/adguard-home/overview.html) directly from your OpenClaw agent. One command to install (binary or Docker), then manage everything via CLI — filter lists, custom block/allow rules, upstream DNS, client configs, query logs, and stats. No web UI clicking required.

**What it does:**
- 🛡️ Install AdGuard Home (binary or Docker) with auto-architecture detection
- 📊 View query stats, top domains, blocked domains, and client activity
- 🔍 Browse query logs — see exactly what's being blocked and allowed
- 📋 Add/remove/refresh filter lists (OISD, Steven Black, Hagezi, etc.)
- 🚫 Block or whitelist specific domains with one command
- ⚙️ Configure upstream DNS (DoH, DoT, Quad9, Cloudflare, Google)
- 🏥 Health checks — service status, DNS resolution, filter freshness
- 💾 Backup configuration to JSON

Perfect for self-hosters, homelab enthusiasts, and anyone who wants network-wide ad blocking without the hassle.

## Core Capabilities

1. One-command install — Binary or Docker, auto-detects OS and architecture
2. Query statistics — Total queries, blocked %, avg response time (24h)
3. Query log viewer — See real-time DNS queries with block/allow status
4. Filter list management — Add, remove, refresh popular blocklists
5. Custom rules — Block or whitelist domains with adblock syntax
6. Upstream DNS config — Set DNS-over-HTTPS/TLS providers
7. Temporary disable — Pause protection for N seconds (debugging)
8. Client management — View configured client devices and their settings
9. Health monitoring — Check service, DNS resolution, and filter freshness
10. Config backup — Export full configuration to timestamped JSON

## Installation Time
**5 minutes** — Run install script, set credentials, start managing
