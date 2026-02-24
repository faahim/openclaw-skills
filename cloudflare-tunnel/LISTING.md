# Listing Copy: Cloudflare Tunnel Manager

## Metadata
- **Type:** Skill
- **Name:** cloudflare-tunnel
- **Display Name:** Cloudflare Tunnel Manager
- **Categories:** [dev-tools, automation]
- **Price:** $12
- **Dependencies:** [cloudflared, jq, bash]

## Tagline

Expose local services to the internet securely — no port forwarding, no public IP needed.

## Description

Running a local dev server, API, or dashboard but need it publicly accessible? Opening firewall ports and configuring NAT is tedious, insecure, and often impossible on shared networks or behind ISPs that block inbound connections.

Cloudflare Tunnel Manager installs and configures `cloudflared` to create encrypted tunnels from your machine to Cloudflare's edge network. Your local services get public HTTPS URLs instantly — no port forwarding, no dynamic DNS, no exposed IP address.

**What it does:**
- 🔧 One-command install of `cloudflared` (Linux/macOS, x86/ARM)
- 🔐 Authenticate and create named tunnels
- 🌐 Route custom domains to local services (auto-HTTPS)
- 🚀 Multi-service routing through a single tunnel (web, API, SSH, databases)
- ⚡ Quick temporary tunnels for demos (*.trycloudflare.com)
- 🔄 Install as systemd service for persistent tunnels
- 🛑 Full lifecycle management: create, route, start, stop, delete

Perfect for developers exposing dev servers, sysadmins providing remote SSH access, and anyone who needs to share local services without infrastructure headaches.

## Core Capabilities

1. Auto-install cloudflared — Detects OS/arch, installs via package manager or binary
2. One-command authentication — Browser-based Cloudflare login, cert saved locally
3. Named tunnel management — Create, list, inspect, delete tunnels
4. DNS routing — Map custom hostnames to tunnels automatically
5. Multi-service config — Route multiple hostnames through one tunnel via YAML
6. Quick tunnels — Instant *.trycloudflare.com URLs for testing/demos
7. SSH tunneling — Expose SSH servers securely without opening port 22
8. Systemd service — Persistent tunnels that survive reboots
9. Zero Trust ready — Add authentication policies to exposed services
10. Cross-platform — Linux (x86, ARM, aarch64) and macOS support

## Installation Time
**5 minutes** — install, auth, create tunnel, start
