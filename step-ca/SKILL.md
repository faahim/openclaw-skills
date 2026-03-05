---
name: step-ca
description: >-
  Run a private Certificate Authority with Smallstep step-ca. Issue and auto-renew TLS certificates for internal services.
categories: [security, dev-tools]
dependencies: [step-cli, step-ca]
---

# Step-CA — Private Certificate Authority

## What This Does

Run your own private Certificate Authority (CA) using Smallstep's `step-ca`. Issue TLS certificates for internal services, homelab domains, dev environments, and mTLS authentication — no public CA needed, no per-cert costs, full control.

**Example:** "Set up a private CA, issue certs for `*.internal.lan`, auto-renew them, and configure HTTPS on all your internal services."

## Quick Start (10 minutes)

### 1. Install Step CLI & Step-CA

```bash
# Detect OS and install
bash scripts/install.sh
```

### 2. Initialize Your CA

```bash
# Create a new CA with defaults
bash scripts/setup-ca.sh --name "My Private CA" --dns localhost --address :8443

# This creates:
#   ~/.step/config/ca.json     — CA configuration
#   ~/.step/certs/root_ca.crt  — Root certificate (distribute to clients)
#   ~/.step/secrets/            — CA private keys (keep secure!)
```

### 3. Start the CA Server

```bash
# Start step-ca in the background
bash scripts/manage.sh start

# Check status
bash scripts/manage.sh status
# Output: ✅ step-ca running on :8443 (PID 12345)
```

### 4. Issue Your First Certificate

```bash
# Issue a cert for a service
bash scripts/cert.sh issue myapp.internal.lan

# Output:
# ✅ Certificate issued:
#   cert: certs/myapp.internal.lan.crt
#   key:  certs/myapp.internal.lan.key
#   expires: 2026-03-06T19:53:00Z (24h default)
```

## Core Workflows

### Workflow 1: Issue Certificates for Internal Services

**Use case:** HTTPS for services on your local network

```bash
# Issue cert for a single domain
bash scripts/cert.sh issue grafana.home.lan

# Issue cert with multiple SANs
bash scripts/cert.sh issue api.internal --san "api.internal.lan" --san "10.0.1.50"

# Issue wildcard cert
bash scripts/cert.sh issue "*.home.lan"
```

### Workflow 2: Auto-Renew Certificates

**Use case:** Never let internal certs expire

```bash
# Set up auto-renewal for a certificate (uses step-ca ACME or cron)
bash scripts/cert.sh renew myapp.internal.lan

# This adds a cron job:
# */12 * * * * step ca renew --force certs/myapp.internal.lan.crt certs/myapp.internal.lan.key
```

**Output on renewal:**
```
[2026-03-05 08:00:00] 🔄 Renewing myapp.internal.lan
[2026-03-05 08:00:01] ✅ Renewed — expires 2026-03-07T08:00:01Z
```

### Workflow 3: ACME Protocol (Let's Encrypt Style)

**Use case:** Use standard ACME clients (certbot, Caddy, Traefik) with your private CA

```bash
# Enable ACME provisioner
bash scripts/setup-ca.sh --enable-acme

# Now any ACME client can request certs from your CA:
# Caddy example:
#   tls {
#     ca https://ca.internal.lan:8443/acme/acme/directory
#     ca_root /path/to/root_ca.crt
#   }

# Certbot example:
# certbot certonly --server https://ca.internal.lan:8443/acme/acme/directory \
#   --standalone -d myapp.internal.lan
```

### Workflow 4: mTLS (Mutual TLS)

**Use case:** Authenticate clients with certificates

```bash
# Issue client certificate
bash scripts/cert.sh issue-client "worker-01"

# Output:
# ✅ Client certificate issued:
#   cert: certs/clients/worker-01.crt
#   key:  certs/clients/worker-01.key

# Verify a client cert
bash scripts/cert.sh verify certs/clients/worker-01.crt
# ✅ Valid — issued by "My Private CA", expires 2026-03-06
```

### Workflow 5: Trust the CA System-Wide

**Use case:** Make all apps trust your private CA

```bash
# Install root cert into system trust store
bash scripts/trust.sh install

# Linux: copies to /usr/local/share/ca-certificates/ + update-ca-certificates
# macOS: adds to System Keychain
# Output: ✅ Root CA trusted system-wide. Restart browsers to take effect.

# Remove trust
bash scripts/trust.sh remove
```

