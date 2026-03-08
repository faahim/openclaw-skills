#!/bin/bash
# Secret Rotation Manager v1.0
# Track, rotate, and audit API keys, tokens, and credentials.

set -euo pipefail

VAULT_DIR="${SECRET_ROTATION_DIR:-$HOME/.secret-rotation}"
VAULT_FILE="$VAULT_DIR/secrets/vault.json"
LOG_FILE="$VAULT_DIR/logs/rotation.log"
BACKUP_DIR="$VAULT_DIR/backups"
DEFAULT_EXPIRY="${SECRET_ROTATION_DEFAULT_EXPIRY:-90}"
DEFAULT_LENGTH="${SECRET_ROTATION_DEFAULT_LENGTH:-32}"
ENCRYPT_KEY="${SECRET_ROTATION_ENCRYPT_KEY:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ─── Helpers ────────────────────────────────────────────

log_audit() {
  local action="$1" name="$2" detail="${3:-}"
  local ts
  ts=$(date -u '+%Y-%m-%d %H:%M:%S')
  echo "$ts | $action | $name | $detail" >> "$LOG_FILE"
}

ensure_dirs() {
  mkdir -p "$VAULT_DIR/secrets" "$VAULT_DIR/logs" "$BACKUP_DIR"
  chmod 700 "$VAULT_DIR"
  if [ ! -f "$VAULT_FILE" ]; then
    echo '{"secrets":[],"rotations":[]}' > "$VAULT_FILE"
    chmod 600 "$VAULT_FILE"
  fi
}

days_until() {
  local expiry="$1"
  local now_epoch expiry_epoch
  now_epoch=$(date -u +%s)
  expiry_epoch=$(date -u -d "$expiry" +%s 2>/dev/null || date -u -j -f "%Y-%m-%d" "$expiry" +%s 2>/dev/null)
  echo $(( (expiry_epoch - now_epoch) / 86400 ))
}

generate_password() {
  local length="${1:-$DEFAULT_LENGTH}"
  local chars="${2:-A-Za-z0-9!@#\$%^&*}"
  openssl rand -base64 $((length * 2)) | tr -dc "$chars" | head -c "$length"
  echo
}

generate_ssh_key() {
  local name="$1"
  local key_file="$VAULT_DIR/secrets/${name}_id_ed25519"
  ssh-keygen -t ed25519 -f "$key_file" -N "" -q
  echo "$key_file"
}

encrypt_value() {
  local value="$1" outfile="$2"
  if [ -n "$ENCRYPT_KEY" ]; then
    echo "$value" | openssl enc -aes-256-cbc -salt -pbkdf2 -pass "pass:$ENCRYPT_KEY" -out "$outfile" 2>/dev/null
  else
    echo "$value" > "$outfile"
  fi
  chmod 600 "$outfile"
}

decrypt_file() {
  local infile="$1"
  if [ -n "$ENCRYPT_KEY" ]; then
    openssl enc -aes-256-cbc -d -salt -pbkdf2 -pass "pass:$ENCRYPT_KEY" -in "$infile" 2>/dev/null
  else
    cat "$infile"
  fi
}

update_env_files() {
  local var_name="$1" new_value="$2"
  shift 2
  local env_files=("$@")
  for f in "${env_files[@]}"; do
    if [ -f "$f" ]; then
      if grep -q "^${var_name}=" "$f"; then
        sed -i "s|^${var_name}=.*|${var_name}=\"${new_value}\"|" "$f"
      else
        echo "${var_name}=\"${new_value}\"" >> "$f"
      fi
    fi
  done
}

send_alert() {
  local message="$1"
  # Webhook
  local webhook="${SECRET_ROTATION_WEBHOOK:-}"
  if [ -n "$webhook" ]; then
    curl -s -X POST "$webhook" \
      -H "Content-Type: application/json" \
      -d "{\"text\":\"$message\"}" > /dev/null 2>&1 || true
  fi
  # Telegram
  local tg_token="${SECRET_ROTATION_TELEGRAM_TOKEN:-}"
  local tg_chat="${SECRET_ROTATION_TELEGRAM_CHAT:-}"
  if [ -n "$tg_token" ] && [ -n "$tg_chat" ]; then
    curl -s "https://api.telegram.org/bot${tg_token}/sendMessage" \
      -d "chat_id=${tg_chat}" \
      -d "text=${message}" \
      -d "parse_mode=Markdown" > /dev/null 2>&1 || true
  fi
}

# ─── Commands ───────────────────────────────────────────

