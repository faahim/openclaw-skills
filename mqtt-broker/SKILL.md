---
name: mqtt-broker
description: >-
  Install and manage a Mosquitto MQTT broker for IoT, home automation, and inter-service messaging.
categories: [home, automation]
dependencies: [mosquitto, mosquitto-clients, openssl]
---

# MQTT Broker Manager

## What This Does

Sets up, configures, and manages an Eclipse Mosquitto MQTT broker on your machine. MQTT is the backbone of IoT and home automation — sensors, smart devices, and services use it to communicate in real-time.

**Example:** "Install Mosquitto, create users with ACLs, enable TLS encryption, publish/subscribe to topics, monitor broker health."

## Quick Start (5 minutes)

### 1. Install Mosquitto

```bash
bash scripts/install.sh
```

This installs `mosquitto` and `mosquitto-clients`, enables the service, and starts the broker on port 1883.

### 2. Test It Works

```bash
# In one terminal — subscribe to a topic
mosquitto_sub -t "test/hello" &

# In another — publish a message
mosquitto_pub -t "test/hello" -m "MQTT is working!"

# You should see: MQTT is working!
```

### 3. Add Authentication

```bash
# Create a password file and add a user
bash scripts/manage-users.sh add myuser mypassword

# Restart broker to apply
sudo systemctl restart mosquitto
```

## Core Workflows

### Workflow 1: Set Up Authenticated Broker

**Use case:** Secure your broker so only authorized clients can connect.

```bash
# Add users
bash scripts/manage-users.sh add sensor1 s3cur3pass
bash scripts/manage-users.sh add dashboard d4shpass
bash scripts/manage-users.sh add publisher pubp4ss

# Enable password auth in config
bash scripts/configure.sh --auth

# Restart
sudo systemctl restart mosquitto

# Test with credentials
mosquitto_pub -t "home/temperature" -m "22.5" -u sensor1 -P s3cur3pass
mosquitto_sub -t "home/#" -u dashboard -P d4shpass
```

### Workflow 2: Enable TLS Encryption

**Use case:** Encrypt all MQTT traffic (required for internet-facing brokers).

```bash
# Generate self-signed CA + server certs
bash scripts/setup-tls.sh --domain mqtt.example.com

# This creates certs in /etc/mosquitto/certs/ and updates config
# Broker now listens on port 8883 (MQTTS)

sudo systemctl restart mosquitto

# Test TLS connection
mosquitto_pub -t "secure/test" -m "encrypted!" \
  --cafile /etc/mosquitto/certs/ca.crt \
  -p 8883 -u sensor1 -P s3cur3pass
```

### Workflow 3: Set Up Topic ACLs

**Use case:** Control who can read/write which topics.

```bash
# Create ACL file
bash scripts/configure.sh --acl

# Edit /etc/mosquitto/acl.conf:
# user sensor1
# topic write home/sensors/#
#
# user dashboard
# topic read home/#
#
# user admin
# topic readwrite #

sudo systemctl restart mosquitto
```

### Workflow 4: Monitor Broker Health

**Use case:** Check connected clients, message rates, uptime.

```bash
# Subscribe to broker system topics
mosquitto_sub -t '$SYS/#' -v -u admin -P adminpass | head -30

# Output includes:
# $SYS/broker/version mosquitto version 2.0.x
# $SYS/broker/uptime 12345 seconds
# $SYS/broker/clients/connected 3
# $SYS/broker/messages/received 1542
# $SYS/broker/messages/sent 3210
```

### Workflow 5: Bridge Two Brokers

**Use case:** Connect a local broker to a remote/cloud broker.

```bash
# Add bridge config
bash scripts/configure.sh --bridge \
  --remote-host cloud.example.com \
  --remote-port 8883 \
  --remote-user bridge_user \
  --remote-pass bridge_pass \
  --topics "home/# out 1"

sudo systemctl restart mosquitto
```

## Configuration

### Main Config File

Located at `/etc/mosquitto/mosquitto.conf`:

