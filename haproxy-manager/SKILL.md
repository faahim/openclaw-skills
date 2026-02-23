---
name: haproxy-manager
description: >-
  Install, configure, and manage HAProxy load balancer with health checks, SSL termination, and real-time stats.
categories: [dev-tools, automation]
dependencies: [haproxy, bash, curl, openssl]
---

# HAProxy Load Balancer Manager

## What This Does

Installs and configures HAProxy as a reverse proxy and load balancer for your services. Handles backend health checks, SSL termination, round-robin/least-connections balancing, and exposes a real-time stats dashboard. No manual config file editing — scripts handle everything.

**Example:** "Balance traffic across 3 app servers, auto-remove unhealthy ones, serve HTTPS, monitor via stats page."

## Quick Start (5 minutes)

### 1. Install HAProxy

```bash
bash scripts/install.sh
```

This detects your OS (Debian/Ubuntu/RHEL/Alpine) and installs HAProxy 2.x+.

### 2. Add Your First Backend

```bash
bash scripts/manage.sh add-backend \
  --name myapp \
  --servers "10.0.0.1:8080,10.0.0.2:8080,10.0.0.3:8080" \
  --port 80 \
  --balance roundrobin
```

### 3. Enable & Start

```bash
bash scripts/manage.sh apply
sudo systemctl restart haproxy
```

### 4. Check Status

```bash
bash scripts/manage.sh status
# Or visit http://localhost:9090/stats (admin/admin by default)
```

## Core Workflows

### Workflow 1: HTTP Load Balancer

Balance HTTP traffic across multiple app servers.

```bash
bash scripts/manage.sh add-backend \
  --name webapp \
  --servers "app1.local:3000,app2.local:3000" \
  --port 80 \
  --balance roundrobin \
  --health-check "/healthz" \
  --health-interval 5
```

Output:
```
✅ Backend 'webapp' added
   Frontend: *:80 → webapp (2 servers, roundrobin)
   Health check: GET /healthz every 5s
   Run 'bash scripts/manage.sh apply' to activate
```

### Workflow 2: HTTPS with SSL Termination

Terminate SSL at HAProxy, forward plain HTTP to backends.

```bash
# Generate or provide SSL cert
bash scripts/manage.sh add-backend \
  --name secure-app \
  --servers "app1:8080,app2:8080" \
  --port 443 \
  --ssl-cert /etc/ssl/certs/mysite.pem \
  --ssl-key /etc/ssl/private/mysite.key \
  --redirect-http
```

This creates:
- HTTPS frontend on port 443
- HTTP→HTTPS redirect on port 80
- Combined PEM for HAProxy

### Workflow 3: TCP Load Balancer (Database, Redis, etc.)

Balance TCP connections (non-HTTP).

```bash
bash scripts/manage.sh add-backend \
  --name postgres \
  --mode tcp \
  --servers "db1:5432,db2:5432" \
  --port 5432 \
  --balance leastconn \
  --health-check-tcp
```

### Workflow 4: Sticky Sessions

Route same client to same backend (useful for stateful apps).

```bash
bash scripts/manage.sh add-backend \
  --name stateful-app \
  --servers "app1:8080,app2:8080" \
  --port 80 \
  --balance roundrobin \
  --sticky cookie SERVERID insert indirect nocache
```

### Workflow 5: Rate Limiting

Limit requests per IP to prevent abuse.

```bash
bash scripts/manage.sh add-backend \
  --name api \
  --servers "api1:8080,api2:8080" \
  --port 80 \
  --rate-limit 100/10s
```

### Workflow 6: Real-Time Stats Dashboard

```bash
bash scripts/manage.sh enable-stats \
  --port 9090 \
  --user admin \
  --pass "$(openssl rand -hex 12)"
```

Visit `http://your-server:9090/stats` for live metrics:
- Requests/sec per backend
- Response times
- Server health status
- Connection counts

### Workflow 7: Add/Remove Servers (Zero Downtime)

```bash
# Add a server to existing backend
bash scripts/manage.sh add-server --backend webapp --server app3.local:3000

# Remove a server (drains connections first)
bash scripts/manage.sh drain-server --backend webapp --server app1.local:3000

# Apply changes
bash scripts/manage.sh apply
sudo systemctl reload haproxy
```

### Workflow 8: Check Backend Health

```bash
bash scripts/manage.sh health

# Output:
# Backend: webapp
#   ✅ app1.local:3000 — UP (2ms, 1523 req)
#   ✅ app2.local:3000 — UP (3ms, 1521 req)
#   ❌ app3.local:3000 — DOWN (timeout, 0 req since 13:45)
#
# Backend: postgres
#   ✅ db1:5432 — UP (1ms)
#   ✅ db2:5432 — UP (1ms)
```

## Configuration

### Config File

HAProxy config is generated at `/etc/haproxy/haproxy.cfg`. The manage script maintains a JSON state file at `~/.haproxy-manager/state.json` and generates the HAProxy config from it.

### Environment Variables

```bash
# Override config location
export HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"

# Override state file location
export HAPROXY_STATE="$HOME/.haproxy-manager/state.json"

# Stats dashboard credentials
export HAPROXY_STATS_USER="admin"
export HAPROXY_STATS_PASS="secretpass"
```

## Advanced Usage

### Custom HAProxy Directives

```bash
# Add raw HAProxy config to a backend
bash scripts/manage.sh raw-config --backend webapp \
  --directive 'option httpchk GET /healthz HTTP/1.1\r\nHost:\ localhost'
```

### ACL-Based Routing

```bash
# Route by hostname
bash scripts/manage.sh add-acl \
  --frontend main \
  --acl "host_api hdr(host) -i api.example.com" \
  --use-backend api-servers

bash scripts/manage.sh add-acl \
  --frontend main \
  --acl "host_web hdr(host) -i www.example.com" \
  --use-backend web-servers
```

### Backup Config

```bash
bash scripts/manage.sh backup
# Saves timestamped backup to ~/.haproxy-manager/backups/
```

### Validate Config

```bash
bash scripts/manage.sh validate
# Runs haproxy -c -f /etc/haproxy/haproxy.cfg
```

## Troubleshooting

### Issue: "haproxy: command not found"

```bash
bash scripts/install.sh
```

### Issue: Port already in use

```bash
# Check what's using the port
sudo ss -tlnp | grep :80
# Kill or reconfigure the conflicting service
```

### Issue: SSL errors

```bash
# Verify cert + key match
bash scripts/manage.sh check-ssl --cert /path/to/cert.pem --key /path/to/key.pem
```

### Issue: Backend shows DOWN but server is running

Check:
1. Health check path exists: `curl http://backend:port/healthz`
2. Firewall allows HAProxy → backend traffic
3. Health check interval isn't too aggressive

## Dependencies

- `haproxy` (2.0+) — installed by `scripts/install.sh`
- `bash` (4.0+)
- `curl` (for health checks)
- `openssl` (for SSL operations)
- `jq` (for state management)
- `socat` (optional, for runtime socket commands)
