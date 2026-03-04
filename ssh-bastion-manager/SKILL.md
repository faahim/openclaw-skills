---
name: ssh-bastion-manager
description: Install and configure a hardened SSH bastion host with key-only auth, optional fail2ban, UFW rules, user onboarding, and audit checks. Use when setting up or maintaining secure SSH jump servers.
categories: [security, dev-tools]
dependencies: [bash, sshd, ufw, fail2ban]
---

# SSH Bastion Manager

Set up a secure SSH jump host fast.

This skill automates bastion hardening tasks that are easy to mess up manually: sshd lockdown, key-only auth, firewall rules, fail2ban, user onboarding, and ongoing audits.

## Quick Start

```bash
# 1) Install dependencies (Ubuntu/Debian)
bash scripts/install.sh

# 2) Harden SSH + firewall
sudo bash scripts/setup.sh --ssh-port 2222 --admin-user "$USER"

# 3) Add a team member (public key file)
sudo bash scripts/create-user.sh --user deploy --pubkey ~/.ssh/deploy.pub

# 4) Run security audit
bash scripts/audit.sh --expected-port 2222
```

## What It Configures

- SSH key-only auth (`PasswordAuthentication no`)
- Root login disabled (`PermitRootLogin no`)
- Optional custom SSH port
- UFW allow only SSH port (+ optional extra CIDRs)
- Fail2ban for sshd
- New users with least-privileged SSH access

## Core Workflows

### 1) New Bastion Setup

```bash
sudo bash scripts/setup.sh --ssh-port 2222 --admin-user ubuntu
```

### 2) Allow Office IP Range

```bash
sudo bash scripts/setup.sh --ssh-port 2222 --allow-cidr 203.0.113.0/24
```

### 3) Add/Rotate User Access

```bash
sudo bash scripts/create-user.sh --user alice --pubkey /tmp/alice.pub
```

### 4) Recurring Security Audit

```bash
bash scripts/audit.sh --expected-port 2222
```

## Troubleshooting

- **Locked out after port change?** Keep your existing SSH session open while testing new port.
- **UFW inactive?** Run `sudo ufw enable` and retry setup.
- **Fail2ban missing jail?** `sudo systemctl restart fail2ban && sudo fail2ban-client status sshd`.

## Safety Notes

- Run setup from an active SSH session and verify new access before closing.
- Store SSH keys securely; never email private keys.
- Use cloud security groups plus host firewall for defense-in-depth.
