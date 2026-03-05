#!/bin/bash
# Navidrome Service Manager
# Manage the Navidrome music server (start/stop/restart/update/backup/restore)

set -euo pipefail

INSTALL_DIR="/opt/navidrome"
DATA_DIR="/var/lib/navidrome"
SERVICE_NAME="navidrome"
CONFIG_FILE="${DATA_DIR}/navidrome.toml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[navidrome]${NC} $1"; }
warn() { echo -e "${YELLOW}[navidrome]${NC} $1"; }
err() { echo -e "${RED}[navidrome]${NC} $1" >&2; }
info() { echo -e "${CYAN}[navidrome]${NC} $1"; }

SUDO=""
[[ $EUID -ne 0 ]] && command -v sudo &>/dev/null && SUDO="sudo"

ACTION="${1:-help}"
shift 2>/dev/null || true

case "$ACTION" in
  status)
    echo ""
    if [[ -f "${INSTALL_DIR}/navidrome" ]]; then
      VER=$("${INSTALL_DIR}/navidrome" --version 2>/dev/null | head -1 || echo "unknown")
      log "Version: ${VER}"
    else
      err "Navidrome not installed at ${INSTALL_DIR}"
      exit 1
    fi

    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
      log "Service: ✅ running"
      PID=$(systemctl show -p MainPID "$SERVICE_NAME" | cut -d= -f2)
      if [[ "$PID" != "0" ]]; then
        MEM=$(ps -o rss= -p "$PID" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
        log "Memory:  ${MEM}"
      fi
    else
      warn "Service: ❌ stopped"
    fi

    if [[ -f "$CONFIG_FILE" ]]; then
      MUSIC=$(grep -E "^MusicFolder" "$CONFIG_FILE" | sed 's/.*= *"//' | sed 's/"//' || echo "not set")
      PORT=$(grep -E "^Port" "$CONFIG_FILE" | sed 's/.*= *//' || echo "4533")
      log "Music:   ${MUSIC}"
      log "Port:    ${PORT}"
      log "URL:     http://localhost:${PORT}"
      log "Config:  ${CONFIG_FILE}"
    fi

    if [[ -d "$DATA_DIR" ]]; then
      DB_SIZE=$(du -sh "${DATA_DIR}/navidrome.db" 2>/dev/null | cut -f1 || echo "N/A")
      log "DB size: ${DB_SIZE}"
    fi
    echo ""
    ;;

  start)
    log "Starting Navidrome..."
    $SUDO systemctl start "$SERVICE_NAME"
    sleep 1
    if systemctl is-active --quiet "$SERVICE_NAME"; then
      log "✅ Navidrome started"
    else
      err "Failed to start. Check: sudo journalctl -u navidrome -n 20"
    fi
    ;;

  stop)
    log "Stopping Navidrome..."
    $SUDO systemctl stop "$SERVICE_NAME"
    log "✅ Navidrome stopped"
    ;;

  restart)
    log "Restarting Navidrome..."
    $SUDO systemctl restart "$SERVICE_NAME"
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
      log "✅ Navidrome restarted"
    else
      err "Failed to restart. Check: sudo journalctl -u navidrome -n 20"
    fi
    ;;

  logs)
    FOLLOW=""
    LINES=50
    for arg in "$@"; do
      case "$arg" in
        -f|--follow) FOLLOW="-f" ;;
        *) LINES="$arg" ;;
      esac
    done
    $SUDO journalctl -u "$SERVICE_NAME" -n "$LINES" $FOLLOW --no-pager
    ;;

  scan)
    PORT=$(grep -E "^Port" "$CONFIG_FILE" 2>/dev/null | sed 's/.*= *//' || echo "4533")
    log "Triggering library scan..."
    # Navidrome rescans on SIGHUP or via API
    $SUDO systemctl kill -s HUP "$SERVICE_NAME" 2>/dev/null || {
      warn "Could not send HUP signal. Restarting service instead..."
      $SUDO systemctl restart "$SERVICE_NAME"
    }
    log "✅ Scan triggered"
    ;;

  update)
    VERSION=""
    for arg in "$@"; do
      case "$arg" in
        --version) shift; VERSION="$1" ;;
        *) VERSION="$arg" ;;
      esac
    done

    # Get current version
    CURRENT=$("${INSTALL_DIR}/navidrome" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "0.0.0")

    # Get latest if not specified
    if [[ -z "$VERSION" ]]; then
      VERSION=$(curl -s "https://api.github.com/repos/navidrome/navidrome/releases/latest" | grep '"tag_name"' | sed -E 's/.*"v([^"]+)".*/\1/')
    fi

    if [[ "$CURRENT" == "$VERSION" ]]; then
      log "Already running v${VERSION}. Nothing to update."
      exit 0
    fi

    log "Updating from v${CURRENT} to v${VERSION}..."

    # Detect arch
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64)  ARCH="amd64" ;;
      aarch64) ARCH="arm64" ;;
      armv7l)  ARCH="armv7" ;;
      armv6l)  ARCH="armv6" ;;
    esac
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    DOWNLOAD_URL="https://github.com/navidrome/navidrome/releases/download/v${VERSION}/navidrome_${VERSION}_${OS}_${ARCH}.tar.gz"
    TMPFILE=$(mktemp)

    curl -fSL "$DOWNLOAD_URL" -o "$TMPFILE" || {
      err "Download failed"; rm -f "$TMPFILE"; exit 1
    }

    log "Stopping service..."
    $SUDO systemctl stop "$SERVICE_NAME"

    # Backup current binary
    $SUDO cp "${INSTALL_DIR}/navidrome" "${INSTALL_DIR}/navidrome.bak"

    log "Installing new version..."
    $SUDO tar -xzf "$TMPFILE" -C "$INSTALL_DIR" navidrome
    $SUDO chmod +x "${INSTALL_DIR}/navidrome"
    rm -f "$TMPFILE"

    $SUDO systemctl start "$SERVICE_NAME"
    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
      NEW=$("${INSTALL_DIR}/navidrome" --version 2>/dev/null | head -1)
      log "✅ Updated to ${NEW}"
      $SUDO rm -f "${INSTALL_DIR}/navidrome.bak"
    else
      err "New version failed to start. Rolling back..."
      $SUDO mv "${INSTALL_DIR}/navidrome.bak" "${INSTALL_DIR}/navidrome"
      $SUDO systemctl start "$SERVICE_NAME"
      err "Rolled back to v${CURRENT}"
      exit 1
    fi
    ;;

  backup)
    BACKUP_DIR="${1:-.}"
    TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
    BACKUP_FILE="${BACKUP_DIR}/navidrome-backup-${TIMESTAMP}.tar.gz"

    log "Backing up Navidrome..."
    mkdir -p "$BACKUP_DIR"

    # Stop for consistent backup
    WAS_RUNNING=false
    if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
      WAS_RUNNING=true
      $SUDO systemctl stop "$SERVICE_NAME"
    fi

    $SUDO tar -czf "$BACKUP_FILE" \
      -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")/navidrome.db" \
      -C "$(dirname "$DATA_DIR")" "$(basename "$DATA_DIR")/navidrome.toml" \
      2>/dev/null || true

    [[ "$WAS_RUNNING" == true ]] && $SUDO systemctl start "$SERVICE_NAME"

    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    log "✅ Backup saved: ${BACKUP_FILE} (${SIZE})"
    ;;

  restore)
    BACKUP_FILE="${1:-}"
    if [[ -z "$BACKUP_FILE" || ! -f "$BACKUP_FILE" ]]; then
      err "Usage: manage.sh restore /path/to/backup.tar.gz"
      exit 1
    fi

    warn "This will overwrite the current database and config!"
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0

    log "Restoring from ${BACKUP_FILE}..."
    $SUDO systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    $SUDO tar -xzf "$BACKUP_FILE" -C "$(dirname "$DATA_DIR")"
    $SUDO chown -R navidrome:navidrome "$DATA_DIR"
    $SUDO systemctl start "$SERVICE_NAME"
    sleep 2

    if systemctl is-active --quiet "$SERVICE_NAME"; then
      log "✅ Restored successfully"
    else
      err "Restore may have issues. Check: sudo journalctl -u navidrome -n 20"
    fi
    ;;

  uninstall)
    warn "This will remove Navidrome binary, service, and user."
    warn "Your music files will NOT be deleted."
    warn "Database at ${DATA_DIR} will be preserved (delete manually if wanted)."
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0

    log "Stopping service..."
    $SUDO systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    $SUDO systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    $SUDO rm -f /etc/systemd/system/navidrome.service
    $SUDO systemctl daemon-reload

    log "Removing binary..."
    $SUDO rm -rf "$INSTALL_DIR"

    log "Removing user..."
    $SUDO userdel navidrome 2>/dev/null || true

    log "✅ Navidrome uninstalled"
    info "Database preserved at: ${DATA_DIR}"
    info "Delete manually: sudo rm -rf ${DATA_DIR}"
    ;;

  help|*)
    echo "Navidrome Manager"
    echo ""
    echo "Usage: manage.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status              Show Navidrome status and info"
    echo "  start               Start the service"
    echo "  stop                Stop the service"
    echo "  restart             Restart the service"
    echo "  logs [-f] [N]       Show last N log lines (-f to follow)"
    echo "  scan                Trigger music library scan"
    echo "  update [--version]  Update to latest (or specific) version"
    echo "  backup [dir]        Backup database and config"
    echo "  restore <file>      Restore from backup archive"
    echo "  uninstall           Remove Navidrome (preserves data)"
    echo ""
    ;;
esac
