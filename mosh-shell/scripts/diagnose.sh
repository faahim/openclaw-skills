#!/bin/bash
# Mosh connection diagnostics
set -euo pipefail

HOST="${1:-}"
[[ -z "$HOST" ]] && { echo "Usage: $0 user@server-ip [--port SSH_PORT]"; exit 1; }

SSH_PORT="22"
[[ "${2:-}" == "--port" ]] && SSH_PORT="${3:-22}"

PASS=0
FAIL=0
WARN=0

check() {
  local num=$1 name=$2 result=$3 detail=$4
  if [[ "$result" == "pass" ]]; then
    echo "[$num] $name: ✅ $detail"
    PASS=$((PASS + 1))
  elif [[ "$result" == "fail" ]]; then
    echo "[$num] $name: ❌ $detail"
    FAIL=$((FAIL + 1))
  else
    echo "[$num] $name: ⚠️  $detail"
    WARN=$((WARN + 1))
  fi
}

echo "Diagnosing mosh connection to $HOST (SSH port $SSH_PORT)..."
echo ""

# 1. SSH connection
if ssh -p "$SSH_PORT" -o ConnectTimeout=5 -o BatchMode=yes "$HOST" "echo ok" &>/dev/null; then
  check 1 "SSH connection" pass "port $SSH_PORT"
else
  check 1 "SSH connection" fail "Cannot connect on port $SSH_PORT"
  echo ""
  echo "Fix: Check SSH access first — mosh requires SSH for handshake"
  exit 1
fi

# 2. mosh-server installed
MOSH_SERVER_PATH=$(ssh -p "$SSH_PORT" "$HOST" "command -v mosh-server 2>/dev/null" 2>/dev/null || echo "")
if [[ -n "$MOSH_SERVER_PATH" ]]; then
  MOSH_VER=$(ssh -p "$SSH_PORT" "$HOST" "mosh-server --version 2>&1 | head -1" 2>/dev/null || echo "unknown")
  check 2 "mosh-server installed" pass "$MOSH_SERVER_PATH ($MOSH_VER)"
else
  check 2 "mosh-server installed" fail "Not found on remote host"
  echo "   Fix: ssh $HOST 'sudo apt-get install -y mosh'  # or yum/brew"
fi

# 3. UDP port check (try 60001)
TEST_PORT=60001
if command -v nc &>/dev/null; then
  # Start a UDP listener on remote, test from local
  ssh -p "$SSH_PORT" "$HOST" "timeout 3 nc -ul $TEST_PORT &>/dev/null &" 2>/dev/null || true
  sleep 1
  if echo "test" | nc -u -w 2 "$(echo "$HOST" | cut -d@ -f2)" "$TEST_PORT" &>/dev/null; then
    check 3 "UDP port $TEST_PORT" pass "OPEN"
  else
    check 3 "UDP port $TEST_PORT" warn "Could not verify (may still work)"
    echo "   Fix: sudo ufw allow 60000:60010/udp"
  fi
  ssh -p "$SSH_PORT" "$HOST" "pkill -f 'nc -ul $TEST_PORT'" 2>/dev/null || true
else
  # Check remote firewall rules instead
  FW_STATUS=$(ssh -p "$SSH_PORT" "$HOST" "sudo ufw status 2>/dev/null | grep '60000' || sudo iptables -L INPUT -n 2>/dev/null | grep '60000' || echo 'unknown'" 2>/dev/null)
  if echo "$FW_STATUS" | grep -qi "allow\|accept"; then
    check 3 "UDP ports (firewall)" pass "Rules found for 60000 range"
  elif echo "$FW_STATUS" | grep -qi "unknown"; then
    check 3 "UDP ports (firewall)" warn "Could not verify — ensure UDP 60000-60010 is open"
  else
    check 3 "UDP ports (firewall)" fail "No rules found for UDP 60000 range"
    echo "   Fix: sudo ufw allow 60000:60010/udp"
  fi
fi

# 4. Server locale
SERVER_LOCALE=$(ssh -p "$SSH_PORT" "$HOST" "locale 2>/dev/null | grep 'LANG=' | head -1" 2>/dev/null || echo "")
if echo "$SERVER_LOCALE" | grep -qi "utf-\?8"; then
  check 4 "Locale (server)" pass "$(echo "$SERVER_LOCALE" | cut -d= -f2)"
else
  check 4 "Locale (server)" fail "No UTF-8 locale: $SERVER_LOCALE"
  echo "   Fix: sudo locale-gen en_US.UTF-8 && sudo update-locale LANG=en_US.UTF-8"
fi

# 5. Client locale
CLIENT_LOCALE=$(locale 2>/dev/null | grep 'LANG=' | head -1 || echo "")
if echo "$CLIENT_LOCALE" | grep -qi "utf-\?8"; then
  check 5 "Locale (client)" pass "$(echo "$CLIENT_LOCALE" | cut -d= -f2)"
else
  check 5 "Locale (client)" warn "No UTF-8 locale: $CLIENT_LOCALE"
fi

# 6. Client mosh installed
if command -v mosh &>/dev/null; then
  CLIENT_VER=$(mosh --version 2>&1 | head -1 || echo "unknown")
  check 6 "mosh (client)" pass "$CLIENT_VER"
else
  check 6 "mosh (client)" fail "Not installed locally"
  echo "   Fix: sudo apt-get install mosh  # or brew install mosh"
fi

echo ""
echo "Result: $PASS passed, $FAIL failed, $WARN warnings"

if [[ $FAIL -eq 0 ]]; then
  echo "✅ All critical checks passed — mosh should work"
  echo ""
  echo "Connect: mosh --ssh=\"ssh -p $SSH_PORT\" $HOST"
else
  echo "❌ $FAIL issue(s) found — fix them and re-run"
fi
