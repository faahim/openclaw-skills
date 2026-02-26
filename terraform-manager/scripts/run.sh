#!/bin/bash
# Terraform Manager — Wrapper for common Terraform operations
set -euo pipefail

COMMAND=""
DIR="."
EXTRA_ARGS=()
ALERT=""
PLAN_FILE=""
AUTO_APPROVE=""

usage() {
  cat <<EOF
Usage: bash run.sh <command> [options]

Commands:
  version                Show Terraform version
  init                   Initialize Terraform project
  fmt                    Format Terraform files
  validate               Validate configuration
  plan                   Show execution plan
  apply                  Apply changes
  destroy                Destroy infrastructure
  drift                  Detect configuration drift
  graph                  Generate resource dependency graph
  import <type.name> <id> Import existing resource
  force-unlock <id>      Force unlock state
  workspace <sub>        Manage workspaces (list|new|select|delete)
  state <sub>            Manage state (list|show|rm|mv|pull|push)

Options:
  --dir <path>           Working directory (default: .)
  --out <file>           Save plan to file
  --plan <file>          Apply from saved plan file
  --auto-approve         Skip interactive approval
  --check                Check only (for fmt)
  --destroy              Plan destruction
  --alert <type>         Alert on drift (telegram)
EOF
  exit 1
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

check_terraform() {
  if ! command -v terraform &>/dev/null; then
    echo "❌ Terraform not found. Run: bash scripts/install.sh"
    exit 1
  fi
}

send_telegram_alert() {
  local msg="$1"
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" \
      -d "text=${msg}" \
      -d "parse_mode=Markdown" >/dev/null 2>&1
  else
    echo "⚠️ Telegram credentials not set (TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID)"
  fi
}

# Parse command
[[ $# -eq 0 ]] && usage
COMMAND="$1"; shift

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    --dir) DIR="$2"; shift 2 ;;
    --out) EXTRA_ARGS+=("-out" "$2"); PLAN_FILE="$2"; shift 2 ;;
    --plan) PLAN_FILE="$2"; shift 2 ;;
    --auto-approve) AUTO_APPROVE="-auto-approve"; shift ;;
    --check) EXTRA_ARGS+=("-check"); shift ;;
    --destroy) EXTRA_ARGS+=("-destroy"); shift ;;
    --alert) ALERT="$2"; shift 2 ;;
    *) EXTRA_ARGS+=("$1"); shift ;;
  esac
done

check_terraform
cd "$DIR"

