# Listing Copy: Grafana Dashboard Manager

## Metadata
- **Type:** Skill
- **Name:** grafana-manager
- **Display Name:** Grafana Dashboard Manager
- **Categories:** [analytics, dev-tools]
- **Price:** $12
- **Dependencies:** [bash, curl, jq]

## Tagline

Install and manage Grafana dashboards, data sources, and alerts from the terminal

## Description

Setting up monitoring dashboards shouldn't mean clicking through web UIs for an hour. Every new server, every new project — the same repetitive setup: install Grafana, add Prometheus, import the same 5 dashboards, configure alerts.

Grafana Dashboard Manager automates the entire workflow. Install Grafana OSS (Debian, RHEL, or Docker), add data sources (Prometheus, PostgreSQL, InfluxDB, MySQL), and import dashboards from Grafana.com — all with simple bash commands. Back up your dashboards, restore them on new servers, manage API keys and notification channels.

**What it does:**
- 🚀 One-command Grafana install (Debian/Ubuntu, RHEL/CentOS, Docker)
- 📊 Add/list/delete data sources (Prometheus, PostgreSQL, InfluxDB, MySQL)
- 📈 Import dashboards from Grafana.com by ID or from JSON files
- 💾 Backup and restore all dashboards in bulk
- 🔔 Set up notification channels (Telegram, Slack, webhooks)
- 🔑 Manage API keys for secure automation
- 🔍 Search and export dashboards

Perfect for developers, sysadmins, and DevOps engineers who manage multiple servers and want repeatable observability setups in minutes, not hours.

## Quick Start Preview

```bash
bash scripts/install.sh
bash scripts/datasource.sh add --name prom --type prometheus --url http://localhost:9090
bash scripts/dashboard.sh import --id 1860 --datasource prom
# ✅ Dashboard 'Node Exporter Full' imported
# 🔗 http://localhost:3000/d/rYdddlPWk
```

## Dependencies
- `bash` (4.0+)
- `curl`
- `jq`
- Docker (optional, for containerized install)
