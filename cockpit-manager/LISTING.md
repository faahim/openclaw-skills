# Listing Copy: Cockpit Web Console Manager

## Metadata
- **Type:** Skill
- **Name:** cockpit-manager
- **Display Name:** Cockpit Web Console Manager
- **Categories:** [automation, dev-tools]
- **Price:** $10
- **Dependencies:** [bash, systemctl]

## Tagline

Manage your Linux server from a web browser — install, configure, and extend Cockpit

## Description

Manually SSH-ing into servers to check CPU, restart services, or manage storage is slow and error-prone. You need a visual dashboard that makes server management instant.

Cockpit Web Console Manager installs and configures Cockpit — the lightweight, web-based Linux admin panel built into most major distros. Monitor CPU/memory/disk in real-time, manage systemd services, view logs, and access a terminal — all from your browser at port 9090.

**What it does:**
- 🖥️ One-command install on Ubuntu, Debian, Fedora, RHEL, Arch, openSUSE
- 📦 Module management — add VM management, container support, storage tools
- 🔧 Configuration — custom ports, SSL certs, idle timeouts, reverse proxy
- 🌐 Multi-server dashboard — manage multiple machines from one Cockpit
- 🔐 SSL certificate setup — self-signed or Let's Encrypt
- 📊 Full status checks with module inventory and session info

Perfect for developers, sysadmins, and homelab enthusiasts who want web-based server management without the overhead of enterprise tools.

## Quick Start Preview

```bash
# Install Cockpit with all modules
bash scripts/install.sh --full

# Check status
bash scripts/status.sh --full

# ✅ Cockpit is running
# 🌐 Dashboard: https://your-server:9090
```

## Core Capabilities

1. Auto-detect distro and install — Ubuntu, Debian, Fedora, RHEL, CentOS, Arch, openSUSE
2. Module management — install/remove machines, podman, storage, network, PCP modules
3. Custom port configuration — change from default 9090 to any port
4. SSL certificate management — self-signed generation or custom cert installation
5. Multi-server management — add remote hosts for unified dashboard
6. Reverse proxy configs — generate Nginx proxy config with WebSocket support
7. Firewall auto-configuration — opens ports in UFW or firewalld automatically
8. Config backup & restore — snapshot and restore all Cockpit settings
9. Health check dashboard — service status, SSL validity, sessions, resource usage
10. Login banner customization — set custom security banners

## Dependencies
- `bash` (4.0+)
- `systemctl` (systemd-based Linux)
- Package manager (apt/dnf/pacman/zypper)

## Installation Time
**5 minutes** — run install script, open browser
