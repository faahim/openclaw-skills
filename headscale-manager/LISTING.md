# Listing Copy: Headscale Manager

## Metadata
- **Type:** Skill
- **Name:** headscale-manager
- **Display Name:** Headscale Manager
- **Categories:** [security, automation]
- **Price:** $15
- **Dependencies:** [bash, curl, jq, systemd]

## Tagline

Self-hosted Tailscale control server — Own your mesh VPN, no cloud dependency

## Description

Running Tailscale is great — until you realize all your coordination data lives on someone else's server. Headscale is the open-source, self-hosted alternative that gives you full control over your mesh VPN.

**Headscale Manager** installs, configures, and manages your Headscale server in minutes. One script to install the binary, create systemd services, and generate a production-ready config. Then manage users, nodes, routes, ACLs, and pre-auth keys — all from the CLI.

**What it does:**
- 🔧 One-command install with auto-detected OS/architecture
- 👥 User management — create, list, rename, delete namespaces
- 💻 Node management — register, tag, rename, monitor devices
- 🌐 Route & exit node control — subnet routing, traffic forwarding
- 🔑 Pre-auth key generation — single-use, reusable, or ephemeral
- 🛡️ ACL policy management — fine-grained access control
- 📊 Status monitoring — node health, connection status, logs
- 💾 Backup & restore — database + config snapshots with auto-pruning
- 🔄 Easy updates — one command to upgrade to latest version
- 🐳 Docker deployment support — containerized option included

**Perfect for:** Self-hosters, homelab enthusiasts, small teams, and anyone who wants a private mesh VPN without Tailscale's cloud. Use standard Tailscale clients on every device — just point them at your own server.

## Quick Start Preview

```bash
# Install Headscale
sudo bash scripts/install.sh

# Start the server
sudo systemctl enable --now headscale

# Create a user and auth key
headscale users create myteam
headscale preauthkeys create --user myteam --reusable --expiration 24h

# Connect from any device:
# tailscale up --login-server http://YOUR_IP:8080 --authkey KEY
```

## Core Capabilities

1. Automated installation — detects OS, downloads correct binary, creates systemd service
2. User/namespace management — organize devices into logical groups
3. Node registration — pre-auth keys, manual registration, ephemeral nodes
4. Subnet routing — route traffic between networks through VPN nodes
5. Exit node support — route all traffic through a specific node
6. ACL policies — control which nodes can talk to which
7. API key management — for automation and integrations
8. DERP relay configuration — NAT traversal for devices behind firewalls
9. Reverse proxy support — Nginx config for HTTPS termination
10. Backup/restore — automated database and config snapshots
11. Docker deployment — run containerized with persistent volumes
12. Web UI support — optional Headscale-UI dashboard integration

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`
- `systemd`
- `tar`
- Tailscale client on devices (free, all platforms)

## Installation Time
**10 minutes** — install binary, configure, connect first device
