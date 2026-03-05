#!/bin/bash
# Install dependencies for DNS Propagation Checker
set -euo pipefail

echo "🔍 Checking dependencies..."

# Check dig
if command -v dig &>/dev/null; then
  echo "✅ dig is installed ($(dig -v 2>&1 | head -1))"
else
  echo "❌ dig not found. Installing..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y dnsutils
  elif command -v yum &>/dev/null; then
    sudo yum install -y bind-utils
  elif command -v apk &>/dev/null; then
    sudo apk add bind-tools
  elif command -v brew &>/dev/null; then
    brew install bind
  else
    echo "⚠️  Could not auto-install. Please install 'dig' manually."
    exit 1
  fi
  echo "✅ dig installed"
fi

# Check jq (optional)
if command -v jq &>/dev/null; then
  echo "✅ jq is installed (optional, for JSON formatting)"
else
  echo "ℹ️  jq not installed (optional — needed for --json pretty-printing)"
fi

echo ""
echo "✅ All required dependencies are installed!"
echo "   Run: bash scripts/check.sh <domain> <record-type>"
