# Listing Copy: Terraform Manager

## Metadata
- **Type:** Skill
- **Name:** terraform-manager
- **Display Name:** Terraform Manager
- **Categories:** [dev-tools, automation]
- **Icon:** 🏗️
- **Dependencies:** [bash, curl, unzip, jq]

## Tagline

Manage Terraform infrastructure — install, plan, apply, drift detection, and state management.

## Description

Managing infrastructure as code shouldn't require memorizing dozens of Terraform commands and flags. When you're juggling multiple environments, tracking drift, and coordinating state across teams, the cognitive overhead adds up fast.

Terraform Manager gives your OpenClaw agent full control over your Terraform workflow. Install or upgrade Terraform automatically, run the full init → plan → apply cycle, manage workspaces for multi-environment deployments, and detect configuration drift with scheduled checks and Telegram alerts.

**What it does:**
- 📦 Install/upgrade Terraform (any version, any OS/arch)
- 🔍 Plan & apply with saved plan files
- 🏗️ Workspace management (create, switch, delete environments)
- ⚠️ Drift detection with Telegram/webhook alerts
- 📊 State management (list, show, move, import, backup)
- 🔐 Checksum verification on all downloads
- 🕐 Cron-ready drift checks (schedule every 6 hours)

**Who it's for:** DevOps engineers, platform teams, and indie hackers managing cloud infrastructure with Terraform.

## Core Capabilities

1. Auto-install — Downloads correct binary for your OS/arch with SHA256 verification
2. Version management — Install specific versions or auto-fetch latest
3. Plan & apply — Full lifecycle with saved plan file support
4. Workspace management — Multi-environment isolation (dev/staging/prod)
5. Drift detection — Compares actual infrastructure to config, alerts on changes
6. State operations — List, show, move, remove, import, backup/restore
7. Format & validate — Check HCL syntax and style
8. Resource graphing — Generate dependency graphs (DOT format)
9. Multi-provider — Works with AWS, GCP, Azure, and any Terraform provider
10. Cron-ready — Schedule drift checks with alerting

## Dependencies
- `bash` (4.0+)
- `curl`
- `unzip`
- `jq`
- Optional: `graphviz` (for resource graphs)
