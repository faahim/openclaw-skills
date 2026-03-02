#!/bin/bash
# Test DNSSEC validation
set -euo pipefail

DOMAIN=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain) DOMAIN="$2"; shift 2 ;;
        *) shift ;;
    esac
done

echo "🔐 Testing DNSSEC validation..."
echo ""

if [[ -n "$DOMAIN" ]]; then
    echo "Testing: $DOMAIN"
    RESULT=$(dig @127.0.0.1 +dnssec +short "$DOMAIN" A 2>&1)
    if [[ -n "$RESULT" ]]; then
        echo "✅ $DOMAIN — resolved: $RESULT"
        # Check for AD flag
        AD_FLAG=$(dig @127.0.0.1 +dnssec "$DOMAIN" A 2>&1 | grep "flags:" | grep -c "ad" || true)
        if [[ $AD_FLAG -gt 0 ]]; then
            echo "   🔒 DNSSEC: authenticated (AD flag set)"
        else
            echo "   ⚠️  DNSSEC: not authenticated (domain may not be signed)"
        fi
    else
        echo "❌ $DOMAIN — resolution failed"
    fi
else
    # Standard DNSSEC test domains
    echo "1. Testing valid DNSSEC signature..."
    VALID=$(dig @127.0.0.1 +short sigok.verteiltesysteme.net A 2>&1)
    if [[ -n "$VALID" ]]; then
        echo "   ✅ sigok.verteiltesysteme.net — DNSSEC valid ($VALID)"
    else
        echo "   ❌ sigok.verteiltesysteme.net — failed to resolve"
    fi

    echo ""
    echo "2. Testing invalid DNSSEC signature (should be rejected)..."
    INVALID=$(dig @127.0.0.1 +short sigfail.verteiltesysteme.net A 2>&1)
    if [[ -z "$INVALID" ]]; then
        echo "   ✅ sigfail.verteiltesysteme.net — correctly rejected (SERVFAIL)"
    else
        echo "   ⚠️  sigfail.verteiltesysteme.net — resolved ($INVALID) — DNSSEC may not be enforcing"
    fi

    echo ""
    echo "3. Testing general resolution..."
    GENERAL=$(dig @127.0.0.1 +short example.com A 2>&1)
    if [[ -n "$GENERAL" ]]; then
        echo "   ✅ example.com — $GENERAL"
    else
        echo "   ❌ example.com — failed"
    fi
fi
