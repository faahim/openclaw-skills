---
name: openssl-toolkit
description: >-
  Generate certificates, CSRs, and keys — inspect, convert, and verify SSL/TLS assets from the command line.
categories: [security, dev-tools]
dependencies: [openssl, bash]
---

# OpenSSL Toolkit

## What This Does

Automates common OpenSSL operations: generate self-signed certs, create CSRs, inspect certificates (local or remote), convert between formats (PEM/DER/PKCS12), verify chains, and generate strong keys. Saves you from memorizing arcane OpenSSL flags.

**Example:** "Generate a self-signed cert for local dev, check when production cert expires, convert a PFX to PEM."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
which openssl || echo "Install openssl first"
openssl version
```

### 2. Generate a Self-Signed Certificate

```bash
bash scripts/openssl-toolkit.sh self-signed \
  --cn "localhost" \
  --days 365 \
  --out ./certs
```

Output:
```
✅ Generated self-signed certificate:
   Key:  ./certs/localhost.key
   Cert: ./certs/localhost.crt
   Valid: 365 days (expires 2027-03-06)
```

### 3. Inspect a Remote Server's Certificate

```bash
bash scripts/openssl-toolkit.sh inspect-remote --host google.com --port 443
```

Output:
```
🔍 Certificate for google.com:443
   Subject:  CN=*.google.com
   Issuer:   CN=GTS CA 1C3, O=Google Trust Services LLC
   Valid:    2026-01-15 to 2026-04-09
   Days left: 34
   Serial:   0A:1B:2C:...
   SANs:     *.google.com, google.com
   Sig Algo: SHA256-RSA
```

## Core Workflows

### Workflow 1: Self-Signed Certificate (Local Dev)

```bash
bash scripts/openssl-toolkit.sh self-signed \
  --cn "myapp.local" \
  --sans "DNS:myapp.local,DNS:api.myapp.local,IP:127.0.0.1" \
  --days 365 \
  --out ./certs
```

### Workflow 2: Generate CSR for CA Signing

```bash
bash scripts/openssl-toolkit.sh csr \
  --cn "example.com" \
  --org "My Company" \
  --country "US" \
  --sans "DNS:example.com,DNS:www.example.com" \
  --keysize 4096 \
  --out ./certs
```

Output:
```
✅ Generated CSR:
   Key: ./certs/example.com.key
   CSR: ./certs/example.com.csr
   Submit the CSR to your Certificate Authority.
```

### Workflow 3: Inspect Local Certificate File

```bash
bash scripts/openssl-toolkit.sh inspect --file ./certs/server.crt
```

### Workflow 4: Check Remote Certificate Expiry

```bash
bash scripts/openssl-toolkit.sh check-expiry --host example.com
```

Output:
```
🔐 example.com — SSL expires in 142 days (2026-07-25)
```

### Workflow 5: Convert Certificate Formats

```bash
# PEM to DER
bash scripts/openssl-toolkit.sh convert --from pem --to der \
  --input cert.pem --output cert.der

# PEM to PKCS12 (PFX)
bash scripts/openssl-toolkit.sh convert --from pem --to p12 \
  --input cert.pem --key private.key --output cert.p12

# PKCS12 to PEM
bash scripts/openssl-toolkit.sh convert --from p12 --to pem \
  --input cert.p12 --output cert.pem
```

### Workflow 6: Verify Certificate Chain

```bash
bash scripts/openssl-toolkit.sh verify-chain \
  --cert server.crt \
  --ca ca-bundle.crt
```

Output:
```
✅ Certificate chain is valid
   server.crt → Intermediate CA → Root CA
```

### Workflow 7: Generate Keys

```bash
# RSA 4096-bit
bash scripts/openssl-toolkit.sh genkey --type rsa --bits 4096 --out mykey.pem

# ECDSA P-256
bash scripts/openssl-toolkit.sh genkey --type ecdsa --curve prime256v1 --out mykey.pem

# Ed25519
bash scripts/openssl-toolkit.sh genkey --type ed25519 --out mykey.pem
```

### Workflow 8: Check Certificate Match (Key + Cert)

```bash
bash scripts/openssl-toolkit.sh match --cert server.crt --key server.key
```

Output:
```
✅ Certificate and key MATCH
```
or
```
❌ Certificate and key DO NOT MATCH
```

## Troubleshooting

### "Can't connect to remote host"
Ensure the host is reachable and the port is open:
```bash
nc -zv example.com 443
```

### "unable to load certificate"
Check the file format. Use `inspect` to see what you have:
```bash
file cert.pem
bash scripts/openssl-toolkit.sh inspect --file cert.pem
```

### "PKCS12 password prompt"
For P12 conversions, set password via `--password` flag or it will prompt interactively.

## Dependencies

- `openssl` (1.1+ or 3.x)
- `bash` (4.0+)
- `nc` / `ncat` (optional, for connectivity checks)