cmd_add() {
  local name="" service="" type="api-key" value="" expires="" warn_days=14
  local env_var="" env_files=()

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --service) service="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --value) value="$2"; shift 2 ;;
      --expires) expires="$2"; shift 2 ;;
      --warn-days) warn_days="$2"; shift 2 ;;
      --env-var) env_var="$2"; shift 2 ;;
      --env-file) env_files+=("$2"); shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$name" ] && { echo "Error: --name required"; exit 1; }
  [ -z "$value" ] && { echo "Error: --value required"; exit 1; }

  # Check for duplicate
  local existing
  existing=$(jq -r --arg n "$name" '.secrets[] | select(.name == $n) | .name' "$VAULT_FILE")
  if [ -n "$existing" ]; then
    echo "Error: Secret '$name' already exists. Use 'rotate' to update."
    exit 1
  fi

  # If no expiry set, default to DEFAULT_EXPIRY days from now
  if [ -z "$expires" ]; then
    expires=$(date -u -d "+${DEFAULT_EXPIRY} days" '+%Y-%m-%d' 2>/dev/null || date -u -v+${DEFAULT_EXPIRY}d '+%Y-%m-%d')
  fi

  local created_at
  created_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  # Store value (obfuscated in vault, only last 4 chars visible)
  local value_hint
  value_hint="***${value: -4}"

  local env_files_json
  env_files_json=$(printf '%s\n' "${env_files[@]}" 2>/dev/null | jq -R . | jq -s . 2>/dev/null || echo '[]')

  local secret_obj
  secret_obj=$(jq -n \
    --arg name "$name" \
    --arg service "$service" \
    --arg type "$type" \
    --arg hint "$value_hint" \
    --arg expires "$expires" \
    --argjson warn_days "$warn_days" \
    --arg env_var "$env_var" \
    --argjson env_files "$env_files_json" \
    --arg created_at "$created_at" \
    '{name: $name, service: $service, type: $type, value_hint: $hint, expires: $expires, warn_days: $warn_days, env_var: $env_var, env_files: $env_files, created_at: $created_at, last_rotated: $created_at}')

  # Add to vault
  jq --argjson obj "$secret_obj" '.secrets += [$obj]' "$VAULT_FILE" > "${VAULT_FILE}.tmp"
  mv "${VAULT_FILE}.tmp" "$VAULT_FILE"
  chmod 600 "$VAULT_FILE"

  # Store actual value in encrypted backup
  encrypt_value "$value" "$BACKUP_DIR/${name}.current.enc"

  log_audit "CREATED" "$name" "type=$type service=$service expires=$expires"
  echo -e "${GREEN}✅ Added secret '$name' (${type}) — expires $expires${NC}"
}

cmd_status() {
  local format="${1:-table}"
  local secrets
  secrets=$(jq -r '.secrets' "$VAULT_FILE")
  local count
  count=$(echo "$secrets" | jq 'length')

  if [ "$count" -eq 0 ]; then
    echo "No secrets tracked. Use 'add' to register one."
    return
  fi

  if [ "$format" = "json" ]; then
    echo "$secrets" | jq -r '.[] | . + {days_left: 0}' | while IFS= read -r line; do
      echo "$line"
    done
    return
  fi

  # Table output
  printf "┌─────────────────────┬──────────────┬────────────┬──────────────┬───────────┐\n"
  printf "│ %-19s │ %-12s │ %-10s │ %-12s │ %-9s │\n" "Name" "Service" "Type" "Expires" "Status"
  printf "├─────────────────────┼──────────────┼────────────┼──────────────┼───────────┤\n"

  echo "$secrets" | jq -c '.[]' | while IFS= read -r secret; do
    local name service type expires warn_days
    name=$(echo "$secret" | jq -r '.name')
    service=$(echo "$secret" | jq -r '.service')
    type=$(echo "$secret" | jq -r '.type')
    expires=$(echo "$secret" | jq -r '.expires')
    warn_days=$(echo "$secret" | jq -r '.warn_days')

    local days_left status
    days_left=$(days_until "$expires")

    if [ "$days_left" -lt 0 ]; then
      status="❌ EXPIRED"
    elif [ "$days_left" -le "$warn_days" ]; then
      status="⚠️  ${days_left}d"
    else
      status="✅ OK"
    fi

    printf "│ %-19s │ %-12s │ %-10s │ %-12s │ %-9s │\n" \
      "${name:0:19}" "${service:0:12}" "${type:0:10}" "$expires" "$status"
  done

  printf "└─────────────────────┴──────────────┴────────────┴──────────────┴───────────┘\n"
}

