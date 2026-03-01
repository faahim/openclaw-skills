# Listing Copy: Loki Log Aggregator

## Metadata
- **Type:** Skill
- **Name:** loki-log-aggregator
- **Display Name:** Loki Log Aggregator
- **Categories:** [analytics, automation]
- **Price:** $15
- **Dependencies:** [bash, curl, unzip, systemctl]

## Tagline

"Centralized log aggregation with Grafana Loki — collect, query, and alert on all your logs"

## Description

Manually SSH-ing into servers to grep through scattered log files is painful. When something breaks at 2am, you need instant access to logs from every service — not a treasure hunt across `/var/log/`.

Loki Log Aggregator installs and configures Grafana Loki + Promtail on your server in under 10 minutes. Promtail ships systemd journals, application logs, and Docker container logs to Loki, where you can query everything with LogQL — a powerful query language similar to PromQL.

**What it does:**
- 📦 One-command install of Loki + Promtail (auto-detects amd64/arm64)
- 📋 Ships systemd, syslog, auth logs out of the box
- 🔍 Query with LogQL: `{job="nginx"} |= "error" | json | status >= 500`
- ➕ Add custom log sources (app logs, Docker, any file path)
- 🔔 Alert rules for error patterns (webhook/Alertmanager integration)
- 📊 Grafana integration for visual log exploration
- ⏰ Configurable retention (default 30 days, auto-compaction)
- 💾 Backup & restore support
- 🏗️ Multi-server ready (install Promtail-only on remote hosts)

**Why Loki over ELK?** Loki indexes labels only (not full text), using 10-100x less storage than Elasticsearch. Perfect for single servers or small clusters.

Perfect for developers, sysadmins, and homelab enthusiasts who want centralized logging without the complexity of ELK/Elasticsearch.

## Quick Start Preview

```bash
# Install Loki + Promtail
bash scripts/install.sh

# Start services
bash scripts/manage.sh start loki
bash scripts/manage.sh start promtail

# Query logs
bash scripts/query.sh '{job="systemd"} |= "error"' --since 1h
```

## Core Capabilities

1. Automated binary installation — Downloads correct Loki/Promtail for your architecture
2. Systemd service management — Start, stop, restart, status with one command
3. LogQL querying — Full query language with filtering, parsing, aggregation
4. Real-time log tailing — Stream matching logs as they arrive
5. Custom source management — Add app logs, Docker logs, any file path
6. Alert rules — Trigger on log patterns exceeding thresholds
7. Retention management — Set log TTL, auto-compaction, storage monitoring
8. Grafana integration — One-command datasource setup
9. Backup & restore — Protect log history
10. Multi-server support — Central Loki with remote Promtail agents
11. Lightweight — 10-100x less storage than ELK stack
12. Uninstall — Clean removal of all components

## Dependencies
- `bash` (4.0+)
- `curl`
- `unzip`
- `systemctl` (Linux with systemd)
- Optional: `jq` (prettier output)
- Optional: `grafana` (visual exploration)

## Installation Time
**10 minutes** — Run install script, start services, query logs

## Pricing Justification

**Why $15:**
- Comparable services: Datadog Logs ($0.10/GB/mo), Papertrail ($7/mo minimum)
- Self-hosted alternative: ELK stack requires 4+ hours setup
- Our advantage: 10-minute install, zero monthly costs, OpenClaw-native management
- Complexity: Medium-High (binary management, systemd, config generation, API querying)
