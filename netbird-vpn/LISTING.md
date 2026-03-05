# Listing Copy: NetBird VPN Manager

## Metadata
- **Type:** Skill
- **Name:** netbird-vpn
- **Display Name:** NetBird VPN Manager
- **Categories:** [security, automation]
- **Icon:** 🔐
- **Dependencies:** [curl, netbird]

## Tagline

"Set up an open-source WireGuard mesh VPN — connect all your machines securely"

## Description

Manually setting up VPN tunnels between your servers, laptops, and cloud instances is a pain. Port forwarding, firewall rules, key exchange — it's tedious and error-prone. You need a mesh VPN that just works.

NetBird VPN Manager installs and configures NetBird — an open-source, WireGuard-based mesh VPN that creates encrypted peer-to-peer connections between all your machines. No central relay bottleneck, automatic NAT traversal, and optional self-hosted management.

**What it does:**
- 🔧 One-command install on Linux, macOS (auto-detects OS and package manager)
- 🔗 Connect machines with setup keys (headless-friendly for servers)
- 📊 Monitor peer connectivity, latency, and connection type (direct vs relayed)
- 🛣️ Manage network routes to expose subnets behind peers
- 🏠 Deploy self-hosted management server with Docker + Let's Encrypt
- 🔔 Health checks with Telegram alerts for connection drops
- 🔐 Optional post-quantum security via Rosenpass

Perfect for developers, sysadmins, and homelab enthusiasts who want a zero-trust mesh network without the complexity of manual WireGuard configs or the cost of commercial VPN services.

## Quick Start Preview

```bash
# Install and connect
bash scripts/setup.sh --setup-key "YOUR-KEY"

# Check peers
bash scripts/manage.sh peers

# Monitor health
bash scripts/health.sh --alert telegram
```

## Core Capabilities

1. Automated installation — Detects OS, installs from official repos
2. Headless authentication — Connect servers with setup keys (no browser needed)
3. Peer management — List, inspect, and monitor all connected machines
4. Route management — Expose subnets behind peers via API
5. Health monitoring — Check connectivity, latency, connection type
6. Telegram alerts — Get notified when peers disconnect
7. Self-hosted option — Deploy your own management server with Docker
8. Group & ACL management — Control access between peer groups
9. DNS resolution — Resolve peer names across the mesh
10. Post-quantum security — Enable Rosenpass key exchange
11. Systemd integration — Auto-start on boot, journal logging
12. Setup key management — Create, list, and manage authentication keys