```conf
# Default listener
listener 1883
protocol mqtt

# Authentication
allow_anonymous false
password_file /etc/mosquitto/passwd

# ACL
acl_file /etc/mosquitto/acl.conf

# TLS listener (when enabled)
listener 8883
protocol mqtt
cafile /etc/mosquitto/certs/ca.crt
certfile /etc/mosquitto/certs/server.crt
keyfile /etc/mosquitto/certs/server.key

# Logging
log_dest file /var/log/mosquitto/mosquitto.log
log_type all

# Persistence
persistence true
persistence_location /var/lib/mosquitto/

# Limits
max_connections -1
max_queued_messages 1000
message_size_limit 0
```

### Environment Variables

```bash
# Default broker connection (for client tools)
export MQTT_HOST="localhost"
export MQTT_PORT="1883"
export MQTT_USER="admin"
export MQTT_PASS="your-password"
```

## Advanced Usage

### WebSocket Support

```bash
# Enable WebSocket listener (for browser MQTT clients)
bash scripts/configure.sh --websocket --ws-port 9001

# Browsers can now connect via ws://yourhost:9001
```

### Retain Messages

```bash
# Publish a retained message (new subscribers get it immediately)
mosquitto_pub -t "home/status" -m "online" -r -u admin -P adminpass

# Clear a retained message
mosquitto_pub -t "home/status" -m "" -r -u admin -P adminpass
```

### QoS Levels

```bash
# QoS 0: At most once (fire and forget)
mosquitto_pub -t "sensor/temp" -m "22.5" -q 0

# QoS 1: At least once (guaranteed delivery)
mosquitto_pub -t "alert/fire" -m "FIRE DETECTED" -q 1

# QoS 2: Exactly once (most reliable, highest overhead)
mosquitto_pub -t "payment/process" -m '{"amount":100}' -q 2
```

### Run as Docker Container

```bash
# Quick Docker setup
bash scripts/install.sh --docker

# This creates docker-compose.yml and starts Mosquitto in a container
# Config mounted from ./mosquitto/config/
# Data persisted in ./mosquitto/data/
```

## Troubleshooting

### Issue: "Connection refused"

**Fix:**
```bash
# Check if mosquitto is running
sudo systemctl status mosquitto

# Check if port is open
ss -tlnp | grep 1883

# Start if stopped
sudo systemctl start mosquitto
```

### Issue: "Not authorized" / "Connection refused: not authorised"

**Fix:**
```bash
# Check password file exists
ls -la /etc/mosquitto/passwd

# Verify credentials work
mosquitto_pub -t "test" -m "test" -u youruser -P yourpass -d

# Re-add user if needed
bash scripts/manage-users.sh add youruser yourpass
sudo systemctl restart mosquitto
```

### Issue: TLS handshake errors

**Fix:**
```bash
# Verify cert dates
openssl x509 -in /etc/mosquitto/certs/server.crt -noout -dates

# Check cert matches key
openssl x509 -in /etc/mosquitto/certs/server.crt -noout -modulus | md5sum
openssl rsa -in /etc/mosquitto/certs/server.key -noout -modulus | md5sum
# Both should match

# Regenerate if expired
bash scripts/setup-tls.sh --domain mqtt.example.com --force
```

### Issue: High memory usage

**Fix:**
```bash
# Limit queued messages in config
# max_queued_messages 100
# max_queued_bytes 1048576

# Limit message size
# message_size_limit 1048576

sudo systemctl restart mosquitto
```

## Integration with Home Assistant

```yaml
# In Home Assistant configuration.yaml
mqtt:
  broker: localhost
  port: 1883
  username: homeassistant
  password: ha_password
```

## Integration with Node-RED

```
MQTT Broker node:
  Server: localhost
  Port: 1883
  Username: nodered
  Password: nr_password
```

## Dependencies

- `mosquitto` (MQTT broker)
- `mosquitto-clients` (pub/sub CLI tools)
- `openssl` (for TLS certificate generation)
- Optional: `docker` + `docker-compose` (for containerized setup)

## Key Principles

1. **Secure by default** — Auth enabled after initial setup
2. **TLS ready** — One command to enable encrypted connections
3. **ACL support** — Fine-grained topic permissions per user
4. **Lightweight** — Mosquitto uses minimal resources (~2MB RAM idle)
5. **Persistent** — Messages survive broker restarts
