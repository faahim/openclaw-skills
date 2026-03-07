# Listing Copy: Dagu Workflow Engine Manager

## Metadata
- **Type:** Skill
- **Name:** dagu-workflow-engine
- **Display Name:** Dagu Workflow Engine Manager
- **Categories:** [automation, dev-tools]
- **Icon:** ⚙️
- **Price:** $15
- **Dependencies:** [bash, curl]

## Tagline

Run complex multi-step pipelines with a visual dashboard — no Python, no overhead

## Description

Manually chaining shell commands with `&&` breaks at the first failure and gives you zero visibility. Cron jobs run in isolation with no dependency management. You need a real workflow engine that handles retries, parallelism, and monitoring — without the complexity of Airflow or Temporal.

Dagu Workflow Engine Manager installs and configures Dagu — a lightweight DAG runner that turns simple YAML into powerful pipelines. Define multi-step workflows with dependencies, parallel execution, retry logic, and scheduled runs. Monitor everything from a clean web dashboard.

**What it does:**
- ⚙️ Install Dagu with one command (Linux/Mac, x86/ARM)
- 📋 Create DAGs from templates (backup, deploy, ETL, monitoring)
- 🔄 Schedule pipelines with cron expressions
- 🔀 Parallel execution with dependency chains
- 🔁 Configurable retry policies per step
- 📊 Web dashboard for monitoring and manual triggers
- 🔐 Optional basic auth for the dashboard
- 📦 Export/import DAGs for backup and migration
- 🔔 Built-in email notifications on failure/success
- 🛠️ Systemd service setup for always-on scheduling

Perfect for developers, sysadmins, and DevOps engineers who need reliable task orchestration without enterprise complexity.

## Quick Start Preview

```bash
# Install Dagu
bash scripts/install.sh

# Create a backup pipeline from template
bash scripts/create-dag.sh nightly-backup --template backup

# Start the dashboard
bash scripts/manage.sh start
# → http://localhost:8080

# Run a pipeline
bash scripts/manage.sh run nightly-backup
```

## Core Capabilities

1. One-command installation — Detects OS/arch, downloads binary, sets up config
2. Template-based DAG creation — Backup, deploy, ETL, monitoring, cron templates
3. Dependency chains — Steps run in order with explicit depends declarations
4. Parallel execution — Independent steps run simultaneously
5. Retry policies — Per-step retry with configurable intervals
6. Cron scheduling — Standard cron expressions for recurring workflows
7. Web dashboard — Visual monitoring, manual triggers, execution history
8. Authentication — Optional basic auth for secure dashboard access
9. Systemd integration — Run as a persistent background service
10. DAG export/import — Backup and migrate your workflows easily

## Dependencies
- `bash` (4.0+)
- `curl` (for installation)
- `systemd` (optional, for service management)

## Installation Time
**5 minutes** — Run install script, create first DAG, start dashboard
