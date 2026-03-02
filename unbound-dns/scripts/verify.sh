#!/bin/bash
# Verify Unbound DNS resolver is working correctly
set -euo pipefail

PASS=0
FAIL=0
PORT="${UNBOUND_PORT:-53}"

check() {
    local label="$1"
    local result="$2"
    if [ "$result" = "0" ]; then
        echo "[✓] $label"
        ((PASS++))
    else
        echo "[✗] $label"
        ((FAIL++))
    fi
}

echo "=== Unbound DNS Verification ==="
echo ""

# 1. Check if running
if command -v systemctl &>/dev/null; then
    PID=$(systemctl show -p MainPID unbound 2>/dev/null | cut -d= -f2)
    if systemctl is-active --quiet unbound 2>/dev/null; then
        echo "[✓] Unbound is running (PID $PID)"
        ((PASS++))
    else
        echo "[✗] Unbound is NOT running"
        ((FAIL++))
        echo "    Fix: sudo systemctl start unbound"
    fi
elif pgrep -x unbound &>/dev/null; then
    PID=$(pgrep -x unbound | head -1)
    echo "[✓] Unbound is running (PID $PID)"
    ((PASS++))
else
    echo "[✗] Unbound is NOT running"
    ((FAIL++))
fi

# 2. Basic DNS resolution
echo ""
echo "--- DNS Resolution ---"
START=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')
RESULT=$(dig @127.0.0.1 -p "$PORT" example.com +short +time=5 2>/dev/null || echo "FAIL")
END=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')
ELAPSED=$((END - START))

if [ "$RESULT" != "FAIL" ] && [ -n "$RESULT" ]; then
    echo "[✓] DNS resolution working: example.com → $RESULT (${ELAPSED}ms)"
    ((PASS++))
else
    echo "[✗] DNS resolution FAILED for example.com"
    ((FAIL++))
    echo "    Fix: Check if Unbound is listening on 127.0.0.1:$PORT"
fi

# 3. Second query (cache test)
START2=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')
RESULT2=$(dig @127.0.0.1 -p "$PORT" example.com +short +time=5 2>/dev/null || echo "FAIL")
END2=$(date +%s%3N 2>/dev/null || python3 -c 'import time; print(int(time.time()*1000))')
ELAPSED2=$((END2 - START2))

if [ "$RESULT2" != "FAIL" ]; then
    echo "[✓] Cache hit speed: ${ELAPSED2}ms (second query)"
    ((PASS++))
fi

# 4. DNSSEC validation
echo ""
echo "--- DNSSEC Validation ---"
DNSSEC_GOOD=$(dig @127.0.0.1 -p "$PORT" sigok.verteiltesysteme.net +short +time=5 2>/dev/null || echo "")
DNSSEC_BAD=$(dig @127.0.0.1 -p "$PORT" sigfail.verteiltesysteme.net +short +time=5 2>/dev/null || echo "")

if [ -n "$DNSSEC_GOOD" ] && [ -z "$DNSSEC_BAD" ]; then
    echo "[✓] DNSSEC validation: PASS (valid sigs accepted, invalid sigs rejected)"
    ((PASS++))
elif [ -n "$DNSSEC_GOOD" ]; then
    echo "[~] DNSSEC partial: valid sigs work, but invalid sigs not rejected"
    ((PASS++))
else
    echo "[✗] DNSSEC validation: FAIL"
    ((FAIL++))
fi

# 5. Config check
echo ""
echo "--- Configuration ---"
if unbound-checkconf /etc/unbound/unbound.conf &>/dev/null; then
    echo "[✓] Config syntax: valid"
    ((PASS++))
else
    echo "[✗] Config syntax: INVALID"
    ((FAIL++))
fi

# 6. Check resolv.conf
if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then
    echo "[✓] System DNS points to localhost"
    ((PASS++))
else
    echo "[~] System DNS not pointing to 127.0.0.1"
    echo "    Your system may not be using Unbound yet."
    echo "    Fix: echo 'nameserver 127.0.0.1' | sudo tee /etc/resolv.conf"
fi

# 7. Multiple domain test
echo ""
echo "--- Multi-Domain Test ---"
DOMAINS=("google.com" "github.com" "cloudflare.com")
ALL_OK=true
for domain in "${DOMAINS[@]}"; do
    R=$(dig @127.0.0.1 -p "$PORT" "$domain" +short +time=5 2>/dev/null | head -1)
    if [ -n "$R" ]; then
        echo "    $domain → $R"
    else
        echo "    $domain → FAILED"
        ALL_OK=false
    fi
done
if [ "$ALL_OK" = true ]; then
    echo "[✓] All domains resolved successfully"
    ((PASS++))
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
    echo "🎉 Unbound is fully operational!"
else
    echo "⚠️  Some checks failed. Review the output above."
fi

exit $FAIL
