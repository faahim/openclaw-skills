---
name: jupyter-lab-manager
description: >-
  Install, configure, and manage JupyterLab — the interactive computing environment for notebooks, code, and data.
categories: [dev-tools, education]
dependencies: [python3, pip]
---

# Jupyter Lab Manager

## What This Does

Install and manage JupyterLab with one command. Create notebooks, install kernels (Python, Node.js, R), configure remote access with password auth, and manage extensions. No manual pip juggling — everything automated.

**Example:** "Set up JupyterLab on my server with password auth, install Python + Node.js kernels, and start it on port 8888."

## Quick Start (5 minutes)

### 1. Install JupyterLab

```bash
bash scripts/install.sh
```

This installs Python3, pip, JupyterLab, and common data science packages (numpy, pandas, matplotlib).

### 2. Start JupyterLab

```bash
bash scripts/run.sh start
# Output:
# 🚀 JupyterLab running at http://localhost:8888
# Token: abc123...
```

### 3. Set Password (for remote access)

```bash
bash scripts/run.sh password
# Enter password when prompted
# Restart: bash scripts/run.sh restart
```

## Core Workflows

### Workflow 1: Install & Start

```bash
# Full install (JupyterLab + data science stack)
bash scripts/install.sh --full

# Start in background
bash scripts/run.sh start --background --port 8888

# Check status
bash scripts/run.sh status
```

### Workflow 2: Add Kernels

```bash
# Add Node.js kernel (requires Node.js installed)
bash scripts/kernels.sh add nodejs

# Add R kernel (requires R installed)
bash scripts/kernels.sh add r

# Add Bash kernel
bash scripts/kernels.sh add bash

# List all kernels
bash scripts/kernels.sh list
```

### Workflow 3: Remote Access (Server Setup)

```bash
# Generate config for remote access
bash scripts/run.sh configure --ip 0.0.0.0 --port 8888

# Set password
bash scripts/run.sh password

# Start with SSL (self-signed cert)
bash scripts/run.sh start --ssl

# Or use behind reverse proxy (recommended)
bash scripts/run.sh start --no-browser --ip 127.0.0.1
```

### Workflow 4: Manage Extensions

```bash
# Install popular extensions
bash scripts/extensions.sh install jupyterlab-git
bash scripts/extensions.sh install jupyterlab-lsp

# List installed extensions
bash scripts/extensions.sh list

# Disable an extension
bash scripts/extensions.sh disable jupyterlab-git
```

### Workflow 5: Run as Systemd Service

```bash
# Install as system service (auto-start on boot)
bash scripts/run.sh service install

# Manage service
bash scripts/run.sh service start
bash scripts/run.sh service stop
bash scripts/run.sh service status

# Remove service
bash scripts/run.sh service uninstall
```

### Workflow 6: Create Notebooks from Templates

```bash
# Create a data analysis notebook
bash scripts/notebooks.sh create --template data-analysis --name "sales-q1.ipynb"

# Create a machine learning notebook
bash scripts/notebooks.sh create --template ml-starter --name "model.ipynb"

# List notebooks in workspace
bash scripts/notebooks.sh list
```

## Configuration

### Environment Variables

```bash
# JupyterLab home directory
export JUPYTER_HOME="$HOME/jupyter-workspace"

# Default port
export JUPYTER_PORT=8888

# IP to bind (0.0.0.0 for remote access)
export JUPYTER_IP="127.0.0.1"

# Python virtual environment path
export JUPYTER_VENV="$HOME/.jupyter-venv"
```

### Config File

Generated at `~/.jupyter/jupyter_lab_config.py`:

```python
c.ServerApp.ip = '127.0.0.1'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.ServerApp.notebook_dir = '~/jupyter-workspace'
c.ServerApp.allow_remote_access = True
```

## Advanced Usage

### Virtual Environment Isolation

```bash
# Install in isolated venv (recommended for servers)
bash scripts/install.sh --venv ~/.jupyter-venv

# All commands auto-activate the venv
bash scripts/run.sh start  # Uses venv automatically
```

### Docker Mode

```bash
# Run JupyterLab in Docker (no system install needed)
bash scripts/run.sh docker --port 8888 --volume ~/notebooks:/home/jovyan/work

# With GPU support
bash scripts/run.sh docker --gpu --port 8888
```

### Backup & Restore

```bash
# Backup all notebooks + config
bash scripts/notebooks.sh backup --output ~/jupyter-backup-$(date +%Y%m%d).tar.gz

# Restore from backup
bash scripts/notebooks.sh restore --input ~/jupyter-backup-20260301.tar.gz
```

## Troubleshooting

### Issue: "jupyter: command not found"

```bash
# Check if venv is active
source ~/.jupyter-venv/bin/activate
which jupyter

# Or reinstall
bash scripts/install.sh
```

### Issue: Can't access remotely

```bash
# Check IP binding
bash scripts/run.sh configure --ip 0.0.0.0

# Check firewall
sudo ufw allow 8888/tcp

# Restart
bash scripts/run.sh restart
```

### Issue: Kernel dies immediately

```bash
# Check kernel specs
bash scripts/kernels.sh list

# Reinstall Python kernel
bash scripts/kernels.sh add python --force

# Check memory
free -h
```

### Issue: Extensions not loading

```bash
# Rebuild extensions
bash scripts/extensions.sh rebuild

# Check JupyterLab version compatibility
jupyter lab --version
```

## Dependencies

- `python3` (3.9+)
- `pip` (Python package manager)
- `virtualenv` (recommended, auto-installed)
- Optional: `nodejs` (for Node.js kernel + extensions)
- Optional: `R` (for R kernel)
- Optional: `docker` (for Docker mode)