### Workflow 6: Manage as Systemd Service

```bash
# Install as systemd service (Linux)
bash scripts/manage.sh install-service

# Now use standard systemd commands:
# systemctl start step-ca
# systemctl enable step-ca  (start on boot)
# systemctl status step-ca
```

## Configuration

### CA Config (~/.step/config/ca.json)

```json
{
  "root": "/home/user/.step/certs/root_ca.crt",
  "crt": "/home/user/.step/certs/intermediate_ca.crt",
  "key": "/home/user/.step/secrets/intermediate_ca_key",
  "address": ":8443",
  "dnsNames": ["ca.internal.lan", "localhost"],
  "logger": {"format": "text"},
  "db": {
    "type": "badgerv2",
    "dataSource": "/home/user/.step/db"
  },
  "authority": {
    "provisioners": [
      {
        "type": "JWK",
        "name": "admin",
        "encryptedKey": "..."
      },
      {
        "type": "ACME",
        "name": "acme"
      }
    ]
  }
}
```

### Environment Variables

```bash
# Optional: custom STEPPATH (default: ~/.step)
export STEPPATH="/etc/step-ca"

# Optional: password file for non-interactive use
export STEP_CA_PASSWORD_FILE="/etc/step-ca/.password"
```

### Certificate Defaults

```bash
# Default cert lifetime: 24 hours (can override)
bash scripts/cert.sh issue myapp.internal.lan --not-after 720h  # 30 days

# Default key type: EC P-256 (can override)
bash scripts/cert.sh issue myapp.internal.lan --kty RSA --size 4096
```

## Advanced Usage

### Run HA (High Availability)

```bash
# Use PostgreSQL as database backend for multi-node CA
bash scripts/setup-ca.sh --db-type postgres \
  --db-url "postgresql://user:pass@db.internal:5432/step_ca"
```

### SSH Certificates

```bash
# Enable SSH certificate authority
bash scripts/setup-ca.sh --enable-ssh

# Issue SSH user certificate
step ssh certificate user@host ~/.ssh/id_ecdsa.pub --sign

# Issue SSH host certificate
step ssh certificate myhost /etc/ssh/ssh_host_ecdsa_key.pub --host --sign
```

### Inspect Certificates

```bash
# Inspect any cert
bash scripts/cert.sh inspect certs/myapp.internal.lan.crt

# Output:
# Subject:     myapp.internal.lan
# Issuer:      My Private CA Intermediate CA
# Valid from:  2026-03-05T19:53:00Z
# Valid until: 2026-03-06T19:53:00Z
# Key type:    EC P-256
# SANs:        myapp.internal.lan
```

### Revoke Certificates

```bash
# Revoke a compromised cert
bash scripts/cert.sh revoke certs/myapp.internal.lan.crt

# Output: ✅ Certificate revoked. Serial: 1234567890
```

## Troubleshooting

### Issue: "connection refused" when issuing certs

**Fix:** Ensure step-ca is running:
```bash
bash scripts/manage.sh status
bash scripts/manage.sh start  # if stopped
```

### Issue: "certificate signed by unknown authority"

**Fix:** Install the root CA into system trust store:
```bash
bash scripts/trust.sh install
# Then restart the application/browser
```

### Issue: "x509: certificate has expired"

**Fix:** Enable auto-renewal:
```bash
bash scripts/cert.sh renew myapp.internal.lan
```

### Issue: Permission denied on port 443

**Fix:** Use a high port (8443) or grant capability:
```bash
sudo setcap 'cap_net_bind_service=+ep' $(which step-ca)
```

## Dependencies

- `step-cli` (Smallstep CLI — certificate management)
- `step-ca` (Smallstep CA server)
- `bash` (4.0+)
- `curl` (for health checks)
- `jq` (for config parsing)
- Optional: `systemd` (for service management)

## Key Principles

1. **Short-lived certs** — Default 24h, forces auto-renewal (more secure)
2. **Zero trust** — mTLS for service-to-service auth
3. **ACME compatible** — Works with Caddy, Traefik, certbot, any ACME client
4. **Minimal attack surface** — CA keys stay on one machine, only cert issuance exposed
5. **Auditable** — Every cert issuance logged in step-ca database
