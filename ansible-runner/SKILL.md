---
name: ansible-runner
description: >-
  Install Ansible, manage inventories, and run playbooks to automate server configuration and deployment.
categories: [dev-tools, automation]
dependencies: [python3, pip, ssh]
---

# Ansible Playbook Runner

## What This Does

Automates server configuration and application deployment using Ansible. Install Ansible, manage host inventories, run playbooks, and handle multi-server orchestration — all from your OpenClaw agent.

**Example:** "Set up Nginx on 3 servers, deploy my app, configure SSL — all with one playbook run."

## Quick Start (5 minutes)

### 1. Install Ansible

```bash
bash scripts/install.sh
```

This installs Ansible via pip, verifies the installation, and sets up a default config.

### 2. Set Up Inventory

```bash
bash scripts/inventory.sh add webserver 192.168.1.10 --user deploy --key ~/.ssh/id_ed25519
bash scripts/inventory.sh add dbserver 192.168.1.20 --user deploy --key ~/.ssh/id_ed25519
bash scripts/inventory.sh list
```

### 3. Run Your First Playbook

```bash
# Ping all hosts to verify connectivity
bash scripts/run.sh ping --inventory inventory.ini

# Run a playbook
bash scripts/run.sh playbook examples/setup-server.yml --inventory inventory.ini
```

## Core Workflows

### Workflow 1: Install Ansible

```bash
bash scripts/install.sh

# Output:
# ✅ Python 3.x found
# ✅ Installing Ansible via pip...
# ✅ Ansible 2.x.x installed successfully
# ✅ ansible.cfg created at ./ansible.cfg
```

### Workflow 2: Manage Inventory

```bash
# Add hosts
bash scripts/inventory.sh add web1 10.0.0.1 --user root --port 22
bash scripts/inventory.sh add web2 10.0.0.2 --user root --port 22
bash scripts/inventory.sh add db1 10.0.0.3 --user root --group databases

# Create groups
bash scripts/inventory.sh group webservers web1,web2
bash scripts/inventory.sh group databases db1

# List all hosts
bash scripts/inventory.sh list

# Output:
# [webservers]
# web1 ansible_host=10.0.0.1 ansible_user=root ansible_port=22
# web2 ansible_host=10.0.0.2 ansible_user=root ansible_port=22
#
# [databases]
# db1 ansible_host=10.0.0.3 ansible_user=root
```

### Workflow 3: Run Playbooks

```bash
# Run a playbook on all hosts
bash scripts/run.sh playbook my-playbook.yml

# Run on specific group
bash scripts/run.sh playbook my-playbook.yml --limit webservers

# Dry run (check mode)
bash scripts/run.sh playbook my-playbook.yml --check

# Run with extra variables
bash scripts/run.sh playbook deploy.yml --extra-vars "version=2.1.0 env=production"

# Run with verbose output
bash scripts/run.sh playbook my-playbook.yml -v
```

### Workflow 4: Ad-hoc Commands

```bash
# Run a command on all hosts
bash scripts/run.sh command "uptime" --inventory inventory.ini

# Install a package on webservers
bash scripts/run.sh command "apt-get install -y nginx" --limit webservers --become

# Copy a file to all hosts
bash scripts/run.sh command "copy src=/tmp/config.conf dest=/etc/app/config.conf" --module copy

# Restart a service
bash scripts/run.sh command "name=nginx state=restarted" --module service --become
```

### Workflow 5: Generate Playbooks from Templates

```bash
# Generate a server setup playbook
bash scripts/generate.sh server-setup --packages "nginx,certbot,fail2ban" --user deploy

# Generate a deploy playbook
bash scripts/generate.sh deploy --repo "git@github.com:user/app.git" --path /opt/app --service app

# Generate a database backup playbook
bash scripts/generate.sh db-backup --type postgres --db myapp --dest /backups --schedule daily
```

## Configuration

### ansible.cfg (auto-generated)

```ini
[defaults]
inventory = ./inventory.ini
remote_user = deploy
host_key_checking = False
timeout = 30
forks = 10
retry_files_enabled = False

[privilege_escalation]
become = True
become_method = sudo
become_ask_pass = False

[ssh_connection]
pipelining = True
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```

### Environment Variables

```bash
# SSH key for all hosts (optional, overrides per-host keys)
export ANSIBLE_SSH_KEY="~/.ssh/id_ed25519"

# Vault password for encrypted vars
export ANSIBLE_VAULT_PASSWORD="your-vault-password"

# Custom inventory path
export ANSIBLE_INVENTORY="./inventory.ini"
```

## Advanced Usage

### Ansible Vault (Encrypted Secrets)

```bash
# Encrypt a file
bash scripts/vault.sh encrypt secrets.yml

# Decrypt a file
bash scripts/vault.sh decrypt secrets.yml

# Edit encrypted file
bash scripts/vault.sh edit secrets.yml

# Run playbook with vault
bash scripts/run.sh playbook deploy.yml --ask-vault-pass
```

### Rolling Deployments

```bash
# Deploy to webservers 2 at a time
bash scripts/run.sh playbook deploy.yml --limit webservers --forks 2 --extra-vars "serial=2"
```

### Run as OpenClaw Cron

```bash
# Daily server health check
bash scripts/run.sh playbook examples/health-check.yml --inventory inventory.ini 2>&1 | tail -20
```

## Included Playbook Templates

### examples/setup-server.yml
Basic server hardening: update packages, configure firewall, set up fail2ban, create deploy user.

### examples/deploy-app.yml
Git-based deployment: pull repo, install deps, restart service, verify health.

### examples/health-check.yml
Server health: check disk, memory, CPU, running services, SSL expiry.

### examples/db-backup.yml
Database backup: dump Postgres/MySQL, compress, upload to S3/remote.

## Troubleshooting

### Issue: "ansible: command not found"

```bash
# Re-run installer
bash scripts/install.sh

# Or install manually
pip3 install --user ansible
export PATH="$HOME/.local/bin:$PATH"
```

### Issue: SSH connection refused

```bash
# Test SSH manually
ssh -i ~/.ssh/id_ed25519 deploy@10.0.0.1

# Check inventory
bash scripts/inventory.sh list

# Run with verbose SSH
bash scripts/run.sh playbook test.yml -vvv
```

### Issue: Permission denied (sudo)

```bash
# Add --become flag
bash scripts/run.sh playbook my-playbook.yml --become

# Or configure in ansible.cfg
# [privilege_escalation]
# become = True
```

### Issue: Host key verification failed

```bash
# Disable host key checking (already in default config)
export ANSIBLE_HOST_KEY_CHECKING=False
```

## Dependencies

- `python3` (3.8+)
- `pip3` (Python package manager)
- `ssh` (OpenSSH client)
- `sshpass` (optional, for password auth)
