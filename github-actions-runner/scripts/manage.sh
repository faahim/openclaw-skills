#!/bin/bash
# GitHub Actions Self-Hosted Runner — Management Script
# Usage: bash manage.sh <command> [options]

set -euo pipefail

RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner}"
META_FILE="$RUNNER_DIR/.runner-meta.json"

# --- Load metadata ---
load_meta() {
  if [ ! -f "$META_FILE" ]; then
    echo "❌ Runner not installed. Run install.sh first."
    exit 1
  fi
  SERVICE_NAME=$(jq -r .service "$META_FILE")
  RUNNER_NAME=$(jq -r .name "$META_FILE")
  RUNNER_URL=$(jq -r .url "$META_FILE")
  RUNNER_REPO=$(jq -r '.repo // ""' "$META_FILE")
  RUNNER_ORG=$(jq -r '.org // ""' "$META_FILE")
  INSTALLED_VERSION=$(jq -r .version "$META_FILE")
}

# --- Commands ---
cmd_start() {
  load_meta
  echo "▶️  Starting runner '$RUNNER_NAME'..."
  systemctl --user start "$SERVICE_NAME"
  sleep 2
  if systemctl --user is-active --quiet "$SERVICE_NAME"; then
    echo "✅ Runner is running"
  else
    echo "❌ Failed to start. Check logs: bash manage.sh logs"
    exit 1
  fi
}

cmd_stop() {
  load_meta
  echo "⏹️  Stopping runner '$RUNNER_NAME'..."
  systemctl --user stop "$SERVICE_NAME"
  echo "✅ Runner stopped"
}

cmd_restart() {
  load_meta
  echo "🔄 Restarting runner '$RUNNER_NAME'..."
  systemctl --user restart "$SERVICE_NAME"
  sleep 2
  if systemctl --user is-active --quiet "$SERVICE_NAME"; then
    echo "✅ Runner restarted"
  else
    echo "❌ Failed to restart. Check logs: bash manage.sh logs"
    exit 1
  fi
}

cmd_status() {
  load_meta

  echo "🏃 Runner: $RUNNER_NAME"
  echo "📂 Directory: $RUNNER_DIR"
  echo "📌 Version: $INSTALLED_VERSION"

  # Systemd status
  if systemctl --user is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    echo "📍 Service: ✅ running"
  else
    echo "📍 Service: ❌ stopped"
  fi

  # GitHub API status (if token available)
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    if [ -n "$RUNNER_REPO" ] && [ "$RUNNER_REPO" != "" ]; then
      RUNNERS=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${RUNNER_REPO}/actions/runners" 2>/dev/null)
    elif [ -n "$RUNNER_ORG" ] && [ "$RUNNER_ORG" != "" ]; then
      RUNNERS=$(curl -s \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/orgs/${RUNNER_ORG}/actions/runners" 2>/dev/null)
    fi

    if [ -n "${RUNNERS:-}" ]; then
      RUNNER_INFO=$(echo "$RUNNERS" | jq -r ".runners[] | select(.name == \"$RUNNER_NAME\")" 2>/dev/null || echo "")
      if [ -n "$RUNNER_INFO" ]; then
        GH_STATUS=$(echo "$RUNNER_INFO" | jq -r .status)
        BUSY=$(echo "$RUNNER_INFO" | jq -r .busy)
        LABELS=$(echo "$RUNNER_INFO" | jq -r '[.labels[].name] | join(", ")')
        echo "🌐 GitHub: $GH_STATUS"
        echo "💼 Busy: $BUSY"
        echo "🏷️  Labels: $LABELS"
      else
        echo "🌐 GitHub: runner not found (may need a moment to sync)"
      fi
    fi
  else
    echo "💡 Set GITHUB_TOKEN to see GitHub API status"
  fi
}

cmd_logs() {
  load_meta
  FOLLOW=""
  if [ "${1:-}" = "-f" ]; then
    FOLLOW="--follow"
  fi
  journalctl --user -u "$SERVICE_NAME" --no-pager -n 50 $FOLLOW
}

cmd_labels() {
  load_meta
  GITHUB_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN required for label management}"

  ACTION="${1:-list}"

  # Get runner ID
  if [ -n "$RUNNER_REPO" ] && [ "$RUNNER_REPO" != "" ]; then
    API_BASE="https://api.github.com/repos/${RUNNER_REPO}/actions/runners"
  else
    API_BASE="https://api.github.com/orgs/${RUNNER_ORG}/actions/runners"
  fi

  RUNNER_ID=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" "$API_BASE" \
    | jq -r ".runners[] | select(.name == \"$RUNNER_NAME\") | .id")

  if [ -z "$RUNNER_ID" ] || [ "$RUNNER_ID" = "null" ]; then
    echo "❌ Runner not found on GitHub"
    exit 1
  fi

  case "$ACTION" in
    list)
      curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "$API_BASE/$RUNNER_ID/labels" \
        | jq -r '.labels[].name'
      ;;
    add)
      LABELS="${2:?Usage: manage.sh labels add label1,label2}"
      IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
      LABEL_JSON=$(printf '%s\n' "${LABEL_ARRAY[@]}" | jq -R . | jq -s .)
      curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "$API_BASE/$RUNNER_ID/labels" \
        -d "{\"labels\": $LABEL_JSON}" \
        | jq -r '.labels[].name'
      echo "✅ Labels added"
      ;;
    remove)
      LABEL="${2:?Usage: manage.sh labels remove label-name}"
      curl -s -X DELETE \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "$API_BASE/$RUNNER_ID/labels/$LABEL" \
        | jq -r '.labels[].name'
      echo "✅ Label '$LABEL' removed"
      ;;
    *)
      echo "Usage: manage.sh labels [list|add|remove] [label]"
      exit 1
      ;;
  esac
}

