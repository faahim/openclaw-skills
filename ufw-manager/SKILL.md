---
name: ufw-manager
description: Install, configure, and audit UFW firewall rules with safe presets and rollback.
categories: [security, automation]
dependencies: [bash, ufw, iptables, jq]
---

# UFW Manager

Install and manage a host firewall using UFW with safer defaults, profile-based setup, rule auditing, and rollback.

## Quick Start

### 1) Install and backup current firewall state

```bash
bash scripts/install.sh
bash scripts/ufw-manager.sh backup --tag before-setup
```

### 2) Apply safe baseline (SSH + outgoing allow)

```bash
bash scripts/ufw-manager.sh baseline --ssh-port 22
bash scripts/ufw-manager.sh status
```

### 3) Add app rules

```bash
bash scripts/ufw-manager.sh allow 80/tcp
bash scripts/ufw-manager.sh allow 443/tcp
bash scripts/ufw-manager.sh status
```

## Commands

```bash
# status / audit
bash scripts/ufw-manager.sh status
bash scripts/ufw-manager.sh audit

# baseline + app rules
bash scripts/ufw-manager.sh baseline --ssh-port 22
bash scripts/ufw-manager.sh allow 443/tcp
bash scripts/ufw-manager.sh deny 23/tcp

# backup / rollback
bash scripts/ufw-manager.sh backup --tag before-change
bash scripts/ufw-manager.sh rollback --tag before-change
```

## What baseline does

- Sets default incoming policy to `deny`
- Sets default outgoing policy to `allow`
- Allows SSH on selected port
- Enables UFW if disabled
- Saves state snapshot for rollback

## Troubleshooting

### Locked out after changes
Use your provider console/KVM and rollback:

```bash
bash scripts/ufw-manager.sh rollback --latest
```

### UFW not installed

```bash
bash scripts/install.sh
```

## Notes

- Requires sudo/root.
- Always create a backup before rule changes.
- Supports Debian/Ubuntu directly; other distros require manual UFW install.
