# Listing Copy: Tinyproxy Manager

## Metadata
- **Type:** Skill
- **Name:** tinyproxy-manager
- **Display Name:** Tinyproxy Manager
- **Categories:** [security, dev-tools]
- **Price:** $8
- **Dependencies:** [bash, tinyproxy, curl]
- **Icon:** 🔀

## Tagline

Install and manage a lightweight HTTP/HTTPS forward proxy — route, filter, and log traffic

## Description

Setting up a forward proxy shouldn't require wrestling with Squid's 200+ config options or running heavy containers. Sometimes you just need a simple, lightweight proxy that works.

Tinyproxy Manager installs and configures Tinyproxy — a sub-2MB HTTP/HTTPS forward proxy — with a clean CLI for all management tasks. Start a proxy in 30 seconds, configure access controls, block domains, chain to upstream proxies, and monitor traffic.

**What it does:**
- 🔀 Forward proxy for HTTP/HTTPS traffic (CONNECT tunneling)
- 🛡️ IP-based access control lists
- 🚫 Domain blocking with filter lists
- 📊 Request logging and traffic statistics
- 🔗 Upstream proxy chaining (corporate proxies, Tor, VPNs)
- 🐳 Container-friendly (expose proxy to Docker networks)
- ⚡ 2MB RAM footprint (vs Squid's 50-200MB)
- 🔧 Full CLI management (start/stop/config/logs/health)

Perfect for developers needing a local proxy for testing, sysadmins routing container traffic, or anyone wanting domain filtering without a full DNS setup.

## Core Capabilities

1. One-command install — auto-detects OS (Debian, RHEL, Alpine, Arch, macOS)
2. Forward proxy — route HTTP/HTTPS through a local endpoint
3. Access control — restrict by IP address or subnet
4. Domain filtering — block ads, tracking, or any domain list
5. Request logging — full audit trail with search and stats
6. Upstream chaining — route through corporate or SOCKS proxies
7. Anonymous mode — strip identifying proxy headers
8. Health checks — verify proxy is running and responsive
9. Systemd integration — enable/disable auto-start on boot
10. Config management — backup, restore, and CLI-driven changes

## Dependencies
- `bash` (4.0+)
- `tinyproxy` (installed by skill)
- `curl` (for health checks)

## Installation Time
**3 minutes** — one script installs everything
