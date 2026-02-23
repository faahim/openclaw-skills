#!/bin/bash
# Grafana Dashboard Manager — API Key Management
set -euo pipefail

GRAFANA_URL="${GRAFANA_URL:-http://localhost:3000}"
GRAFANA_USER="${GRAFANA_USER:-admin}"
GRAFANA_PASS="${GRAFANA_PASS:-admin}"

cmd_create() {
  local name="openclaw" role="Admin"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --role) role="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  local payload
  payload=$(jq -n --arg name "$name" --arg role "$role" '{name: $name, role: $role}')

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -H "Content-Type: application/json" \
    -X POST "${GRAFANA_URL}/api/auth/keys" \
    -d "$payload")

  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    local key
    key=$(echo "$body" | jq -r '.key')
    echo "✅ API key created: $name ($role)"
    echo ""
    echo "export GRAFANA_API_KEY=\"$key\""
    echo ""
    echo "Add this to ~/.bashrc or ~/.openclaw/env"
  else
    echo "❌ Failed: $body"
    exit 1
  fi
}

cmd_list() {
  local response
  response=$(curl -s -w "\n%{http_code}" \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    "${GRAFANA_URL}/api/auth/keys")

  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "$body" | jq -r '.[] | "[\(.id)] \(.name) (\(.role))"'
  else
    echo "❌ Failed: $body"
    exit 1
  fi
}

cmd_delete() {
  local id=""
  while [[ $# -gt 0 ]]; do
    case $1 in
      --id) id="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [[ -z "$id" ]] && { echo "Usage: $0 delete --id KEY_ID"; exit 1; }

  local response
  response=$(curl -s -w "\n%{http_code}" \
    -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
    -X DELETE "${GRAFANA_URL}/api/auth/keys/${id}")

  local http_code body
  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  if [[ "$http_code" == "200" ]]; then
    echo "✅ API key $id deleted"
  else
    echo "❌ Failed: $body"
    exit 1
  fi
}

ACTION="${1:-}"
shift || true

case "$ACTION" in
  create) cmd_create "$@" ;;
  list) cmd_list ;;
  delete) cmd_delete "$@" ;;
  *)
    echo "Usage: $0 {create|list|delete} [options]"
    echo ""
    echo "Commands:"
    echo "  create  Create API key (--name, --role Admin|Editor|Viewer)"
    echo "  list    List all API keys"
    echo "  delete  Delete an API key (--id)"
    exit 1
    ;;
esac
