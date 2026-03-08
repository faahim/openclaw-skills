---
name: jwt-toolkit
description: >-
  Decode, verify, generate, and debug JWT tokens from the command line.
categories: [dev-tools, security]
dependencies: [bash, openssl, jq]
---

# JWT Toolkit

## What This Does

Decode, verify, generate, and debug JSON Web Tokens directly from your terminal. No web-based tools, no copy-pasting tokens into random websites. Inspect headers and payloads, check expiry, verify signatures with HMAC/RSA/EC keys, and generate new tokens for testing.

**Example:** "Decode a JWT from your API, check if it's expired, verify the signature against your secret, generate test tokens with custom claims."

## Quick Start (2 minutes)

### 1. Check Dependencies

```bash
# These are standard on most systems
which openssl jq base64 || echo "Install missing: apt install jq openssl coreutils"
```

### 2. Decode a JWT

```bash
bash scripts/jwt.sh decode "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"

# Output:
# === HEADER ===
# {
#   "alg": "HS256",
#   "typ": "JWT"
# }
# === PAYLOAD ===
# {
#   "sub": "1234567890",
#   "name": "John Doe",
#   "iat": 1516239022
# }
# === TOKEN STATUS ===
# ⚠️  No 'exp' claim — token does not expire
```

### 3. Generate a Test Token

```bash
bash scripts/jwt.sh generate \
  --secret "my-secret-key" \
  --claim "sub=user123" \
  --claim "role=admin" \
  --expires 3600

# Output: eyJhbGciOiJIUzI1NiIs...
```

## Core Workflows

### Workflow 1: Decode & Inspect Token

**Use case:** Debug an API token — see what claims it carries

```bash
# From a variable
bash scripts/jwt.sh decode "$MY_TOKEN"

# From clipboard (Linux)
xclip -selection clipboard -o | xargs bash scripts/jwt.sh decode

# Pretty-print specific claim
bash scripts/jwt.sh decode "$TOKEN" --claim sub
# Output: 1234567890
```

### Workflow 2: Check Expiry

**Use case:** Is this token still valid?

```bash
bash scripts/jwt.sh check "$TOKEN"

# Output:
# ✅ Token is VALID — expires in 2h 15m (2026-03-08T05:08:00Z)
# or
# ❌ Token EXPIRED 3d ago (2026-03-05T02:53:00Z)
```

### Workflow 3: Verify Signature (HMAC)

**Use case:** Confirm token wasn't tampered with

```bash
bash scripts/jwt.sh verify "$TOKEN" --secret "my-secret-key"

# Output:
# ✅ Signature VALID (HS256)
# or
# ❌ Signature INVALID — token may be tampered
```

### Workflow 4: Verify Signature (RSA/EC)

**Use case:** Verify with a public key

```bash
# RSA
bash scripts/jwt.sh verify "$TOKEN" --pubkey /path/to/public.pem

# EC (P-256)
bash scripts/jwt.sh verify "$TOKEN" --pubkey /path/to/ec-public.pem
```

### Workflow 5: Generate Test Tokens

**Use case:** Create tokens for API testing

```bash
# HMAC token with custom claims
bash scripts/jwt.sh generate \
  --alg HS256 \
  --secret "test-secret" \
  --claim "sub=user42" \
  --claim "email=test@example.com" \
  --claim "roles=[\"admin\",\"user\"]" \
  --expires 86400

# RSA-signed token
bash scripts/jwt.sh generate \
  --alg RS256 \
  --privkey /path/to/private.pem \
  --claim "sub=service-account" \
  --claim "iss=my-auth-server" \
  --expires 3600
```

### Workflow 6: Diff Two Tokens

**Use case:** Compare what changed between two JWTs

```bash
bash scripts/jwt.sh diff "$OLD_TOKEN" "$NEW_TOKEN"

# Output:
# === HEADER DIFF ===
# (no changes)
# === PAYLOAD DIFF ===
# - "exp": 1709856000
# + "exp": 1709942400
# - "role": "user"
# + "role": "admin"
```

### Workflow 7: Generate Key Pairs

**Use case:** Create RSA/EC key pairs for JWT signing

```bash
# RSA 2048-bit
bash scripts/jwt.sh keygen --alg RS256 --out ./keys/

# EC P-256
bash scripts/jwt.sh keygen --alg ES256 --out ./keys/

# Output:
# ✅ Private key: ./keys/private.pem
# ✅ Public key:  ./keys/public.pem
```

### Workflow 8: Batch Decode from Logs

**Use case:** Extract and decode JWTs from log files or curl output

```bash
# Extract Bearer tokens from HTTP headers in a log file
grep -oP 'Bearer \K[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+' access.log | \
  while read token; do
    echo "---"
    bash scripts/jwt.sh decode "$token" --compact
  done
```

## Configuration

### Environment Variables

```bash
# Default secret for HMAC operations (optional)
export JWT_SECRET="your-default-secret"

# Default algorithm
export JWT_ALG="HS256"  # HS256, HS384, HS512, RS256, RS384, RS512, ES256, ES384, ES512

# Default private key path (for RSA/EC)
export JWT_PRIVKEY="/path/to/private.pem"

# Default public key path (for verification)
export JWT_PUBKEY="/path/to/public.pem"
```

## Troubleshooting

### Issue: "base64: invalid input"

**Fix:** The token may have URL-safe base64. The script handles this automatically, but if you're piping raw base64:
```bash
echo "$segment" | tr '_-' '/+' | base64 -d
```

### Issue: "openssl: command not found"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get install openssl

# Mac (usually pre-installed)
brew install openssl
```

### Issue: RSA verification fails on valid token

**Check:**
1. Key format is PEM (not DER)
2. Using the correct public key that matches the signing private key
3. Algorithm matches: RS256 vs RS384 vs RS512

## Dependencies

- `bash` (4.0+)
- `openssl` (for signature operations)
- `jq` (for JSON pretty-printing)
- `base64` (coreutils — pre-installed on most systems)
- `date` (coreutils — for expiry calculations)
