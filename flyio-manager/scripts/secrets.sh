#!/bin/bash
# Manage Fly.io app secrets
# Usage: bash secrets.sh --set KEY=VAL ... | --list | --unset KEY ... [--app NAME]

set -euo pipefail

PREFIX="[flyio-manager]"
ACTION=""
APP=""
SECRETS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --set) ACTION="set"; shift
            while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                SECRETS+=("$1"); shift
            done ;;
        --unset) ACTION="unset"; shift
            while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                SECRETS+=("$1"); shift
            done ;;
        --list) ACTION="list"; shift ;;
        --app) APP="$2"; shift 2 ;;
        *) echo "$PREFIX Unknown option: $1"; exit 1 ;;
    esac
done

if ! command -v fly &>/dev/null; then
    echo "$PREFIX flyctl not found. Run: bash scripts/install.sh"
    exit 1
fi

APP_FLAG=""
[[ -n "$APP" ]] && APP_FLAG="--app $APP"

case "$ACTION" in
    set)
        if [[ ${#SECRETS[@]} -eq 0 ]]; then
            echo "$PREFIX No secrets provided. Usage: --set KEY1=VAL1 KEY2=VAL2"
            exit 1
        fi
        echo "$PREFIX Setting ${#SECRETS[@]} secret(s)..."
        fly secrets set "${SECRETS[@]}" $APP_FLAG
        echo "$PREFIX ✅ Secrets set (app will restart)"
        ;;
    unset)
        if [[ ${#SECRETS[@]} -eq 0 ]]; then
            echo "$PREFIX No secrets provided. Usage: --unset KEY1 KEY2"
            exit 1
        fi
        echo "$PREFIX Removing ${#SECRETS[@]} secret(s)..."
        fly secrets unset "${SECRETS[@]}" $APP_FLAG
        echo "$PREFIX ✅ Secrets removed (app will restart)"
        ;;
    list)
        echo "$PREFIX Current secrets:"
        fly secrets list $APP_FLAG
        ;;
    *)
        echo "$PREFIX Usage:"
        echo "  bash secrets.sh --set KEY1=VAL1 KEY2=VAL2 [--app NAME]"
        echo "  bash secrets.sh --list [--app NAME]"
        echo "  bash secrets.sh --unset KEY1 KEY2 [--app NAME]"
        exit 1
        ;;
esac
