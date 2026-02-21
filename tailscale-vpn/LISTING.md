# Listing Copy: Tailscale VPN Manager

## Metadata
- **Type:** Skill
- **Name:** tailscale-vpn
- **Display Name:** Tailscale VPN Manager
- **Categories:** [security, automation]
- **Price:** $15
- **Dependencies:** [curl, tailscale]

## Tagline

"Install and manage Tailscale VPN — private mesh network with zero firewall config"

## Description

Setting up a VPN between your servers, laptops, and phones usually means wrestling with WireGuard configs, opening firewall ports, and managing SSH keys across machines. It's the kind of task that takes an afternoon and breaks when your IP changes.

Tailscale VPN Manager installs and configures Tailscale on any Linux or macOS machine in under 3 minutes. Auto-detects your OS, sets up the service, and connects you to your private mesh network. No port forwarding, no manual key exchange — just run the install script and authenticate.

**What it does:**
- 🔧 Auto-install Tailscale on any OS (Debian, Ubuntu, RHEL, Fedora, Arch, Alpine, macOS)
- 🌐 Connect machines to a private WireGuard mesh network
- 🔑 Enable Tailscale SSH (no SSH keys to manage)
- 🚪 Set up exit nodes (route traffic through any machine)
- 📡 Configure subnet routing (access entire LANs remotely)
- 🔒 Manage ACL policies via API (who can access what)
- 🏥 Full diagnostics — network health, peer status, DNS, forwarding checks
- 🚀 Fleet provisioning with auth keys

Perfect for developers, sysadmins, and homelab enthusiasts who want their machines connected without the networking headaches.

## Core Capabilities

1. One-command install — Auto-detects OS family, installs + enables service
2. Mesh VPN — All devices connected peer-to-peer via WireGuard
3. Tailscale SSH — Passwordless, keyless SSH between devices
4. Exit nodes — Route all traffic through any tailnet machine
5. Subnet routing — Access entire LANs through one Tailscale node
6. Tailscale Serve/Funnel — Expose local services to tailnet or internet
7. ACL management — View, validate, and apply access policies via API
8. Fleet provisioning — Auth keys for automated server onboarding
9. Full diagnostics — Service status, peer connectivity, network checks
10. MagicDNS — Access devices by name, not IP address
11. Docker support — Run Tailscale as a container sidecar

## Dependencies
- `curl`
- `tailscale` (installed by the skill)
- Root/sudo access
- Linux 4.1+ / macOS 10.15+

## Installation Time
**3 minutes** — Run install script, authenticate, done
