# Listing Copy: WireGuard VPN Manager

## Metadata
- **Type:** Skill
- **Name:** wireguard-vpn
- **Display Name:** WireGuard VPN Manager
- **Categories:** [security, automation]
- **Price:** $15
- **Dependencies:** [wireguard-tools, bash, jq, qrencode]

## Tagline

"Install, configure, and manage WireGuard VPN tunnels — automated key management and peer setup"

## Description

Setting up WireGuard manually means generating keys with cryptic commands, hand-editing config files, configuring iptables rules, and repeating it all for every new device. One wrong character in a public key and nothing works.

WireGuard VPN Manager handles the entire lifecycle through simple commands. Initialize a server, add peers by name, generate QR codes for phones, set up site-to-site tunnels, and manage everything with a single script. Keys, configs, firewall rules, and IP allocation are all automated.

**What it does:**
- 🔧 Auto-install WireGuard on Ubuntu/Debian/Fedora/Arch/Alpine
- 🔑 Automated key generation + preshared keys for every peer
- 📱 QR code generation for mobile devices (WireGuard app)
- 🌐 Site-to-site tunnel configuration
- 👥 Named peer management with transfer stats
- 🔒 Kill-switch option for clients (block non-VPN traffic)
- 💾 Backup and restore entire VPN configurations
- 🚀 Auto-start on boot via systemd
- 🔢 Automatic IP allocation (no manual tracking)
- 🛡️ Pre-configured NAT and firewall rules

Perfect for developers, sysadmins, and self-hosters who want a private VPN without paying for commercial services — and without the pain of manual WireGuard setup.

## Quick Start Preview

```bash
# Install WireGuard
sudo bash scripts/install.sh

# Set up server
sudo bash scripts/wg-manager.sh init-server --endpoint $(curl -s ifconfig.me)

# Add a device
sudo bash scripts/wg-manager.sh add-peer --name "phone" --dns 1.1.1.1

# Show QR for mobile
sudo bash scripts/wg-manager.sh qr --name "phone"
```

## Core Capabilities

1. Server initialization — One command creates full server config with NAT rules
2. Peer management — Add/remove peers by name, auto-assign IPs
3. QR codes — Scan to connect mobile devices instantly
4. Site-to-site — Connect servers/offices securely
5. Key automation — Generate, rotate, and track keypairs automatically
6. Kill switch — Optional client-side VPN-only traffic enforcement
7. Backup/restore — Export and import entire VPN setups
8. Multi-OS install — Auto-detect and install on major Linux distros
9. Live reload — Add/remove peers without restarting the tunnel
10. Transfer stats — Monitor bandwidth per peer with named identification
