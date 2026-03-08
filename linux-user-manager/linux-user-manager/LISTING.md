# Listing Copy: Linux User Manager

## Metadata
- **Type:** Skill
- **Name:** linux-user-manager
- **Display Name:** Linux User Manager
- **Categories:** [security, automation]
- **Price:** $12
- **Dependencies:** [bash, useradd, usermod, chage, passwd]
- **Icon:** 👤

## Tagline

Manage Linux users, groups, sudo & SSH keys — one tool, zero mistakes

## Description

Managing Linux user accounts manually is tedious and error-prone. One wrong `chmod`, a forgotten group membership, or a missed password expiry can create security holes. You need a single, reliable tool that handles it all.

Linux User Manager wraps all user administration into a clean CLI. Create users with SSH keys and sudo access in one command. Enforce password policies. Audit who has access to what. Bulk-create from CSV. Every change is logged automatically.

**What it does:**
- 👤 Create, modify, delete users with full configuration
- 🔑 SSH key management (add, remove, list per user)
- 🛡️ Sudo access control (grant, revoke, passwordless)
- 🔒 Password policies (expiry, aging, force-change, lock/unlock)
- 👥 Group management (create, add/remove members)
- 📊 Security audits (login history, expiring passwords, inactive users)
- 📋 Bulk operations (create users from CSV)
- 📝 Automatic audit logging to `/var/log/user-manager.log`

Perfect for sysadmins, DevOps engineers, and anyone managing Linux servers who wants reliable user management without memorizing a dozen commands.

## Quick Start Preview

```bash
# Create user with SSH key, sudo, and password expiry
sudo bash scripts/user-manager.sh create \
  --username deploy \
  --groups sudo,docker \
  --ssh-key "ssh-ed25519 AAAA..." \
  --password-expire 90

# Full security audit
bash scripts/user-manager.sh audit --full
```

## Core Capabilities

1. User lifecycle — Create, modify, delete with one command
2. SSH key management — Add, remove, list keys per user
3. Sudo control — Grant/revoke sudo, passwordless option
4. Password policies — Max/min age, force-change, lock/unlock
5. Group management — Create groups, manage memberships
6. Security audit — Login history, expiring passwords, inactive accounts
7. Bulk operations — Create users from CSV
8. Dry-run mode — Preview changes before applying
9. Audit logging — All changes logged automatically
10. Idempotent — Safe to run multiple times

## Dependencies
- `bash` (4.0+)
- `useradd` / `usermod` / `userdel`
- `chage`, `passwd`, `getent`, `last`
- All pre-installed on standard Linux distributions

## Installation Time
**2 minutes** — chmod +x, run
