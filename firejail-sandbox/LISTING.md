# Listing Copy: Firejail Sandbox Manager

## Metadata
- **Type:** Skill
- **Name:** firejail-sandbox
- **Display Name:** Firejail Sandbox Manager
- **Categories:** [security, automation]
- **Price:** $10
- **Icon:** 🔒
- **Dependencies:** [firejail, bash]

## Tagline

Sandbox untrusted apps — restrict file, network, and system access with Firejail

## Description

Every app you run has full access to your home directory, SSH keys, browser history, and network. One malicious script or compromised app can exfiltrate everything. Firejail fixes this by sandboxing applications using Linux namespaces and seccomp filters.

Firejail Sandbox Manager installs and configures Firejail, creates custom restrictive profiles for your apps, and audits which applications are running unprotected. No containers, no VMs — just lightweight OS-level sandboxing that works with any Linux application.

**What it does:**
- 🔒 Install Firejail with one command (Ubuntu, Fedora, Arch, etc.)
- 🛡️ Sandbox any app — browsers, scripts, downloads, dev tools
- 📝 Generate custom restrictive profiles with sane defaults
- 🔍 Audit which high-risk apps lack sandbox coverage
- 🌐 Network isolation — run apps with zero network access
- 📁 Filesystem restrictions — blacklist ~/.ssh, ~/.gnupg, sensitive dirs
- 🔇 Device control — disable sound, webcam, GPU access per app
- 📊 Monitor active sandboxes in real-time

Perfect for developers running untrusted code, security-conscious users who want defense-in-depth, and sysadmins hardening workstations.

## Quick Start Preview

```bash
# Install Firejail
bash scripts/install.sh

# Run Firefox sandboxed
firejail --private firefox

# Run untrusted script with no network
firejail --net=none --private bash untrusted.sh

# Audit your apps
bash scripts/audit.sh
```

## Core Capabilities

1. One-command install — auto-detects OS, installs from package manager
2. App sandboxing — restrict any Linux app's filesystem/network/device access
3. Custom profiles — generate restrictive profiles with sane defaults
4. Network isolation — completely cut off network per-app
5. Filesystem blacklists — protect SSH keys, cloud creds, sensitive files
6. Security audit — shows which high-risk apps lack sandbox profiles
7. Profile inspector — pretty-print what each profile restricts
8. Active monitoring — list and tree-view of running sandboxes
9. Overlay filesystem — persistent sandboxes that don't touch real files
10. X11 sandboxing — prevent keyloggers via Xephyr/Xpra isolation
