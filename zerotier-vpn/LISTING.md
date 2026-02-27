# Listing Copy: ZeroTier VPN Manager

## Metadata
- **Type:** Skill
- **Name:** zerotier-vpn
- **Display Name:** ZeroTier VPN Manager
- **Categories:** [security, automation]
- **Price:** $10
- **Dependencies:** [curl, jq, zerotier-one]
- **Icon:** 🌐

## Tagline
Manage ZeroTier peer-to-peer VPN networks — create meshes, authorize devices, monitor health

## Description

Port forwarding is a pain. Setting up traditional VPNs is worse. ZeroTier creates encrypted peer-to-peer networks between your devices with zero configuration — but managing networks, authorizing members, and monitoring health still requires manual API calls or the web dashboard.

**ZeroTier VPN Manager** gives your OpenClaw agent full control over ZeroTier networks. Install ZeroTier, create private networks, join devices, authorize members, check connectivity, and run automated health checks — all from your terminal.

**What it does:**
- 🔧 Install ZeroTier on Linux/macOS/FreeBSD with one command
- 🌐 Create private mesh networks with custom IP ranges
- 🔑 Authorize/deauthorize members via ZeroTier Central API
- 📊 Monitor network health — offline nodes, relayed connections, pending members
- 🛡️ Configure flow rules (firewall) and DNS for your network
- 🔄 Bridge mode — route traffic between ZeroTier and local subnets
- ⏰ Cron-ready health checks with alerts

**Who it's for:** Developers, homelab enthusiasts, and sysadmins who want secure device connectivity without VPN servers, port forwarding, or firewall headaches.

## Core Capabilities

1. One-command installation — Linux, macOS, FreeBSD auto-detected
2. Network creation — Private networks with custom CIDR ranges
3. Member management — Authorize, deauthorize, list with online status
4. Network overview — Member count, online status, subnet info
5. Peer diagnostics — Direct vs relayed connections, latency
6. Health checks — Detect offline nodes, pending members, relay issues
7. Flow rules — Firewall configuration via API
8. Bridge mode — Route between ZeroTier and LAN subnets
9. DNS configuration — Custom domains for network members
10. Systemd integration — Auto-start on boot

## Dependencies
- `curl`, `jq` (pre-installed on most systems)
- `zerotier-one` (installed by included script)

## Installation Time
**5 minutes** — Run install script, create or join network
