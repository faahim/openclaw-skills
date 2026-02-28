---
name: tinyproxy-manager
description: >-
  Install, configure, and manage Tinyproxy — a lightweight HTTP/HTTPS forward proxy for traffic routing, access control, and request logging.
categories: [security, dev-tools]
dependencies: [bash, tinyproxy, curl]
---

# Tinyproxy Manager

## What This Does

Installs and manages [Tinyproxy](https://tinyproxy.github.io/), a lightweight HTTP/HTTPS forward proxy server. Use it to route agent traffic through a proxy, filter web access by domain, log HTTP requests, or provide proxy access to containers and local services.

**Example:** "Set up a forward proxy on port 8888, allow only local network, block ad domains, log all requests."

## Quick Start (3 minutes)

### 1. Install Tinyproxy

```bash
bash scripts/install.sh
```

This detects your OS (Debian/Ubuntu, RHEL/Fedora, Alpine, Arch) and installs tinyproxy.

### 2. Start with Defaults

```bash
bash scripts/run.sh start
# Proxy running on 127.0.0.1:8888
```

### 3. Test It

```bash
curl -x http://127.0.0.1:8888 https://httpbin.org/ip
# Returns your public IP — routed through tinyproxy
```

## Core Workflows

### Workflow 1: Basic Forward Proxy

**Use case:** Route HTTP/HTTPS traffic through a local proxy

```bash
# Start proxy on default port 8888
bash scripts/run.sh start

# Use it
export http_proxy=http://127.0.0.1:8888
export https_proxy=http://127.0.0.1:8888
curl https://example.com
```

### Workflow 2: Restricted Access Proxy

**Use case:** Allow only specific IPs/subnets to use the proxy

```bash
# Configure allowed networks
bash scripts/run.sh config --allow "192.168.1.0/24" --allow "10.0.0.0/8"

# Deny all others (default behavior)
bash scripts/run.sh restart
```

### Workflow 3: Domain Filtering

**Use case:** Block specific domains (ads, tracking, malware)

```bash
# Add domains to blocklist
bash scripts/run.sh block --domain "ads.example.com"
bash scripts/run.sh block --domain "tracking.example.com"

# Block from a list file
bash scripts/run.sh block --file blocklist.txt

# Reload config
bash scripts/run.sh reload
```

### Workflow 4: Request Logging & Analysis

**Use case:** Log all proxied requests for debugging or auditing

```bash
# Enable verbose logging
bash scripts/run.sh config --log-level Info

# View live logs
bash scripts/run.sh logs --follow

# Search logs for specific domain
bash scripts/run.sh logs --grep "api.example.com"

# Get request stats (top domains, request counts)
bash scripts/run.sh stats
```

### Workflow 5: Upstream Proxy Chaining

**Use case:** Chain tinyproxy to another upstream proxy (Tor, corporate proxy, VPN gateway)

```bash
# Route through upstream proxy
bash scripts/run.sh config --upstream "http://corporate-proxy.local:3128"

# Route through SOCKS proxy (via connect)
bash scripts/run.sh config --upstream-socks "127.0.0.1:9050"

bash scripts/run.sh restart
```

### Workflow 6: Container/Docker Proxy

**Use case:** Provide proxy access to Docker containers

```bash
# Bind to all interfaces (use with caution + access controls)
bash scripts/run.sh config --bind "0.0.0.0" --port 8888 --allow "172.17.0.0/16"

bash scripts/run.sh restart

# In Docker: docker run --env http_proxy=http://host.docker.internal:8888 ...
```

## Configuration

### Config via CLI

```bash
# Set port
bash scripts/run.sh config --port 8080

# Set bind address
bash scripts/run.sh config --bind "0.0.0.0"

# Set max connections
bash scripts/run.sh config --max-clients 200

# Set connection timeout (seconds)
bash scripts/run.sh config --timeout 600

# Add basic auth header
bash scripts/run.sh config --add-header "X-Proxy-Auth: mysecrettoken"

# Show current config
bash scripts/run.sh config --show
```

### Config File

Default location: `/etc/tinyproxy/tinyproxy.conf`

```bash
# Edit directly
bash scripts/run.sh edit

# Backup current config
bash scripts/run.sh config --backup

# Restore from backup
bash scripts/run.sh config --restore
```

### Environment Variables

```bash
# Override default port
export TINYPROXY_PORT=8888

# Override config path
export TINYPROXY_CONF="/etc/tinyproxy/tinyproxy.conf"

# Override log path
export TINYPROXY_LOG="/var/log/tinyproxy/tinyproxy.log"
```

## Advanced Usage

### Run as Systemd Service

```bash
# Enable auto-start on boot
bash scripts/run.sh enable

# Disable auto-start
bash scripts/run.sh disable

# Check service status
bash scripts/run.sh status
```

### Run in Foreground (for containers/debugging)

```bash
bash scripts/run.sh foreground
```

### Access Control Lists

```bash
# Allow specific IP
bash scripts/run.sh allow --ip "192.168.1.100"

# Allow subnet
bash scripts/run.sh allow --subnet "10.0.0.0/8"

# Remove allow rule
bash scripts/run.sh deny --ip "192.168.1.100"

# List current ACLs
bash scripts/run.sh acl --list
```

### Anonymous Proxy Headers

```bash
# Strip identifying headers (X-Forwarded-For, Via, etc.)
bash scripts/run.sh config --anonymous

# Restore normal headers
bash scripts/run.sh config --no-anonymous
```

### Health Check

```bash
# Check if proxy is running and responsive
bash scripts/run.sh health

# Output:
# ✅ Tinyproxy is running (PID 12345)
# ✅ Listening on 127.0.0.1:8888
# ✅ Proxy test passed (200 OK via proxy)
# 📊 Uptime: 3d 12h 45m | Connections: 1,234 | Active: 2
```

## Troubleshooting

### Issue: "Connection refused" when using proxy

**Check:**
1. Is tinyproxy running? `bash scripts/run.sh status`
2. Correct port? `bash scripts/run.sh config --show | grep Port`
3. Is your IP allowed? `bash scripts/run.sh acl --list`

### Issue: "Access denied" for specific client

**Fix:**
```bash
bash scripts/run.sh allow --ip "CLIENT_IP_HERE"
bash scripts/run.sh reload
```

### Issue: HTTPS sites not working through proxy

**Note:** Tinyproxy handles HTTPS via CONNECT tunneling. It does NOT decrypt HTTPS traffic (this is correct and secure behavior). If HTTPS is failing:
```bash
# Ensure ConnectPort includes 443
bash scripts/run.sh config --connect-port 443
bash scripts/run.sh reload
```

### Issue: Slow proxy performance

**Fix:**
```bash
# Increase max clients
bash scripts/run.sh config --max-clients 500

# Reduce timeout for idle connections
bash scripts/run.sh config --timeout 300

bash scripts/run.sh restart
```

## Uninstall

```bash
bash scripts/install.sh --uninstall
# Stops service, removes config, optionally removes tinyproxy package
```

## Key Principles

1. **Lightweight** — Tinyproxy uses ~2MB RAM (vs Squid's 50-200MB)
2. **Secure by default** — Only localhost allowed, no open proxy
3. **Config-driven** — All changes via CLI or config file, auto-backup
4. **Non-destructive** — Backs up config before changes, easy rollback
5. **Transparent** — Logs everything, easy to audit
