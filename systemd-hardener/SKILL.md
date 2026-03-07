---
name: systemd-hardener
description: >-
  Audit and harden systemd service units with sandboxing, capability restrictions, and filesystem protections.
categories: [security, automation]
dependencies: [systemd, bash]
---

# Systemd Security Hardener

## What This Does

Audits systemd service units using `systemd-analyze security`, identifies weak spots, and applies hardening directives (sandboxing, capability dropping, filesystem protections). Turns your "UNSAFE" services into "OK" or "GOOD" rated units without breaking them.

**Example:** "Scan all services, find the 10 worst-scoring ones, generate hardened override files, and test they still start."

## Quick Start (5 minutes)

### 1. Check Prerequisites

```bash
# Requires systemd 248+ (for security scoring)
systemctl --version | head -1

# Verify systemd-analyze is available
which systemd-analyze
```

### 2. Audit All Services

```bash
# Scan all running services and rank by security exposure
bash scripts/hardener.sh audit

# Output:
# SERVICE                          EXPOSURE  RATING
# docker.service                   9.6       UNSAFE
# nginx.service                    9.2       UNSAFE
# postgresql.service               8.8       EXPOSED
# sshd.service                     7.4       MEDIUM
# ...
```

### 3. Audit a Specific Service

```bash
# Deep audit with recommendations
bash scripts/hardener.sh audit --service nginx.service

# Output:
# === Security Audit: nginx.service ===
# Current Score: 9.2/10 (UNSAFE)
#
# ❌ PrivateTmp=no                    → Recommend: PrivateTmp=yes
# ❌ ProtectSystem=no                 → Recommend: ProtectSystem=strict
# ❌ ProtectHome=no                   → Recommend: ProtectHome=yes
# ❌ NoNewPrivileges=no               → Recommend: NoNewPrivileges=yes
# ❌ CapabilityBoundingSet=~          → Recommend: Drop unused capabilities
# ✅ User=www-data                    → Good: Not running as root
```

### 4. Generate Hardening Override

```bash
# Generate a systemd override file with recommended hardening
bash scripts/hardener.sh harden --service nginx.service --output /tmp/nginx-override.conf

# Review the override
cat /tmp/nginx-override.conf

# Apply it (requires sudo)
sudo mkdir -p /etc/systemd/system/nginx.service.d/
sudo cp /tmp/nginx-override.conf /etc/systemd/system/nginx.service.d/hardening.conf
sudo systemctl daemon-reload
sudo systemctl restart nginx.service
```

### 5. Verify Improvement

```bash
bash scripts/hardener.sh audit --service nginx.service
# New Score: 4.2/10 (OK) — improved from 9.2!
```

## Core Workflows

### Workflow 1: Full System Audit

**Use case:** See which services are most exposed

```bash
bash scripts/hardener.sh audit --sort exposure --top 20
```

### Workflow 2: Generate Override for Service

**Use case:** Harden a specific service without editing the unit file directly

```bash
# Conservative mode — only applies safe directives that rarely break services
bash scripts/hardener.sh harden --service myapp.service --mode conservative

# Aggressive mode — maximum hardening (may need tuning)
bash scripts/hardener.sh harden --service myapp.service --mode aggressive

# Custom — pick specific directives
bash scripts/hardener.sh harden --service myapp.service \
  --enable PrivateTmp,ProtectSystem,NoNewPrivileges,ProtectHome
```

### Workflow 3: Batch Harden All Unsafe Services

**Use case:** Generate overrides for all services scoring above 7.0

```bash
bash scripts/hardener.sh harden-all --threshold 7.0 --mode conservative --output-dir /tmp/hardening/

# Review generated overrides
ls /tmp/hardening/
# docker.service.d/hardening.conf
# nginx.service.d/hardening.conf
# postgresql.service.d/hardening.conf
```

### Workflow 4: Test Hardening Without Applying

**Use case:** Dry-run to see what would change

```bash
bash scripts/hardener.sh harden --service nginx.service --dry-run
```

### Workflow 5: Compare Before/After

**Use case:** Show the security improvement

```bash
bash scripts/hardener.sh compare --service nginx.service --override /tmp/nginx-override.conf
# Before: 9.2/10 (UNSAFE)
# After:  4.2/10 (OK)
# Improvement: 5.0 points (54% reduction in exposure)
```

## Hardening Directives Reference

### Safe Directives (rarely break services)

| Directive | What It Does |
|-----------|-------------|
| `PrivateTmp=yes` | Isolated /tmp per service |
| `ProtectSystem=strict` | Read-only filesystem (except /dev, /proc, /sys) |
| `ProtectHome=yes` | Hide /home, /root, /run/user |
| `NoNewPrivileges=yes` | Prevent privilege escalation |
| `ProtectKernelTunables=yes` | Read-only /proc/sys, /sys |
| `ProtectKernelModules=yes` | Deny module loading |
| `ProtectControlGroups=yes` | Read-only cgroup filesystem |
| `RestrictNamespaces=yes` | Deny namespace creation |
| `RestrictRealtime=yes` | Deny realtime scheduling |
| `PrivateDevices=yes` | No access to physical devices |
| `MemoryDenyWriteExecute=yes` | No W^X memory pages |

### Aggressive Directives (may need tuning)

| Directive | What It Does |
|-----------|-------------|
| `ProtectSystem=strict` + `ReadWritePaths=` | Strict FS with explicit write paths |
| `CapabilityBoundingSet=` | Drop ALL capabilities |
| `SystemCallFilter=@system-service` | Whitelist only common syscalls |
| `RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX` | Only network + unix sockets |
| `IPAddressDeny=any` | Block all network (for local-only services) |
| `LockPersonality=yes` | Lock execution domain |

## Troubleshooting

### Service won't start after hardening

**Fix:** Check which directive broke it:
```bash
# Check journal for permission errors
journalctl -u myservice.service -n 50 --no-pager | grep -i "denied\|permission\|access"

# Remove the override temporarily
sudo rm /etc/systemd/system/myservice.service.d/hardening.conf
sudo systemctl daemon-reload
sudo systemctl restart myservice.service

# Re-apply with conservative mode
bash scripts/hardener.sh harden --service myservice.service --mode conservative
```

### ProtectSystem=strict blocks writes

**Fix:** Add explicit write paths:
```ini
[Service]
ProtectSystem=strict
ReadWritePaths=/var/lib/myapp /var/log/myapp
```

### MemoryDenyWriteExecute breaks JIT-compiled apps

**Fix:** Remove this directive for Node.js, Python, Java, etc.

## Dependencies

- `systemd` (248+ recommended, 232+ minimum)
- `bash` (4.0+)
- `awk`, `grep`, `sed` (standard)
- Root/sudo access for applying overrides
