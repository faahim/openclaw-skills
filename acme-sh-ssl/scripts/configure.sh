#!/bin/bash
# ACME.sh SSL Manager — Configuration

set -euo pipefail

ACME="$HOME/.acme.sh/acme.sh"
[[ -f "$ACME" ]] || { echo "❌ acme.sh not installed."; exit 1; }

CA=""
EMAIL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --ca) CA="$2"; shift 2 ;;
    --email) EMAIL="$2"; shift 2 ;;
    --upgrade) "$ACME" --upgrade; echo "✅ Upgraded"; exit 0 ;;
    --version) "$ACME" --version; exit 0 ;;
    --help) echo "Usage: bash configure.sh [--ca letsencrypt|zerossl|buypass|google] [--email you@email.com] [--upgrade] [--version]"; exit 0 ;;
    *) shift ;;
  esac
done

if [[ -n "$CA" ]]; then
  "$ACME" --set-default-ca --server "$CA"
  echo "✅ Default CA set to: $CA"
fi

if [[ -n "$EMAIL" ]]; then
  "$ACME" --register-account -m "$EMAIL"
  echo "✅ Account registered with email: $EMAIL"
fi

if [[ -z "$CA" && -z "$EMAIL" ]]; then
  echo "ℹ️  Current configuration:"
  echo "   Install dir: $HOME/.acme.sh/"
  echo "   Version:     $("$ACME" --version 2>/dev/null | head -1)"
  echo ""
  echo "   Options:"
  echo "     --ca letsencrypt|zerossl|buypass|google"
  echo "     --email you@email.com"
  echo "     --upgrade"
fi
