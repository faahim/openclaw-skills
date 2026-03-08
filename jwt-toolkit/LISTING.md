# Listing Copy: JWT Toolkit

## Metadata
- **Type:** Skill
- **Name:** jwt-toolkit
- **Display Name:** JWT Toolkit
- **Categories:** [dev-tools, security]
- **Icon:** 🔑
- **Dependencies:** [bash, openssl, jq]

## Tagline

Decode, verify, generate & debug JWT tokens — all from your terminal

## Description

Tired of pasting tokens into random websites just to see what's inside? JWT Toolkit gives your OpenClaw agent full JWT superpowers — decode headers and payloads, check expiry, verify HMAC/RSA/EC signatures, generate test tokens, diff two tokens, and create key pairs. All from the command line, no external services.

**What it does:**
- 🔍 Decode any JWT — inspect headers, payloads, and expiry status
- ✅ Verify signatures — HMAC (HS256/384/512), RSA (RS256/384/512), EC (ES256/384/512)
- 🔨 Generate test tokens — custom claims, configurable expiry, any algorithm
- 📊 Diff two tokens — see exactly what changed between versions
- 🔐 Generate key pairs — RSA and EC keys for signing
- ⏰ Expiry checks — instant valid/expired status with human-readable time remaining

**Who it's for:** Developers working with APIs, auth systems, OAuth flows, or any JWT-based infrastructure. Debug tokens in seconds instead of minutes.

## Quick Start Preview

```bash
# Decode a token
bash scripts/jwt.sh decode "eyJhbG..."

# Verify signature
bash scripts/jwt.sh verify "$TOKEN" --secret "my-key"

# Generate test token
bash scripts/jwt.sh generate --secret "key" --claim "sub=user1" --expires 3600
```

## Core Capabilities

1. JWT decoding — Pretty-print header + payload with syntax highlighting
2. Expiry checking — Human-readable "expires in 2h 15m" or "expired 3d ago"
3. HMAC verification — HS256, HS384, HS512 signature validation
4. RSA verification — RS256, RS384, RS512 with PEM public keys
5. EC verification — ES256, ES384, ES512 with PEM public keys
6. Token generation — Create tokens with custom claims and expiry
7. RSA/EC keygen — Generate key pairs for JWT signing
8. Token diffing — Compare two tokens side-by-side
9. Claim extraction — Pull specific claims by name
10. Batch decoding — Parse tokens from log files and HTTP headers
11. Environment config — Set defaults via JWT_SECRET, JWT_ALG, etc.
12. Zero dependencies beyond standard tools — bash, openssl, jq, base64
