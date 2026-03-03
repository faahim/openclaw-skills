#!/bin/bash
# Pretty-print what a Firejail profile restricts
set -e

APP="${1:-}"

if [ -z "$APP" ]; then
    echo "Usage: bash show-profile.sh <app-name>"
    exit 1
fi

# Find profile
PROFILE=""
if [ -f "$HOME/.config/firejail/${APP}.profile" ]; then
    PROFILE="$HOME/.config/firejail/${APP}.profile"
    echo "📄 User profile: $PROFILE"
elif [ -f "/etc/firejail/${APP}.profile" ]; then
    PROFILE="/etc/firejail/${APP}.profile"
    echo "📄 System profile: $PROFILE"
else
    echo "❌ No profile found for: $APP"
    echo "   Create one: bash scripts/create-profile.sh $APP"
    exit 1
fi

echo ""

# Parse and display restrictions
echo "🔒 Restrictions for: $APP"
echo "═══════════════════════════════"

echo ""
echo "📁 Filesystem:"
grep -E "^(blacklist|whitelist|read-only|private|noblacklist)" "$PROFILE" 2>/dev/null | sed 's/^/   /' || echo "   (none specified)"

echo ""
echo "🌐 Network:"
grep -E "^(net |dns |protocol )" "$PROFILE" 2>/dev/null | sed 's/^/   /' || echo "   (unrestricted)"

echo ""
echo "🛡️  Security:"
grep -E "^(caps|seccomp|noroot|nonewprivs|apparmor)" "$PROFILE" 2>/dev/null | sed 's/^/   /' || echo "   (default)"

echo ""
echo "🔇 Devices:"
grep -E "^(nosound|no3d|notv|novideo|nodvd|private-dev|private-tmp)" "$PROFILE" 2>/dev/null | sed 's/^/   /' || echo "   (all allowed)"

echo ""
echo "📋 Other:"
grep -E "^(nogroups|shell|disable-mnt|dbus)" "$PROFILE" 2>/dev/null | sed 's/^/   /' || echo "   (none)"

echo ""
echo "📝 Full profile: $PROFILE"
