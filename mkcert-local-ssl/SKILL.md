---
name: mkcert-local-ssl
description: >-
  Generate locally-trusted SSL certificates for development domains using mkcert. No more browser warnings for localhost.
categories: [dev-tools, security]
dependencies: [mkcert, bash]
---

# mkcert Local SSL Manager

## What This Does

Generate locally-trusted HTTPS certificates for local development domains — no more "Your connection is not private" warnings. Uses [mkcert](https://github.com/nicerloop/mkcert) to create a local Certificate Authority and issue certificates trusted by your browser and system.

**Example:** `bash scripts/run.sh --domains "localhost,myapp.local,*.dev.local"` → cert + key files ready for nginx/caddy/node.

## Quick Start (3 minutes)

### 1. Install mkcert

```bash
bash scripts/install.sh
```

This installs mkcert and creates a local CA (one-time setup). Your browsers will automatically trust certificates from this CA.

### 2. Generate a Certificate

```bash
# Single domain
bash scripts/run.sh --domains "localhost"

# Multiple domains + wildcard
bash scripts/run.sh --domains "localhost,myapp.local,*.dev.local,127.0.0.1"

# Output:
# ✅ Certificate generated:
#   cert: /home/user/.local/share/mkcert-ssl/localhost+3.pem
#   key:  /home/user/.local/share/mkcert-ssl/localhost+3-key.pem
#   domains: localhost, myapp.local, *.dev.local, 127.0.0.1
#   expires: 2028-02-24
```

### 3. Use with Your Server

```bash
# Node.js
node --tls-cert=/path/to/cert.pem --tls-key=/path/to/key.pem app.js

# Nginx
# ssl_certificate /path/to/cert.pem;
# ssl_certificate_key /path/to/key.pem;

# Caddy (Caddyfile)
# myapp.local {
#   tls /path/to/cert.pem /path/to/key.pem
# }
```

## Core Workflows

### Workflow 1: Generate Cert for localhost

```bash
bash scripts/run.sh --domains "localhost,127.0.0.1,::1"
```

### Workflow 2: Generate Wildcard Cert for Local Dev

```bash
bash scripts/run.sh --domains "*.local.dev,local.dev"
```

Use with `/etc/hosts` entries:
```
127.0.0.1 api.local.dev
127.0.0.1 app.local.dev
127.0.0.1 admin.local.dev
```

### Workflow 3: Generate Cert with Custom Output Path

```bash
bash scripts/run.sh --domains "myapp.local" --output /path/to/project/certs/
```

### Workflow 4: List All Generated Certificates

```bash
bash scripts/run.sh --list
```

Output:
```
Certificates in /home/user/.local/share/mkcert-ssl/:
  localhost+2.pem        (localhost, 127.0.0.1, ::1) — expires 2028-02-24
  myapp.local.pem        (myapp.local)               — expires 2028-02-24
  wildcard.local.dev.pem (*.local.dev, local.dev)     — expires 2028-02-24
```

### Workflow 5: Check CA Installation Status

```bash
bash scripts/run.sh --status
```

Output:
```
✅ mkcert installed: v1.4.4
✅ Local CA installed and trusted
   CA location: /home/user/.local/share/mkcert
   Certificates: 3 generated
```

### Workflow 6: Revoke / Clean Up

```bash
# Remove a specific cert
bash scripts/run.sh --remove "localhost+2"

# Uninstall the local CA (removes trust)
bash scripts/run.sh --uninstall-ca
```

## Configuration

### Environment Variables

```bash
# Custom certificate storage directory (default: ~/.local/share/mkcert-ssl/)
export MKCERT_SSL_DIR="$HOME/.local/share/mkcert-ssl"

# Certificate validity (mkcert default: 2 years 3 months)
# Note: mkcert doesn't support custom validity — this is informational
```

### Integration Examples

**Node.js (Express):**
```javascript
const https = require('https');
const fs = require('fs');
const app = require('./app');

https.createServer({
  cert: fs.readFileSync('/path/to/cert.pem'),
  key: fs.readFileSync('/path/to/key.pem')
}, app).listen(443);
```

**Vite:**
```javascript
// vite.config.js
import fs from 'fs';
export default {
  server: {
    https: {
      cert: fs.readFileSync('/path/to/cert.pem'),
      key: fs.readFileSync('/path/to/key.pem'),
    }
  }
}
```

**Docker Compose:**
```yaml
services:
  nginx:
    volumes:
      - ./certs:/etc/nginx/certs:ro
    ports:
      - "443:443"
```

## Troubleshooting

### Issue: "mkcert: command not found"

```bash
# Re-run install
bash scripts/install.sh
```

### Issue: Browser still shows warning after cert generation

```bash
# Reinstall the CA root
mkcert -install
# Then restart your browser
```

### Issue: Firefox doesn't trust the cert (Linux)

Firefox uses its own cert store. mkcert handles this if `certutil` is installed:
```bash
sudo apt-get install libnss3-tools  # Debian/Ubuntu
# Then re-run: mkcert -install
```

### Issue: Certificate expired

```bash
# Regenerate
bash scripts/run.sh --domains "localhost,myapp.local"
# Old cert is replaced automatically
```

## Dependencies

- `mkcert` (installed by scripts/install.sh)
- `bash` (4.0+)
- `openssl` (for cert inspection)
- Optional: `libnss3-tools` (for Firefox trust on Linux)
