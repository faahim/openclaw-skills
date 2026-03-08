---
name: stunnel-tls-wrapper
description: >-
  Wrap any plain TCP service in TLS encryption using stunnel. Secure Redis, MySQL, SMTP, and more without modifying the application.
categories: [security, automation]
dependencies: [stunnel, openssl]
---

# Stunnel TLS Wrapper

## What This Does

Wraps plain-text TCP services in TLS encryption using [stunnel](https://www.stunnel.org/). Secure legacy services (Redis, MySQL, SMTP, databases, custom TCP apps) without changing application code. Generates self-signed or Let's Encrypt certs, manages multiple tunnels, and monitors tunnel health.

**Example:** "Encrypt Redis traffic between your app server and database server — zero code changes."

## Quick Start (5 minutes)

### 1. Install Stunnel

```bash
bash scripts/install.sh
```

### 2. Create a TLS Tunnel

```bash
# Wrap local Redis (port 6379) with TLS on port 6380
bash scripts/tunnel.sh create \
  --name redis-tls \
  --accept 6380 \
  --connect 127.0.0.1:6379 \
  --mode server \
  --cert auto
```

Output:
```
✅ Generated self-signed certificate: /etc/stunnel/certs/redis-tls.pem
✅ Tunnel 'redis-tls' created: TLS:6380 → TCP:127.0.0.1:6379
✅ Stunnel config written: /etc/stunnel/conf.d/redis-tls.conf
✅ Service started and enabled
```

### 3. Verify It Works

```bash
bash scripts/tunnel.sh status
```

Output:
```
TUNNEL          MODE    ACCEPT  CONNECT           STATUS   PID    UPTIME
redis-tls       server  6380    127.0.0.1:6379    ✅ UP    12345  2m
```

## Core Workflows

### Workflow 1: Secure Redis

**Server side** (where Redis runs):
```bash
bash scripts/tunnel.sh create \
  --name redis-server \
  --accept 0.0.0.0:6380 \
  --connect 127.0.0.1:6379 \
  --mode server \
  --cert /path/to/server.pem
```

**Client side** (app connecting to Redis):
```bash
bash scripts/tunnel.sh create \
  --name redis-client \
  --accept 127.0.0.1:6379 \
  --connect redis-server.example.com:6380 \
  --mode client \
  --ca /path/to/ca.pem
```

Now your app connects to `localhost:6379` as usual — traffic is encrypted in transit.

### Workflow 2: Secure MySQL Replication

```bash
# On primary
bash scripts/tunnel.sh create \
  --name mysql-primary \
  --accept 0.0.0.0:3307 \
  --connect 127.0.0.1:3306 \
  --mode server \
  --cert auto

# On replica
bash scripts/tunnel.sh create \
  --name mysql-replica \
  --accept 127.0.0.1:3306 \
  --connect primary.example.com:3307 \
  --mode client \
  --verify 2
```

### Workflow 3: TLS Proxy for SMTP

```bash
# Accept SMTPS on 465, forward to local Postfix on 25
bash scripts/tunnel.sh create \
  --name smtps-proxy \
  --accept 0.0.0.0:465 \
  --connect 127.0.0.1:25 \
  --mode server \
  --cert /etc/letsencrypt/live/mail.example.com/fullchain.pem \
  --key /etc/letsencrypt/live/mail.example.com/privkey.pem
```

### Workflow 4: Secure Any TCP Service

```bash
# Generic: wrap any TCP port
bash scripts/tunnel.sh create \
  --name myapp-tls \
  --accept 0.0.0.0:8443 \
  --connect 127.0.0.1:8080 \
  --mode server \
  --cert auto
```

## Certificate Management

### Auto-Generate Self-Signed Certs

```bash
# Creates cert valid for 365 days
bash scripts/certs.sh generate \
  --name myservice \
  --cn myservice.example.com \
  --days 365
```

Output:
```
✅ Generated: /etc/stunnel/certs/myservice.pem (cert+key)
✅ CA cert:   /etc/stunnel/certs/myservice-ca.pem
   Expires:  2027-03-08
```

### Use Let's Encrypt Certs

```bash
bash scripts/tunnel.sh create \
  --name web-tls \
  --accept 443 \
  --connect 127.0.0.1:8080 \
  --mode server \
  --cert /etc/letsencrypt/live/example.com/fullchain.pem \
  --key /etc/letsencrypt/live/example.com/privkey.pem
```

### Check Certificate Expiry

```bash
bash scripts/certs.sh check-expiry

# Output:
# CERTIFICATE                EXPIRES         DAYS LEFT  STATUS
# redis-tls.pem              2027-03-08      365        ✅ OK
# mysql-primary.pem          2026-04-15      38         ⚠️  EXPIRING SOON
# smtps-proxy.pem            2026-03-15      7          🔴 CRITICAL
```

### Auto-Renew Self-Signed Certs

```bash
# Renew certs expiring within 30 days
bash scripts/certs.sh renew --threshold 30

# Add to crontab for automatic renewal
bash scripts/certs.sh install-cron --threshold 30
```

## Tunnel Management

### List All Tunnels

```bash
bash scripts/tunnel.sh list
```

### Stop/Start/Restart a Tunnel

```bash
bash scripts/tunnel.sh stop redis-tls
bash scripts/tunnel.sh start redis-tls
bash scripts/tunnel.sh restart redis-tls
```

### Remove a Tunnel

```bash
bash scripts/tunnel.sh remove redis-tls
```

### Monitor Health

```bash
bash scripts/tunnel.sh health

# Output:
# TUNNEL          STATUS   CONNECTIONS  BYTES IN     BYTES OUT    ERRORS
# redis-tls       ✅ UP    42           1.2 MB       856 KB       0
# mysql-primary   ✅ UP    3            45.6 MB      12.3 MB      0
# smtps-proxy     ❌ DOWN  0            -            -            cert expired
```

## Configuration

### Environment Variables

```bash
# Certificate directory
export STUNNEL_CERT_DIR="/etc/stunnel/certs"

# Config directory
export STUNNEL_CONF_DIR="/etc/stunnel/conf.d"

# Log level (0=emergency, 7=debug)
export STUNNEL_LOG_LEVEL="5"

# Alert on cert expiry (days)
export STUNNEL_CERT_WARN_DAYS="30"
```

### Global stunnel.conf

The installer creates `/etc/stunnel/stunnel.conf`:

```ini
; Global options
pid = /var/run/stunnel.pid
setuid = stunnel4
setgid = stunnel4

; Logging
output = /var/log/stunnel.log
debug = 5

; Include per-tunnel configs
include = /etc/stunnel/conf.d
```

### Per-Tunnel Config

Each tunnel gets its own file in `/etc/stunnel/conf.d/`:

```ini
; /etc/stunnel/conf.d/redis-tls.conf
[redis-tls]
client = no
accept = 6380
connect = 127.0.0.1:6379
cert = /etc/stunnel/certs/redis-tls.pem
```

## Advanced Usage

### Mutual TLS (mTLS)

```bash
# Server requires client certificate
bash scripts/tunnel.sh create \
  --name secure-api \
  --accept 0.0.0.0:8443 \
  --connect 127.0.0.1:8080 \
  --mode server \
  --cert /path/to/server.pem \
  --verify 2 \
  --ca /path/to/client-ca.pem
```

### Protocol-Specific Options

```bash
# STARTTLS for SMTP
bash scripts/tunnel.sh create \
  --name smtp-starttls \
  --accept 0.0.0.0:587 \
  --connect 127.0.0.1:25 \
  --mode server \
  --cert auto \
  --protocol smtp
```

### Load Balancing (Round-Robin)

```bash
# Distribute to multiple backends
bash scripts/tunnel.sh create \
  --name lb-app \
  --accept 0.0.0.0:443 \
  --connect 10.0.0.1:8080 \
  --connect 10.0.0.2:8080 \
  --connect 10.0.0.3:8080 \
  --mode server \
  --cert auto
```

## Troubleshooting

### Issue: "stunnel: command not found"

**Fix:**
```bash
bash scripts/install.sh
```

### Issue: "Could not bind to port"

**Fix:** Port already in use. Check with:
```bash
ss -tlnp | grep <port>
```

### Issue: Certificate verification failed

**Fix:**
1. Check cert path: `openssl x509 -in /path/to/cert.pem -noout -text`
2. Verify CA chain: `openssl verify -CAfile ca.pem cert.pem`
3. Check expiry: `bash scripts/certs.sh check-expiry`

### Issue: Connection refused on client side

**Fix:**
1. Verify server tunnel is running: `bash scripts/tunnel.sh status`
2. Check firewall allows the accept port
3. Test with: `openssl s_client -connect server:port`

## Dependencies

- `stunnel` (4.x or 5.x)
- `openssl` (certificate generation)
- `bash` (4.0+)
- `systemctl` (service management, optional)
