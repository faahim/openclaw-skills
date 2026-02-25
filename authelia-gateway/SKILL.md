---
name: authelia-gateway
description: >-
  Install and configure Authelia as an authentication gateway for self-hosted services.
  Adds SSO, 2FA, and access control policies to any reverse proxy setup.
categories: [security, automation]
dependencies: [docker, docker-compose]
---

# Authelia Authentication Gateway

## What This Does

Authelia is a powerful authentication and authorization server that sits in front of your self-hosted services, providing Single Sign-On (SSO), two-factor authentication (TOTP, WebAuthn, Duo), and fine-grained access control policies. This skill installs, configures, and manages Authelia with Docker Compose, integrating with Nginx or Traefik as a reverse proxy companion.

**Example:** "Protect Gitea, Grafana, and Jellyfin behind a single login page with 2FA — no more exposing services to the internet unprotected."

## Quick Start (10 minutes)

### 1. Prerequisites

```bash
# Ensure Docker and Docker Compose are installed
docker --version && docker compose version

# If not installed:
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### 2. Generate Configuration

```bash
# Run the setup script — generates config, secrets, and docker-compose.yml
bash scripts/setup.sh --domain auth.example.com --email admin@example.com
```

This creates:
```
authelia-data/
├── configuration.yml    # Main Authelia config
├── users_database.yml   # User accounts (argon2id hashed)
├── docker-compose.yml   # Authelia + Redis
└── secrets/
    ├── jwt_secret
    ├── session_secret
    ├── storage_encryption_key
    └── smtp_password
```

### 3. Add Your First User

```bash
bash scripts/manage-users.sh add --username admin --email admin@example.com
# You'll be prompted for a password (hashed with argon2id)
```

### 4. Start Authelia

```bash
cd authelia-data
docker compose up -d

# Check status
docker compose logs -f authelia
```

### 5. Configure Your Reverse Proxy

#### Nginx

Add to your server block:

```nginx
# Authentication endpoint
location /authelia {
    internal;
    set $upstream_authelia http://127.0.0.1:9091/api/verify;
    proxy_pass $upstream_authelia;
    proxy_set_header X-Original-URL $scheme://$http_host$request_uri;
    proxy_set_header X-Forwarded-Method $request_method;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-URI $request_uri;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header Content-Length "";
    proxy_set_header Connection "";
}

