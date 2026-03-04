# Listing Copy: OpenVPN Manager

## Metadata
- **Type:** Skill
- **Name:** openvpn-manager
- **Display Name:** OpenVPN Manager
- **Categories:** [security, automation]
- **Icon:** 🔒
- **Price:** $15
- **Dependencies:** [bash, curl, openssl]

## Tagline

Deploy and manage a full OpenVPN server — from install to client configs in 10 minutes

## Description

Setting up OpenVPN manually means wrestling with Easy-RSA, PKI certificates, iptables rules, and config files. One wrong step and nothing connects. You need a VPN server, not a weekend project.

OpenVPN Manager automates the entire process. One script installs OpenVPN, generates your Certificate Authority, configures the server with modern security defaults (AES-256-GCM, TLS-Crypt), and sets up firewall rules. Adding users is a single command that produces a ready-to-use `.ovpn` file.

**What it does:**
- 🔒 Full OpenVPN server installation with secure defaults
- 👤 One-command client certificate generation (`.ovpn` files)
- 🚫 Instant user revocation with CRL updates
- 📊 Server status dashboard (connected clients, bandwidth, cert expiry)
- 🔄 Certificate rotation and renewal
- 💾 Full PKI backup and restore
- 🛡️ Automatic firewall configuration (iptables/ufw)
- ⏱️ Cron-ready health monitoring

**Who it's for:** Developers, sysadmins, and teams who need a self-hosted VPN without the complexity of manual setup or the cost of commercial VPN services.

## Core Capabilities

1. One-command server installation — OpenVPN + Easy-RSA + PKI + firewall in one script
2. Client management — Add, revoke, list, and renew user certificates
3. Ready-to-use configs — Generates inline `.ovpn` files (no separate cert files needed)
4. Modern security — AES-256-GCM cipher, TLS-Crypt, SHA256 auth by default
5. Firewall automation — Configures iptables NAT, IP forwarding, and ufw rules
6. Certificate monitoring — Alert on certs expiring within N days
7. Multi-platform — Ubuntu, Debian, CentOS, Rocky, Alma, Amazon Linux, Arch
8. Backup & restore — Full PKI backup with one command
9. Server rotation — Rotate server certificates without losing clients
10. Split tunnel support — Route all traffic or just specific subnets
11. TCP/UDP support — Default UDP, switch to TCP 443 for restrictive networks
12. Cron monitoring — `--check` flag for health monitoring scripts

## Quick Start Preview

```bash
# Install server
sudo bash scripts/install.sh

# Add a user
sudo bash scripts/client.sh add john
# → /etc/openvpn/clients/john.ovpn

# Check status
sudo bash scripts/status.sh
```

## Dependencies
- `bash` (4.0+)
- `openvpn` (installed by script)
- `easy-rsa` (installed by script)
- `openssl`, `curl`, `iptables`
- Root/sudo access

## Installation Time
**10 minutes** — Run install script, create first client, connect
