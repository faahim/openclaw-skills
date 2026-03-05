#!/bin/bash
# Install dependencies for Package Auditor

set -euo pipefail

echo "📦 Package Auditor — Installing dependencies..."

if command -v apt-get &>/dev/null; then
  echo "  Detected: Debian/Ubuntu (apt)"
  sudo apt-get update -qq
  sudo apt-get install -y debsecan jq
  
  # apt-show-versions is optional
  if ! command -v apt-show-versions &>/dev/null; then
    sudo apt-get install -y apt-show-versions 2>/dev/null || echo "  ⚠️  apt-show-versions not available (optional)"
  fi
  
  echo "  ✅ Dependencies installed"

elif command -v dnf &>/dev/null; then
  echo "  Detected: RHEL/Fedora (dnf)"
  sudo dnf install -y jq
  echo "  ✅ Dependencies installed (dnf has built-in security advisories)"

elif command -v brew &>/dev/null; then
  echo "  Detected: macOS (brew)"
  brew install jq 2>/dev/null || true
  echo "  ✅ Dependencies installed"

else
  echo "  ❌ Unsupported package manager"
  echo "  Supported: apt (Debian/Ubuntu), dnf (RHEL/Fedora), brew (macOS)"
  exit 1
fi

echo ""
echo "✅ Ready! Run: bash scripts/audit.sh"
