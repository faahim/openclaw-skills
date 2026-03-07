# Listing Copy: Mosh — Mobile Shell Manager

## Metadata
- **Type:** Skill
- **Name:** mosh-shell
- **Display Name:** Mosh — Mobile Shell Manager
- **Categories:** [dev-tools, communication]
- **Icon:** 📡
- **Price:** $8
- **Dependencies:** [mosh, ufw/iptables]

## Tagline

Install and configure Mosh for persistent SSH that survives network changes and roaming

## Description

SSH drops when your WiFi blips, your laptop sleeps, or you switch from office to mobile hotspot. Every developer and sysadmin knows the pain of reconnecting, re-authenticating, and finding your terminal state.

Mosh (Mobile Shell) replaces SSH for interactive sessions. It uses UDP instead of TCP, provides instant local echo on high-latency connections, and reconnects automatically when your network changes. This skill installs mosh on servers and clients, configures firewall rules, sets up connection profiles, and includes a diagnostic tool for troubleshooting.

**What it does:**
- 🔧 One-command install on any Linux distro or macOS
- 🔥 Auto-configures firewall (ufw/iptables/firewalld)
- 📋 Save and manage connection profiles
- 🔍 Diagnose connection issues (SSH, ports, locale, mosh version)
- 🖥️ Multi-server batch install from a hosts file
- 🔄 Survives WiFi→cellular→WiFi transitions seamlessly

Perfect for developers SSH-ing into remote servers, sysadmins managing infrastructure from unreliable networks, and anyone tired of "broken pipe" errors.

## Core Capabilities

1. Auto-detect OS and install mosh via native package manager
2. Configure firewall UDP port rules (ufw, iptables, firewalld)
3. Save connection profiles with SSH port, key, and tmux settings
4. Batch install across multiple servers from a hosts file
5. Diagnose connection issues with 6-point check
6. Tmux integration for double-resilient sessions
7. Jump host / bastion support
8. Locale verification and auto-fix
9. Works on Ubuntu, Debian, Fedora, CentOS, Arch, Alpine, macOS

## Dependencies
- `bash` (4.0+)
- `ssh` (for initial handshake)
- Package manager (apt/yum/dnf/pacman/brew)

## Installation Time
**3 minutes** — run install script, connect immediately
