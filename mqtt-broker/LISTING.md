# Listing Copy: MQTT Broker Manager

## Metadata
- **Type:** Skill
- **Name:** mqtt-broker
- **Display Name:** MQTT Broker Manager
- **Categories:** [home, automation]
- **Price:** $12
- **Dependencies:** [mosquitto, mosquitto-clients, openssl]

## Tagline

"Install and manage a Mosquitto MQTT broker — IoT and home automation messaging in minutes"

## Description

Setting up an MQTT broker shouldn't require reading 50 pages of documentation. Whether you're connecting IoT sensors, building smart home automations, or wiring microservices together, you need a reliable message broker — fast.

MQTT Broker Manager installs Eclipse Mosquitto, configures authentication, generates TLS certificates, and sets up topic-level access control — all through simple scripts your OpenClaw agent can run. No manual config file editing, no certificate headaches.

**What it does:**
- 📦 One-command install (apt/yum/brew/Docker)
- 🔐 User management with password authentication
- 🔒 TLS encryption with auto-generated certificates
- 📋 Topic ACLs — fine-grained per-user permissions
- 🌐 WebSocket support for browser-based MQTT clients
- 🌉 Broker bridging — connect local to cloud
- 📊 Health monitoring via $SYS topics
- 🐳 Docker deployment option

Perfect for developers building IoT projects, home automation enthusiasts running Home Assistant or Node-RED, and anyone who needs lightweight pub/sub messaging.

## Quick Start Preview

```bash
# Install broker
bash scripts/install.sh

# Add a user
bash scripts/manage-users.sh add myuser mypass

# Enable auth + TLS
bash scripts/configure.sh --auth
bash scripts/setup-tls.sh --domain mqtt.myhost.com

# Publish/subscribe
mosquitto_pub -t "home/temp" -m "22.5" -u myuser -P mypass
mosquitto_sub -t "home/#" -u myuser -P mypass
```

## Core Capabilities

1. Automated Mosquitto installation — Detects OS, installs correct packages
2. User management — Add, remove, list MQTT users via CLI
3. TLS certificate generation — Self-signed CA + server certs with SAN support
4. Authentication enforcement — Toggle anonymous vs password-based access
5. Topic ACLs — Per-user read/write/deny rules on topic patterns
6. WebSocket listener — Enable browser MQTT clients on configurable port
7. Broker bridging — Connect local broker to remote/cloud instances
8. Docker support — docker-compose deployment with persistent volumes
9. Health monitoring — Built-in $SYS topic monitoring for broker stats
10. Home Assistant / Node-RED ready — Drop-in integration configs

## Dependencies
- `mosquitto` (2.0+)
- `mosquitto-clients`
- `openssl`
- Optional: `docker` + `docker-compose`

## Installation Time
**5 minutes** — Install, add user, start publishing
