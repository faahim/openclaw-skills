#!/bin/bash
# Test Netdata alert notifications
set -e

METHOD="${1:-all}"

echo "🧪 Testing alert notification: $METHOD"

# Use Netdata's built-in alarm tester
TESTER="/usr/libexec/netdata/plugins.d/alarm-notify.sh"
[ ! -f "$TESTER" ] && TESTER="/usr/lib/netdata/plugins.d/alarm-notify.sh"
[ ! -f "$TESTER" ] && TESTER="$(find / -name 'alarm-notify.sh' -path '*/netdata/*' 2>/dev/null | head -1)"

if [ -z "$TESTER" ] || [ ! -f "$TESTER" ]; then
    echo "❌ Could not find alarm-notify.sh"
    echo "   Netdata may not be installed correctly"
    exit 1
fi

sudo "$TESTER" test "$METHOD" 2>&1

echo ""
echo "✅ Test notification sent via: $METHOD"
echo "   Check your $METHOD for the test message"