cmd_check() {
  local warn_days="${1:-14}" alert_mode="${2:-}" webhook_url="${3:-}"
  local alerts=()

  jq -c '.secrets[]' "$VAULT_FILE" | while IFS= read -r secret; do
    local name service expires secret_warn
    name=$(echo "$secret" | jq -r '.name')
    service=$(echo "$secret" | jq -r '.service')
    expires=$(echo "$secret" | jq -r '.expires')
    secret_warn=$(echo "$secret" | jq -r '.warn_days')

    local days_left
    days_left=$(days_until "$expires")

    if [ "$days_left" -lt 0 ]; then
      local msg="❌ ${name} (${service}) EXPIRED $(( days_left * -1 )) days ago (${expires})"
      echo -e "${RED}${msg}${NC}"
      [ "$alert_mode" = "webhook" ] && send_alert "$msg"
    elif [ "$days_left" -le "$warn_days" ]; then
      local msg="⚠️  ${name} (${service}) expires in ${days_left} days (${expires})"
      echo -e "${YELLOW}${msg}${NC}"
      [ "$alert_mode" = "webhook" ] && send_alert "$msg"
    fi
  done
}

cmd_rotate() {
  local name="" length="$DEFAULT_LENGTH" chars='A-Za-z0-9!@#$%^&*'

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --length) length="$2"; shift 2 ;;
      --chars) chars="$2"; shift 2 ;;
      --value) new_value="$2"; shift 2 ;;
      *) echo "Unknown option: $1"; exit 1 ;;
    esac
  done

  [ -z "$name" ] && { echo "Error: --name required"; exit 1; }

  # Get current secret
  local secret
  secret=$(jq -r --arg n "$name" '.secrets[] | select(.name == $n)' "$VAULT_FILE")
  [ -z "$secret" ] && { echo "Error: Secret '$name' not found"; exit 1; }

  local type env_var
  type=$(echo "$secret" | jq -r '.type')
  env_var=$(echo "$secret" | jq -r '.env_var')
  local env_files_arr
  env_files_arr=$(echo "$secret" | jq -r '.env_files[]' 2>/dev/null)

  # Backup old value
  local today
  today=$(date -u '+%Y-%m-%d')
  if [ -f "$BACKUP_DIR/${name}.current.enc" ]; then
    cp "$BACKUP_DIR/${name}.current.enc" "$BACKUP_DIR/${name}.${today}.enc"
  fi

  # Generate or use provided new value
  local new_value="${new_value:-}"
  if [ -z "$new_value" ]; then
    case "$type" in
      password|webhook-secret)
        new_value=$(generate_password "$length" "$chars")
        ;;
      ssh-key)
        new_value=$(generate_ssh_key "$name")
        ;;
      *)
        echo "Error: Cannot auto-generate for type '$type'. Use --value to provide new value."
        exit 1
        ;;
    esac
  fi

  # Store new value
  encrypt_value "$new_value" "$BACKUP_DIR/${name}.current.enc"

  # Update hint
  local new_hint="***${new_value: -4}"

  # Calculate new expiry
  local new_expiry
  new_expiry=$(date -u -d "+${DEFAULT_EXPIRY} days" '+%Y-%m-%d' 2>/dev/null || date -u -v+${DEFAULT_EXPIRY}d '+%Y-%m-%d')
  local now
  now=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  # Update vault
  jq --arg n "$name" --arg hint "$new_hint" --arg exp "$new_expiry" --arg now "$now" \
    '(.secrets[] | select(.name == $n)) |= . + {value_hint: $hint, expires: $exp, last_rotated: $now}' \
    "$VAULT_FILE" > "${VAULT_FILE}.tmp"
  mv "${VAULT_FILE}.tmp" "$VAULT_FILE"
  chmod 600 "$VAULT_FILE"

  # Update env files
  if [ -n "$env_var" ] && [ "$env_var" != "null" ]; then
    local files_array=()
    while IFS= read -r f; do
      [ -n "$f" ] && files_array+=("$f")
    done <<< "$env_files_arr"
    if [ ${#files_array[@]} -gt 0 ]; then
      update_env_files "$env_var" "$new_value" "${files_array[@]}"
      echo -e "${BLUE}   Updated env files (${env_var})${NC}"
    fi
  fi

  # Add rotation record
  jq --arg n "$name" --arg now "$now" --arg exp "$new_expiry" \
    '.rotations += [{"name": $n, "rotated_at": $now, "new_expiry": $exp}]' \
    "$VAULT_FILE" > "${VAULT_FILE}.tmp"
  mv "${VAULT_FILE}.tmp" "$VAULT_FILE"
  chmod 600 "$VAULT_FILE"

  log_audit "ROTATED" "$name" "new expiry=$new_expiry"

  echo -e "${GREEN}🔄 Rotated '${name}'${NC}"
  echo -e "   Old value backed up to ${BACKUP_DIR}/${name}.${today}.enc"
  if [ "$type" = "ssh-key" ]; then
    echo -e "   New SSH key: ${new_value}"
  else
    echo -e "   New value generated (${#new_value} chars)"
  fi
  echo -e "   New expiry: ${new_expiry} (${DEFAULT_EXPIRY} days)"
}

cmd_audit() {
  local name="" all=false format="text"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name) name="$2"; shift 2 ;;
      --all) all=true; shift ;;
      --format) format="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [ "$format" = "json" ]; then
    if [ -n "$name" ]; then
      grep "| $name |" "$LOG_FILE" 2>/dev/null | jq -R 'split(" | ") | {timestamp: .[0], action: .[1], name: .[2], detail: .[3]}' | jq -s .
    else
      cat "$LOG_FILE" 2>/dev/null | jq -R 'split(" | ") | {timestamp: .[0], action: .[1], name: .[2], detail: .[3]}' | jq -s .
    fi
    return
  fi

  if [ -n "$name" ]; then
    echo -e "${BLUE}Audit log for: $name${NC}"
    grep "| $name |" "$LOG_FILE" 2>/dev/null || echo "No entries found."
  elif $all; then
    echo -e "${BLUE}Full audit log:${NC}"
    cat "$LOG_FILE" 2>/dev/null || echo "No entries found."
  else
    echo -e "${BLUE}Recent audit entries (last 20):${NC}"
    tail -20 "$LOG_FILE" 2>/dev/null || echo "No entries found."
  fi
}

