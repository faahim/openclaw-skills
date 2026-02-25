# Listing Copy: Ansible Playbook Runner

## Metadata
- **Type:** Skill
- **Name:** ansible-runner
- **Display Name:** Ansible Playbook Runner
- **Categories:** [dev-tools, automation]
- **Icon:** 🤖
- **Dependencies:** [python3, pip, ssh]

## Tagline
Automate server setup, deployment, and management — run Ansible playbooks from your agent.

## Description

Managing multiple servers manually is slow and error-prone. SSH-ing into each box to run commands, install packages, and configure services doesn't scale — and it's exactly the kind of repetitive work your agent should handle.

Ansible Playbook Runner installs Ansible, manages your host inventory, and runs playbooks to automate server configuration and deployment. Set up 10 servers with identical configs, deploy your app with a single command, or run daily health checks across your entire infrastructure.

**What it does:**
- 🔧 One-command Ansible installation and setup
- 📋 Manage host inventories (add/remove/group servers)
- 📜 Run playbooks for server setup, deployment, backups
- ⚡ Execute ad-hoc commands across multiple servers
- 🏗️ Generate playbooks from templates (server hardening, deploy, backup)
- 🔐 Ansible Vault for encrypted secrets
- 📊 Server health checks (disk, memory, services, SSL)

Perfect for developers and sysadmins who manage multiple servers and want their OpenClaw agent to handle infrastructure automation.

## Core Capabilities

1. Install & configure Ansible — One script sets up everything
2. Inventory management — Add, remove, group servers from CLI
3. Playbook execution — Run with limits, check mode, extra vars
4. Ad-hoc commands — Quick commands across all servers
5. Playbook templates — Generate server setup, deploy, backup playbooks
6. Vault encryption — Secure secrets management
7. Health monitoring — Disk, memory, services, SSL expiry checks
8. Rolling deploys — Deploy to servers N at a time
9. Fact gathering — Query server hardware/software info
10. Cron-ready — Schedule automated infrastructure tasks
