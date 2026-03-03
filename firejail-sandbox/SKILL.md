---
name: firejail-sandbox
description: >-
  Install and manage Firejail application sandboxing — restrict apps from accessing files, network, and system resources they don't need.
categories: [security, automation]
dependencies: [firejail, bash]
---

# Firejail Sandbox Manager

## What This Does

Sandbox untrusted or risky applications using Firejail — a SUID program that restricts the running environment of applications using Linux namespaces, seccomp-bpf, and capabilities. Prevent apps from accessing your home directory, network, or other processes.

**Example:** "Run Firefox in a sandbox that can't read ~/.ssh, ~/.gnupg, or ~/Documents. Run a downloaded script with no network access."

## Quick Start (5 minutes)

### 1. Install Firejail

```bash
bash scripts/install.sh
```

### 2. Sandbox Any Application

```bash
# Run Firefox sandboxed (uses built-in profile)
firejail firefox

# Run a script with no network access
firejail --net=none bash /path/to/untrusted-script.sh

# Run an app with read-only home directory
firejail --private python3 suspicious-app.py
```

### 3. Check What's Restricted

```bash
# List active sandboxes
firejail --list

# Show sandbox details
firejail --tree

# Test a profile (dry run)
firejail --debug firefox 2>&1 | head -50
```

## Core Workflows

### Workflow 1: Sandbox a Browser

**Use case:** Isolate your browser from sensitive files

```bash
# Firefox with private home (temp home, wiped on exit)
firejail --private firefox

# Chromium with restricted filesystem
firejail --blacklist=~/.ssh --blacklist=~/.gnupg --blacklist=~/Documents chromium-browser

# Browser with no access to real downloads (uses temp dir)
firejail --private-tmp --private-dev firefox
```

### Workflow 2: Run Untrusted Code Safely

**Use case:** Execute a downloaded script without risking your system

```bash
# No network, no home access, read-only filesystem
firejail --net=none --private --read-only=/ bash untrusted.sh

# Python script with minimal permissions
firejail --net=none --private --nogroups --nosound python3 sketch-script.py

# Node.js app sandboxed
firejail --net=none --private --blacklist=/etc node suspicious-app.js
```

### Workflow 3: Create Custom Profiles

**Use case:** Define reusable sandbox rules for specific apps

```bash
# Generate a restrictive profile for an app
bash scripts/create-profile.sh myapp

# Edit the generated profile
nano ~/.config/firejail/myapp.local

# Run with custom profile
firejail --profile=~/.config/firejail/myapp.local myapp
```

### Workflow 4: Network Isolation

**Use case:** Run apps with no network or restricted network

```bash
# Complete network isolation
firejail --net=none transmission-gtk

# Restrict to specific interface
firejail --net=eth0 curl https://example.com

# Restrict DNS
firejail --dns=1.1.1.1 --dns=9.9.9.9 firefox
```

### Workflow 5: Audit Sandbox Coverage

**Use case:** Check which apps have Firejail profiles

```bash
# List all available profiles
bash scripts/audit.sh

# Check if a specific app has a profile
firejail --debug-check appname

# Show what a profile restricts
bash scripts/show-profile.sh firefox
```

## Configuration

### Default Restrictions (firejail.config)

```bash
# /etc/firejail/firejail.config
# Global settings

# Restrict all users to firejail profiles
force-nonewprivs yes

# Enable AppArmor integration (if available)
# apparmor yes

# Restrict access to /proc
restrict-namespaces yes
```

### Custom Profile Format

```
# ~/.config/firejail/myapp.local
# Whitelist only what the app needs

# Filesystem
whitelist ~/myapp-data
blacklist ~/.ssh
blacklist ~/.gnupg
blacklist ~/.aws
read-only ~/Documents

# Network
# net none          # No network at all
# dns 1.1.1.1      # Restrict DNS

# System
nogroups
nosound
no3d
notv
novideo
nodvd

# Capabilities
caps.drop all

# Seccomp
seccomp

# Process
noroot
private-tmp
private-dev
```

### Environment Variables

```bash
# Override default profile directory
export FIREJAIL_PROFILE_DIR="$HOME/.config/firejail"

# Enable verbose logging
export FIREJAIL_DEBUG=1
```

## Advanced Usage

### Persistent Sandbox (Overlay Filesystem)

```bash
# Changes persist in overlay, not real filesystem
firejail --overlay firefox

# Named overlay (reusable between sessions)
firejail --overlay-named=work-browser firefox
```

### Sandbox All Apps by Default

```bash
# Create symlinks for automatic sandboxing
sudo firecfg

# Now running "firefox" automatically uses firejail
# To undo:
sudo firecfg --clean
```

### Monitor Sandbox Activity

```bash
# Watch active sandboxes
watch -n 2 firejail --list

# Get PID tree of sandboxed processes
firejail --tree

# Check resource usage of sandbox
firejail --top
```

### X11 Sandboxing (Prevent Keyloggers)

```bash
# Run with Xephyr (separate X server)
firejail --x11=xephyr firefox

# Run with Xpra (rootless)
firejail --x11=xpra firefox
```

## Troubleshooting

### Issue: "Permission denied" when running firejail

**Fix:**
```bash
# Firejail needs SUID bit
sudo chmod 4755 /usr/bin/firejail
```

### Issue: App doesn't work in sandbox

**Fix:** Relax restrictions incrementally
```bash
# Start with minimal restrictions
firejail --noprofile myapp

# Add restrictions one by one
firejail --seccomp myapp
firejail --seccomp --private-tmp myapp
firejail --seccomp --private-tmp --nogroups myapp
# Stop when it breaks → that's the restriction to skip
```

### Issue: Can't access files in sandbox

**Fix:** Whitelist specific directories
```bash
firejail --whitelist=~/Projects/myapp --whitelist=~/Downloads myapp
```

### Issue: No sound in sandboxed app

**Fix:** Remove nosound from profile or run with:
```bash
firejail --ignore=nosound spotify
```

## Scripts Reference

### scripts/install.sh
Installs Firejail from package manager, verifies SUID, creates config directory.

### scripts/create-profile.sh
Generates a restrictive custom profile for any application with sane defaults.

### scripts/audit.sh
Lists all apps with/without Firejail profiles, highlights high-risk unsandboxed apps.

### scripts/show-profile.sh
Pretty-prints what a Firejail profile restricts (filesystem, network, capabilities).

## Key Principles

1. **Least privilege** — Deny everything, whitelist what's needed
2. **Layer defenses** — Namespaces + seccomp + caps + filesystem restrictions
3. **Test first** — Use --noprofile, add restrictions gradually
4. **Profile per app** — Custom profiles in ~/.config/firejail/
5. **Audit regularly** — Check which apps run unsandboxed