cmd_report() {
  local format="${1:-markdown}"

  local today
  today=$(date -u '+%Y-%m-%d')

  if [ "$format" = "csv" ]; then
    echo "Name,Service,Type,Expires,Days Left,Status,Last Rotated"
    jq -c '.secrets[]' "$VAULT_FILE" | while IFS= read -r secret; do
      local name service type expires days_left status last_rotated
      name=$(echo "$secret" | jq -r '.name')
      service=$(echo "$secret" | jq -r '.service')
      type=$(echo "$secret" | jq -r '.type')
      expires=$(echo "$secret" | jq -r '.expires')
      last_rotated=$(echo "$secret" | jq -r '.last_rotated')
      days_left=$(days_until "$expires")
      [ "$days_left" -lt 0 ] && status="EXPIRED" || status="OK"
      echo "$name,$service,$type,$expires,$days_left,$status,$last_rotated"
    done
    return
  fi

  # Markdown report
  echo "# Secrets Inventory Report"
  echo ""
  echo "**Generated:** $today"
  echo ""
  local total expired warning ok
  total=$(jq '.secrets | length' "$VAULT_FILE")
  echo "**Total secrets tracked:** $total"
  echo ""
  echo "| Name | Service | Type | Expires | Days Left | Status |"
  echo "|------|---------|------|---------|-----------|--------|"

  jq -c '.secrets[]' "$VAULT_FILE" | while IFS= read -r secret; do
    local name service type expires days_left status
    name=$(echo "$secret" | jq -r '.name')
    service=$(echo "$secret" | jq -r '.service')
    type=$(echo "$secret" | jq -r '.type')
    expires=$(echo "$secret" | jq -r '.expires')
    days_left=$(days_until "$expires")
    [ "$days_left" -lt 0 ] && status="❌ EXPIRED" || { [ "$days_left" -le 14 ] && status="⚠️ Warning" || status="✅ OK"; }
    echo "| $name | $service | $type | $expires | $days_left | $status |"
  done
}