case $COMMAND in
  version)
    terraform version
    ;;

  init)
    log "🔧 Initializing Terraform..."
    terraform init "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
    log "✅ Init complete"
    ;;

  fmt)
    log "📝 Formatting Terraform files..."
    terraform fmt -recursive "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}" .
    log "✅ Format complete"
    ;;

  validate)
    log "🔍 Validating configuration..."
    terraform validate "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
    log "✅ Configuration valid"
    ;;

  plan)
    log "🔍 Running terraform plan..."
    terraform plan "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
    ;;

  apply)
    if [[ -n "$PLAN_FILE" ]]; then
      log "🚀 Applying saved plan: $PLAN_FILE"
      terraform apply $AUTO_APPROVE "$PLAN_FILE"
    else
      log "🚀 Running terraform apply..."
      terraform apply $AUTO_APPROVE "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
    fi
    log "✅ Apply complete!"
    ;;

  destroy)
    log "💥 Running terraform destroy..."
    terraform destroy $AUTO_APPROVE "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
    log "✅ Destroy complete"
    ;;

  drift)
    log "🔍 Checking for drift..."
    PLAN_OUTPUT=$(terraform plan -detailed-exitcode -no-color 2>&1) || EXIT_CODE=$?
    EXIT_CODE=${EXIT_CODE:-0}

    if [[ $EXIT_CODE -eq 0 ]]; then
      log "✅ No drift detected — infrastructure matches configuration"
    elif [[ $EXIT_CODE -eq 2 ]]; then
      DRIFT_SUMMARY=$(echo "$PLAN_OUTPUT" | grep -E "^(Plan:|  [~+-])" | head -20)
      log "⚠️ DRIFT DETECTED:"
      echo "$DRIFT_SUMMARY"

      if [[ "$ALERT" == "telegram" ]]; then
        send_telegram_alert "⚠️ *Terraform Drift Detected*%0A%0A$(echo "$DRIFT_SUMMARY" | head -10)"
      fi
    else
      log "❌ Error checking drift:"
      echo "$PLAN_OUTPUT"
      exit 1
    fi
    ;;

  graph)
    terraform graph "${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}"
    ;;

  import)
    [[ ${#EXTRA_ARGS[@]} -lt 2 ]] && { echo "Usage: run.sh import <resource> <id> --dir <path>"; exit 1; }
    log "📥 Importing ${EXTRA_ARGS[0]} (${EXTRA_ARGS[1]})..."
    terraform import "${EXTRA_ARGS[0]}" "${EXTRA_ARGS[1]}"
    log "✅ Import complete"
    ;;

  force-unlock)
    [[ ${#EXTRA_ARGS[@]} -lt 1 ]] && { echo "Usage: run.sh force-unlock <lock-id> --dir <path>"; exit 1; }
    log "🔓 Force unlocking state (ID: ${EXTRA_ARGS[0]})..."
    terraform force-unlock -force "${EXTRA_ARGS[0]}"
    log "✅ State unlocked"
    ;;

  workspace)
    [[ ${#EXTRA_ARGS[@]} -lt 1 ]] && { echo "Usage: run.sh workspace <list|new|select|delete> [name]"; exit 1; }
    SUB="${EXTRA_ARGS[0]}"
    case $SUB in
      list)
        terraform workspace list
        ;;
      new|select|delete)
        [[ ${#EXTRA_ARGS[@]} -lt 2 ]] && { echo "Usage: run.sh workspace $SUB <name>"; exit 1; }
        terraform workspace "$SUB" "${EXTRA_ARGS[1]}"
        log "✅ Workspace '${EXTRA_ARGS[1]}' — $SUB done"
        ;;
      *) echo "Unknown workspace command: $SUB"; exit 1 ;;
    esac
    ;;

  state)
    [[ ${#EXTRA_ARGS[@]} -lt 1 ]] && { echo "Usage: run.sh state <list|show|rm|mv|pull|push> [args]"; exit 1; }
    SUB="${EXTRA_ARGS[0]}"
    REST=("${EXTRA_ARGS[@]:1}")
    case $SUB in
      list)
        terraform state list "${REST[@]+"${REST[@]}"}"
        ;;
      show)
        [[ ${#REST[@]} -lt 1 ]] && { echo "Usage: run.sh state show <resource>"; exit 1; }
        terraform state show "${REST[0]}"
        ;;
      rm)
        [[ ${#REST[@]} -lt 1 ]] && { echo "Usage: run.sh state rm <resource>"; exit 1; }
        terraform state rm "${REST[0]}"
        log "✅ Removed ${REST[0]} from state"
        ;;
      mv)
        [[ ${#REST[@]} -lt 2 ]] && { echo "Usage: run.sh state mv <source> <dest>"; exit 1; }
        terraform state mv "${REST[0]}" "${REST[1]}"
        log "✅ Moved ${REST[0]} → ${REST[1]}"
        ;;
      pull)
        terraform state pull
        ;;
      push)
        [[ ${#REST[@]} -lt 1 ]] && { echo "Usage: run.sh state push <file>"; exit 1; }
        terraform state push "${REST[0]}"
        log "✅ State pushed"
        ;;
      *) echo "Unknown state command: $SUB"; exit 1 ;;
    esac
    ;;

  *)
    echo "Unknown command: $COMMAND"
    usage
    ;;
esac