# Authelia portal
server {
    listen 443 ssl;
    server_name auth.example.com;

    location / {
        proxy_pass http://127.0.0.1:9091;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Protected service example
server {
    listen 443 ssl;
    server_name gitea.example.com;

    location / {
        # Auth check
        auth_request /authelia;
        auth_request_set $target_url $scheme://$http_host$request_uri;
        auth_request_set $user $upstream_http_remote_user;
        auth_request_set $groups $upstream_http_remote_groups;
        auth_request_set $name $upstream_http_remote_name;
        auth_request_set $email $upstream_http_remote_email;
        error_page 401 =302 https://auth.example.com/?rd=$target_url;

        # Pass user info to backend
        proxy_set_header Remote-User $user;
        proxy_set_header Remote-Groups $groups;
        proxy_set_header Remote-Name $name;
        proxy_set_header Remote-Email $email;

        proxy_pass http://127.0.0.1:3000;
    }
}
```

#### Traefik (docker-compose labels)

```yaml
labels:
  - "traefik.http.middlewares.authelia.forwardAuth.address=http://authelia:9091/api/verify?rd=https://auth.example.com"
  - "traefik.http.middlewares.authelia.forwardAuth.trustForwardHeader=true"
  - "traefik.http.middlewares.authelia.forwardAuth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
  # Apply to a service:
  - "traefik.http.routers.myservice.middlewares=authelia@docker"
```

## Core Workflows

### Workflow 1: Protect a Service with 2FA

**Use case:** Require TOTP 2FA for accessing a sensitive service (e.g., admin panel)

Edit `authelia-data/configuration.yml` access control:

```yaml
access_control:
  default_policy: deny
  rules:
    # Admin panel requires 2FA
    - domain: admin.example.com
      policy: two_factor

    # Internal tools just need login
    - domain: "*.internal.example.com"
      policy: one_factor

    # Public services bypass auth
    - domain: public.example.com
      policy: bypass
```

```bash
# Restart to apply
cd authelia-data && docker compose restart authelia
```

### Workflow 2: Add/Remove Users

```bash
# Add user
bash scripts/manage-users.sh add --username alice --email alice@example.com --groups admins,devs

# Remove user
bash scripts/manage-users.sh remove --username alice

# Reset password
bash scripts/manage-users.sh reset-password --username alice

# List users
bash scripts/manage-users.sh list
```

### Workflow 3: Configure Email Notifications

```bash
# Set SMTP credentials for password reset emails and 2FA notifications
bash scripts/configure-smtp.sh \
  --host smtp.gmail.com \
  --port 587 \
  --username you@gmail.com \
  --from "Authelia <auth@example.com>"
# You'll be prompted for the app password
```

### Workflow 4: Set Up WebAuthn (Hardware Keys)

Edit `authelia-data/configuration.yml`:

```yaml
webauthn:
  disable: false
  display_name: Authelia
  attestation_conveyance_preference: indirect
  user_verification: preferred
  timeout: 60s
```

Users can then register hardware keys (YubiKey, etc.) from the Authelia web portal.

### Workflow 5: Monitor Auth Events

```bash
# View recent auth attempts
bash scripts/auth-logs.sh --tail 50

# Filter failed logins (potential attacks)
bash scripts/auth-logs.sh --failed --since "1 hour ago"

# Export auth log summary
bash scripts/auth-logs.sh --summary --date today
```

## Configuration

### Access Control Policies

```yaml
# configuration.yml — access_control section
access_control:
  default_policy: deny  # deny | one_factor | two_factor | bypass

  rules:
    # By domain
    - domain: app.example.com
      policy: one_factor

    # By domain + path
    - domain: app.example.com
      resources:
        - "^/api/.*$"
      policy: two_factor

    # By user/group
    - domain: admin.example.com
      subject:
        - "group:admins"
      policy: two_factor

    # By IP network (bypass for local)
    - domain: "*.example.com"
      networks:
        - 192.168.1.0/24
        - 10.0.0.0/8
      policy: bypass

    # Multiple domains with wildcard
    - domain:
        - "*.internal.example.com"
        - "dashboard.example.com"
      policy: one_factor
```

### Session Configuration

```yaml
session:
  name: authelia_session
  domain: example.com     # Cookie domain (parent of all protected services)
  expiration: 3600         # 1 hour
  inactivity: 300          # 5 min idle timeout
  remember_me_duration: 1M # "Remember me" lasts 1 month
```

### Storage Backend

```yaml
# SQLite (default, good for small setups)
storage:
  local:
    path: /config/db.sqlite3

# PostgreSQL (recommended for production)
storage:
  postgres:
    host: postgres
    port: 5432
    database: authelia
    username: authelia
    password: your-password
```

### Environment Variables

```bash
# Required secrets (auto-generated by setup.sh)
AUTHELIA_JWT_SECRET=<random-64-char>
AUTHELIA_SESSION_SECRET=<random-64-char>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<random-64-char>

# SMTP (for password resets)
AUTHELIA_NOTIFIER_SMTP_PASSWORD=<app-password>

# Domain
AUTHELIA_DOMAIN=auth.example.com
```

## Advanced Usage

### High Availability with PostgreSQL + Redis

```bash
bash scripts/setup.sh \
  --domain auth.example.com \
  --email admin@example.com \
  --storage postgres \
  --postgres-host db.example.com \
  --redis-host redis.example.com
```

### Integrate with LDAP/Active Directory

Edit `configuration.yml`:

```yaml
authentication_backend:
  ldap:
    url: ldap://ldap.example.com
    base_dn: dc=example,dc=com
    username_attribute: uid
    additional_users_dn: ou=users
    additional_groups_dn: ou=groups
    users_filter: "(&({username_attribute}={input})(objectClass=person))"
    groups_filter: "(&(member={dn})(objectClass=groupOfNames))"
    user: cn=admin,dc=example,dc=com
    password: your-ldap-password
```

### Backup and Restore

```bash
# Backup (config + database + secrets)
bash scripts/backup.sh --output /backups/authelia-$(date +%Y%m%d).tar.gz

# Restore
bash scripts/backup.sh --restore /backups/authelia-20260225.tar.gz
```

### Health Check Endpoint

```bash
# Check if Authelia is healthy
curl -s http://localhost:9091/api/health | jq .
# {"status":"OK"}
```

## Troubleshooting

### Issue: "Unable to connect to Redis"

**Fix:**
```bash
# Check Redis is running
docker compose ps redis
# Restart Redis
docker compose restart redis
```

### Issue: 502 Bad Gateway after auth

**Check:** Ensure the upstream service is reachable from the proxy. Test:
```bash
curl -I http://localhost:<service-port>
```

### Issue: Redirect loop after login

**Fix:** Ensure the `session.domain` in config matches your cookie domain:
```yaml
session:
  domain: example.com  # Must be the parent domain
```

### Issue: TOTP codes not working

**Check:** Time sync between server and client. Authelia allows ±1 period skew by default:
```yaml
totp:
  issuer: example.com
  period: 30
  skew: 1  # Allow 1 period before/after
```

### Issue: "Storage encryption key must be at least 20 characters"

**Fix:**
```bash
# Regenerate
openssl rand -hex 32 > authelia-data/secrets/storage_encryption_key
docker compose restart authelia
```

## Security Best Practices

1. **Always use HTTPS** — Authelia cookies require secure transport
2. **Use strong secrets** — setup.sh generates 64-char random secrets
3. **Enable 2FA for sensitive services** — Don't rely on passwords alone
4. **Restrict by IP when possible** — Bypass auth for trusted networks
5. **Monitor failed logins** — Use `auth-logs.sh --failed` regularly
6. **Backup regularly** — Include secrets directory in backups
7. **Keep updated** — `docker compose pull && docker compose up -d`

## Dependencies

- `docker` (20.10+)
- `docker-compose` (v2+)
- `openssl` (for secret generation)
- `argon2` or `docker` (for password hashing)
- Optional: `nginx` or `traefik` (reverse proxy)