cmd_import() {
  local env_file="" service="" default_expiry="$DEFAULT_EXPIRY"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --env-file) env_file="$2"; shift 2 ;;
      --service) service="$2"; shift 2 ;;
      --default-expiry) default_expiry="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [ -z "$env_file" ] && { echo "Error: --env-file required"; exit 1; }
  [ ! -f "$env_file" ] && { echo "Error: File not found: $env_file"; exit 1; }

  local count=0
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ ]] && continue
    [[ -z "$line" ]] && continue

    local key value
    key=$(echo "$line" | cut -d= -f1 | tr -d ' "'"'")
    value=$(echo "$line" | cut -d= -f2- | tr -d '"'"'")

    # Skip if already tracked
    local existing
    existing=$(jq -r --arg n "$key" '.secrets[] | select(.name == $n) | .name' "$VAULT_FILE")
    [ -n "$existing" ] && continue

    local expires
    expires=$(date -u -d "+${default_expiry} days" '+%Y-%m-%d' 2>/dev/null || date -u -v+${default_expiry}d '+%Y-%m-%d')

    cmd_add --name "$key" --service "${service:-imported}" --type "api-key" \
      --value "$value" --expires "$expires" --env-var "$key" --env-file "$env_file"

    count=$((count + 1))
  done < "$env_file"

  echo -e "${GREEN}Imported $count secrets from $env_file${NC}"
}

cmd_remove() {
  local name="$1"
  [ -z "$name" ] && { echo "Error: name required"; exit 1; }

  jq --arg n "$name" '.secrets = [.secrets[] | select(.name != $n)]' "$VAULT_FILE" > "${VAULT_FILE}.tmp"
  mv "${VAULT_FILE}.tmp" "$VAULT_FILE"
  chmod 600 "$VAULT_FILE"

  log_audit "REMOVED" "$name" "manually deleted"
  echo -e "${YELLOW}🗑️  Removed secret '$name'${NC}"
}

cmd_decrypt_backup() {
  local file="$1"
  [ -z "$file" ] && { echo "Error: --file required"; exit 1; }
  [ ! -f "$file" ] && { echo "Error: File not found: $file"; exit 1; }
  decrypt_file "$file"
}

# ─── Main ───────────────────────────────────────────────

ensure_dirs

case "${1:-help}" in
  add)      shift; cmd_add "$@" ;;
  status)   shift; cmd_status "${1:-table}" ;;
  check)
    shift
    warn_days=14; alert_mode=""; webhook_url=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --warn-days) warn_days="$2"; shift 2 ;;
        --alert) alert_mode="$2"; shift 2 ;;
        --webhook-url) webhook_url="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    cmd_check "$warn_days" "$alert_mode" "$webhook_url"
    ;;
  rotate)   shift; cmd_rotate "$@" ;;
  audit)    shift; cmd_audit "$@" ;;
  report)   shift; cmd_report "${1:-markdown}" ;;
  import)   shift; cmd_import "$@" ;;
  remove)   shift; cmd_remove "$@" ;;
  decrypt-backup) shift; cmd_decrypt_backup "$@" ;;
  config)
    shift
    while [[ $# -gt 0 ]]; do
      case $1 in
        --encrypt-backups)
          if [ "$2" = "on" ]; then
            echo "Backup encryption enabled. Set SECRET_ROTATION_ENCRYPT_KEY in your environment."
          else
            echo "Backup encryption disabled."
          fi
          shift 2 ;;
        *) shift ;;
      esac
    done
    ;;
  help|--help|-h)
    echo "Secret Rotation Manager v1.0"
    echo ""
    echo "Usage: rotate.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  add        Add a new secret to track"
    echo "  status     Show all secrets and their health"
    echo "  check      Check for expiring/expired secrets"
    echo "  rotate     Rotate a secret (generate new value)"
    echo "  audit      View rotation audit trail"
    echo "  report     Generate secrets inventory report"
    echo "  import     Import secrets from .env file"
    echo "  remove     Remove a secret from tracking"
    echo "  decrypt-backup  Decrypt a backup file"
    echo "  help       Show this help"
    echo ""
    echo "Environment:"
    echo "  SECRET_ROTATION_DIR           Base directory (default: ~/.secret-rotation)"
    echo "  SECRET_ROTATION_WEBHOOK       Webhook URL for alerts"
    echo "  SECRET_ROTATION_TELEGRAM_TOKEN  Telegram bot token"
    echo "  SECRET_ROTATION_TELEGRAM_CHAT   Telegram chat ID"
    echo "  SECRET_ROTATION_DEFAULT_EXPIRY  Default expiry days (default: 90)"
    echo "  SECRET_ROTATION_DEFAULT_LENGTH  Default password length (default: 32)"
    echo "  SECRET_ROTATION_ENCRYPT_KEY     Encryption key for backups"
    ;;
  *)
    echo "Unknown command: $1. Use 'help' for usage."
    exit 1
    ;;
esac
