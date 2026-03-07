# Listing Copy: Systemd Security Hardener

## Metadata
- **Type:** Skill
- **Name:** systemd-hardener
- **Display Name:** Systemd Security Hardener
- **Categories:** [security, automation]
- **Price:** $12
- **Dependencies:** [systemd, bash]

## Tagline

"Audit and harden systemd services — Find and fix security exposures in minutes"

## Description

Most systemd services run with zero sandboxing by default. That means every service has full filesystem access, can load kernel modules, and escalate privileges. You're one exploit away from full system compromise.

Systemd Security Hardener scans all your running services, scores their security exposure (0-10), and generates hardening override files that apply sandboxing, capability restrictions, and filesystem protections. No manual systemd documentation reading — just run the audit, review recommendations, and apply.

**What it does:**
- 🔍 Audit all services with security exposure scores (0-10)
- 🛡️ Generate hardening overrides (conservative or aggressive mode)
- 📋 Batch harden all unsafe services above a threshold
- 🔄 Compare before/after security improvements
- 🏗️ Non-destructive — uses systemd drop-in overrides, never edits unit files
- ⚡ 5-minute setup — no dependencies beyond systemd itself

**Who it's for:** Sysadmins, DevOps engineers, and security-conscious developers who want to lock down their Linux servers without spending hours reading systemd.exec(5) man pages.

## Core Capabilities

1. Full system security audit — Score all running services
2. Per-service deep analysis — See exactly which directives are missing
3. Conservative hardening — Safe defaults that rarely break services
4. Aggressive hardening — Maximum sandboxing with syscall filtering
5. Custom directive selection — Pick exactly which protections to enable
6. Batch hardening — Fix all services above a threshold at once
7. Dry-run mode — Preview changes before applying
8. Drop-in overrides — Never modifies original unit files
9. Before/after comparison — Quantify security improvements
10. Zero external dependencies — Just bash and systemd
