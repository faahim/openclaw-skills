#!/bin/bash
# Audit which applications have Firejail profiles
set -e

echo "🔍 Firejail Sandbox Audit"
echo "========================="
echo ""

if ! command -v firejail &>/dev/null; then
    echo "❌ Firejail not installed. Run: bash scripts/install.sh"
    exit 1
fi

# Count profiles
SYSTEM_PROFILES=$(ls /etc/firejail/*.profile 2>/dev/null | wc -l)
USER_PROFILES=$(ls ~/.config/firejail/*.profile 2>/dev/null | wc -l)

echo "📊 Profile Summary"
echo "   System profiles: $SYSTEM_PROFILES"
echo "   User profiles:   $USER_PROFILES"
echo ""

# Check common high-risk apps
echo "🎯 High-Risk Application Coverage"
echo "──────────────────────────────────"

HIGH_RISK_APPS=(
    "firefox" "chromium" "chromium-browser" "google-chrome"
    "thunderbird" "evolution"
    "slack" "discord" "telegram-desktop" "signal-desktop"
    "code" "atom" "sublime_text"
    "transmission-gtk" "qbittorrent" "deluge"
    "vlc" "mpv"
    "libreoffice" "gimp" "inkscape"
    "steam"
    "zoom" "skype"
)

COVERED=0
UNCOVERED=0
MISSING_APPS=0

for app in "${HIGH_RISK_APPS[@]}"; do
    if command -v "$app" &>/dev/null; then
        if [ -f "/etc/firejail/${app}.profile" ] || [ -f "$HOME/.config/firejail/${app}.profile" ]; then
            echo "   ✅ $app — profiled"
            ((COVERED++))
        else
            echo "   ⚠️  $app — INSTALLED but NO profile"
            ((UNCOVERED++))
        fi
    fi
done

echo ""
echo "📈 Coverage: $COVERED profiled, $UNCOVERED unprotected"

# List active sandboxes
ACTIVE=$(firejail --list 2>/dev/null | wc -l)
if [ "$ACTIVE" -gt 0 ]; then
    echo ""
    echo "🏃 Active Sandboxes ($ACTIVE)"
    echo "──────────────────────────────"
    firejail --list 2>/dev/null
fi

# Suggestions
if [ "$UNCOVERED" -gt 0 ]; then
    echo ""
    echo "💡 Recommendations"
    echo "──────────────────"
    echo "   Run 'sudo firecfg' to auto-sandbox all supported apps"
    echo "   Or create profiles: bash scripts/create-profile.sh <app>"
fi
