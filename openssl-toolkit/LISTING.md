# Listing Copy: OpenSSL Toolkit

## Metadata
- **Type:** Skill
- **Name:** openssl-toolkit
- **Display Name:** OpenSSL Toolkit
- **Categories:** [security, dev-tools]
- **Icon:** 🔐
- **Dependencies:** [openssl, bash]

## Tagline
Manage SSL certificates and keys — generate, inspect, convert, and verify from the CLI

## Description

Tired of Googling OpenSSL commands every time you need a certificate? The OpenSSL Toolkit wraps all the common operations into a single, easy-to-use script.

Generate self-signed certificates for local development with proper SANs. Create CSRs ready for CA signing. Check when your production SSL expires (and get warned before it's too late). Convert between PEM, DER, and PKCS12 formats. Verify certificate chains. Generate RSA, ECDSA, and Ed25519 keys. Confirm your cert and key actually match.

**What it does:**
- 🔐 Generate self-signed certs with SANs for local dev
- 📝 Create CSRs for CA signing with custom org/country
- 🔍 Inspect local certificate files (subject, issuer, dates, SANs)
- 🌐 Check remote server certificates and expiry dates
- 🔄 Convert between PEM, DER, and PKCS12 formats
- ✅ Verify certificate chains against CA bundles
- 🔑 Generate RSA (up to 4096-bit), ECDSA, and Ed25519 keys
- 🔗 Confirm certificate-key pair matches

No external services, no API keys — just OpenSSL and bash. Works on any Linux or macOS system.

## Quick Start Preview

```bash
# Generate a self-signed cert
bash scripts/openssl-toolkit.sh self-signed --cn "myapp.local" --days 365 --out ./certs

# Check when production cert expires
bash scripts/openssl-toolkit.sh check-expiry --host example.com

# Convert PFX to PEM
bash scripts/openssl-toolkit.sh convert --from p12 --to pem --input cert.p12 --output cert.pem
```