cmd_update() {
  load_meta

  LATEST=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//')

  if [ "${1:-}" = "--check" ]; then
    if [ "$LATEST" = "$INSTALLED_VERSION" ]; then
      echo "✅ Up to date (v${INSTALLED_VERSION})"
    else
      echo "🆕 Update available: v${INSTALLED_VERSION} → v${LATEST}"
    fi
    return
  fi

  if [ "$LATEST" = "$INSTALLED_VERSION" ]; then
    echo "✅ Already at latest version (v${INSTALLED_VERSION})"
    return
  fi

  echo "🆕 Updating: v${INSTALLED_VERSION} → v${LATEST}"

  # Stop service
  systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true

  # Download new version
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  RUNNER_ARCH="x64" ;;
    aarch64) RUNNER_ARCH="arm64" ;;
  esac

  FILENAME="actions-runner-linux-${RUNNER_ARCH}-${LATEST}.tar.gz"
  cd "$RUNNER_DIR"
  curl -sL -o "$FILENAME" "https://github.com/actions/runner/releases/download/v${LATEST}/${FILENAME}"
  tar xzf "$FILENAME"

  # Update metadata
  jq ".version = \"$LATEST\"" "$META_FILE" > "${META_FILE}.tmp" && mv "${META_FILE}.tmp" "$META_FILE"

  # Restart
  systemctl --user start "$SERVICE_NAME"
  echo "✅ Updated to v${LATEST} and restarted"
}

cmd_remove() {
  load_meta
  GITHUB_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN required to unregister runner}"

  echo "🗑️  Removing runner '$RUNNER_NAME'..."

  # Stop service
  systemctl --user stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl --user disable "$SERVICE_NAME" 2>/dev/null || true
  rm -f "$HOME/.config/systemd/user/${SERVICE_NAME}.service"
  systemctl --user daemon-reload

  echo "✅ Removed systemd service"

  # Get removal token
  if [ -n "$RUNNER_REPO" ] && [ "$RUNNER_REPO" != "" ]; then
    REMOVE_TOKEN=$(curl -s -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${RUNNER_REPO}/actions/runners/remove-token" \
      | jq -r .token)
  else
    REMOVE_TOKEN=$(curl -s -X POST \
      -H "Authorization: token $GITHUB_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/orgs/${RUNNER_ORG}/actions/runners/remove-token" \
      | jq -r .token)
  fi

  cd "$RUNNER_DIR"
  ./config.sh remove --token "$REMOVE_TOKEN" 2>/dev/null || true
  echo "✅ Unregistered from GitHub"

  # Cleanup
  cd "$HOME"
  rm -rf "$RUNNER_DIR"
  echo "🧹 Cleaned up $RUNNER_DIR"

  echo "✅ Runner fully removed"
}

# --- Main ---
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  restart) cmd_restart ;;
  status)  cmd_status ;;
  logs)    cmd_logs "$@" ;;
  labels)  cmd_labels "$@" ;;
  update)  cmd_update "$@" ;;
  remove)  cmd_remove ;;
  help|*)
    echo "GitHub Actions Self-Hosted Runner Manager"
    echo ""
    echo "Usage: bash manage.sh <command>"
    echo ""
    echo "Commands:"
    echo "  start              Start the runner service"
    echo "  stop               Stop the runner service"
    echo "  restart            Restart the runner service"
    echo "  status             Show runner status (local + GitHub API)"
    echo "  logs [-f]          View logs (optionally follow)"
    echo "  labels list        List runner labels"
    echo "  labels add <l,l>   Add labels"
    echo "  labels remove <l>  Remove a label"
    echo "  update [--check]   Update runner to latest version"
    echo "  remove             Unregister and remove runner"
    ;;
esac
