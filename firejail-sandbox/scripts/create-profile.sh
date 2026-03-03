#!/bin/bash
# Create a restrictive Firejail profile for an application
set -e

APP_NAME="${1:-}"

if [ -z "$APP_NAME" ]; then
    echo "Usage: bash create-profile.sh <app-name>"
    echo "Example: bash create-profile.sh myapp"
    exit 1
fi

PROFILE_DIR="$HOME/.config/firejail"
PROFILE_FILE="$PROFILE_DIR/${APP_NAME}.profile"

mkdir -p "$PROFILE_DIR"

if [ -f "$PROFILE_FILE" ]; then
    echo "⚠️  Profile already exists: $PROFILE_FILE"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
fi

# Find the app binary
APP_PATH=$(which "$APP_NAME" 2>/dev/null || echo "")

cat > "$PROFILE_FILE" << EOF
# Firejail profile for: $APP_NAME
# Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
# Location: $PROFILE_FILE
#
# Start restrictive, relax as needed.
# Test with: firejail --profile=$PROFILE_FILE $APP_NAME

# ── Filesystem ──────────────────────────
# Blacklist sensitive directories
blacklist \${HOME}/.ssh
blacklist \${HOME}/.gnupg
blacklist \${HOME}/.aws
blacklist \${HOME}/.config/gcloud
blacklist \${HOME}/.kube
blacklist \${HOME}/.docker
blacklist \${HOME}/.password-store
blacklist \${HOME}/.local/share/keyrings

# App-specific whitelist (uncomment and customize)
# whitelist \${HOME}/.config/$APP_NAME
# whitelist \${HOME}/$APP_NAME-data

# Temp directories
private-tmp
private-dev

# ── Network ─────────────────────────────
# Uncomment ONE of these:
# net none                    # No network at all
# dns 1.1.1.1                # Restrict DNS server
# protocol unix,inet,inet6   # Allow only these protocols

# ── System ──────────────────────────────
nogroups
nosound
no3d
notv
novideo
nodvd
nonewprivs

# ── Security ────────────────────────────
caps.drop all
seccomp
noroot

# ── D-Bus ───────────────────────────────
# dbus-user none
# dbus-system none

# ── Misc ────────────────────────────────
shell none
disable-mnt
EOF

echo "✅ Profile created: $PROFILE_FILE"
echo ""
echo "Test it:"
echo "   firejail --profile=$PROFILE_FILE $APP_NAME"
echo ""
echo "If the app doesn't work, relax restrictions by commenting out lines."
echo "Start by commenting out 'net none', then 'nosound', then 'caps.drop all'."
