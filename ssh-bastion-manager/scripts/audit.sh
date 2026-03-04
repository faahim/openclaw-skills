#!/usr/bin/env bash
set -euo pipefail

EXPECTED_PORT=22
while [[ $# -gt 0 ]]; do
  case "$1" in
    --expected-port) EXPECTED_PORT="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 1;;
  esac
done

ok() { echo "✅ $*"; }
fail() { echo "❌ $*"; }

CFG=/etc/ssh/sshd_config
[[ -f "$CFG" ]] || { fail "Missing $CFG"; exit 1; }

PORT=$(awk '/^Port /{print $2; exit}' "$CFG" || true)
[[ "$PORT" == "$EXPECTED_PORT" ]] && ok "SSH port is $EXPECTED_PORT" || fail "SSH port mismatch (found: ${PORT:-none})"

grep -Eq '^PasswordAuthentication no' "$CFG" && ok "PasswordAuthentication disabled" || fail "PasswordAuthentication not hardened"
grep -Eq '^PermitRootLogin no' "$CFG" && ok "Root login disabled" || fail "Root login not hardened"

if command -v ufw >/dev/null 2>&1; then
  ufw status | grep -q "Status: active" && ok "UFW active" || fail "UFW inactive"
else
  fail "UFW not installed"
fi

systemctl is-active --quiet fail2ban && ok "Fail2ban running" || fail "Fail2ban not running"
