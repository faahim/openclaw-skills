#!/bin/bash
# Tailscale ACL Manager — View and apply access control policies
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[acl]${NC} $1"; }
warn() { echo -e "${YELLOW}[acl]${NC} $1"; }
err() { echo -e "${RED}[acl]${NC} $1" >&2; }

# Check required env vars
if [[ -z "${TAILSCALE_API_KEY:-}" ]]; then
    err "TAILSCALE_API_KEY not set"
    echo "Get one at: https://login.tailscale.com/admin/settings/keys"
    echo "export TAILSCALE_API_KEY='tskey-api-xxxx'"
    exit 1
fi

if [[ -z "${TAILSCALE_TAILNET:-}" ]]; then
    err "TAILSCALE_TAILNET not set"
    echo "export TAILSCALE_TAILNET='your-domain.com'"
    exit 1
fi

API_BASE="https://api.tailscale.com/api/v2"
AUTH_HEADER="Authorization: Bearer $TAILSCALE_API_KEY"

ACTION="${1:-help}"

case "$ACTION" in
    view|get)
        log "Fetching ACL policy for tailnet: $TAILSCALE_TAILNET"
        curl -sf \
            -H "$AUTH_HEADER" \
            "$API_BASE/tailnet/$TAILSCALE_TAILNET/acl" | jq .
        ;;
    
    apply|set)
        ACL_FILE="${2:-}"
        if [[ -z "$ACL_FILE" || ! -f "$ACL_FILE" ]]; then
            err "Usage: $0 apply <acl-policy.json>"
            exit 1
        fi
        
        # Validate JSON
        if ! jq . "$ACL_FILE" &>/dev/null; then
            err "Invalid JSON in $ACL_FILE"
            exit 1
        fi
        
        log "Applying ACL policy from: $ACL_FILE"
        RESPONSE=$(curl -sf \
            -X POST \
            -H "$AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d @"$ACL_FILE" \
            "$API_BASE/tailnet/$TAILSCALE_TAILNET/acl" 2>&1)
        
        if [[ $? -eq 0 ]]; then
            log "✅ ACL policy applied successfully"
        else
            err "❌ Failed to apply ACL policy"
            echo "$RESPONSE"
            exit 1
        fi
        ;;
    
    validate|test)
        ACL_FILE="${2:-}"
        if [[ -z "$ACL_FILE" || ! -f "$ACL_FILE" ]]; then
            err "Usage: $0 validate <acl-policy.json>"
            exit 1
        fi
        
        log "Validating ACL policy: $ACL_FILE"
        RESPONSE=$(curl -sf \
            -X POST \
            -H "$AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d @"$ACL_FILE" \
            "$API_BASE/tailnet/$TAILSCALE_TAILNET/acl/validate" 2>&1)
        
        if echo "$RESPONSE" | jq -e '.message == ""' &>/dev/null 2>&1; then
            log "✅ ACL policy is valid"
        else
            warn "Validation result:"
            echo "$RESPONSE" | jq .
        fi
        ;;
    
    devices|list)
        log "Listing devices on tailnet: $TAILSCALE_TAILNET"
        curl -sf \
            -H "$AUTH_HEADER" \
            "$API_BASE/tailnet/$TAILSCALE_TAILNET/devices" | jq '.devices[] | {name: .name, hostname: .hostname, addresses: .addresses, os: .os, online: .online, lastSeen: .lastSeen}'
        ;;
    
    keys)
        log "Listing auth keys for tailnet: $TAILSCALE_TAILNET"
        curl -sf \
            -H "$AUTH_HEADER" \
            "$API_BASE/tailnet/$TAILSCALE_TAILNET/keys" | jq .
        ;;
    
    create-key)
        REUSABLE="${2:-false}"
        EPHEMERAL="${3:-false}"
        TAGS="${4:-}"
        
        BODY=$(jq -n \
            --argjson reusable "$REUSABLE" \
            --argjson ephemeral "$EPHEMERAL" \
            '{capabilities: {devices: {create: {reusable: $reusable, ephemeral: $ephemeral}}}}')
        
        if [[ -n "$TAGS" ]]; then
            BODY=$(echo "$BODY" | jq --arg tags "$TAGS" '.capabilities.devices.create.tags = ($tags | split(","))')
        fi
        
        log "Creating auth key (reusable=$REUSABLE, ephemeral=$EPHEMERAL)..."
        curl -sf \
            -X POST \
            -H "$AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d "$BODY" \
            "$API_BASE/tailnet/$TAILSCALE_TAILNET/keys" | jq .
        ;;
    
    help|*)
        echo "Tailscale ACL Manager"
        echo ""
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  view              View current ACL policy"
        echo "  apply <file>      Apply ACL policy from JSON file"
        echo "  validate <file>   Validate ACL policy without applying"
        echo "  devices           List all devices on tailnet"
        echo "  keys              List auth keys"
        echo "  create-key [reusable] [ephemeral] [tags]"
        echo "                    Create a new auth key"
        echo ""
        echo "Environment:"
        echo "  TAILSCALE_API_KEY    API key from Tailscale admin"
        echo "  TAILSCALE_TAILNET    Your tailnet name (e.g., example.com)"
        ;;
esac
