#!/bin/bash
# Cloud Sync & Backup — Restore from backup
set -euo pipefail

REMOTE=""
TARGET=""
DECRYPT=false
PASSWORD="${BACKUP_PASSWORD:-}"
LATEST=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --remote)    REMOTE="$2"; shift 2 ;;
    --target)    TARGET="$2"; shift 2 ;;
    --decrypt)   DECRYPT=true; shift ;;
    --password)  PASSWORD="$2"; shift 2 ;;
    --latest)    LATEST=true; shift ;;
    *)           echo "Unknown: $1"; exit 1 ;;
  esac
done

if [[ -z "$REMOTE" || -z "$TARGET" ]]; then
  echo "Usage: restore.sh --remote <remote:path/file> --target <local-path> [--decrypt --password <pass>] [--latest]"
  exit 1
fi

if ! command -v rclone &>/dev/null; then
  echo "❌ rclone not installed. Run: bash scripts/install.sh"
  exit 1
fi

mkdir -p "$TARGET"

# If --latest, find most recent backup file
if [[ "$LATEST" == true ]]; then
  echo "🔍 Finding latest backup in $REMOTE..."
  LATEST_FILE=$(rclone lsf "$REMOTE" --files-only | sort -r | head -1)
  if [[ -z "$LATEST_FILE" ]]; then
    echo "❌ No backup files found in $REMOTE"
    exit 1
  fi
  REMOTE="${REMOTE%/}/${LATEST_FILE}"
  echo "📦 Latest: $LATEST_FILE"
fi

FILENAME=$(basename "$REMOTE")
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Downloading: $REMOTE"
rclone copy "$REMOTE" "$TEMP_DIR/" --progress

DOWNLOADED="$TEMP_DIR/$FILENAME"

# Decrypt if needed
if [[ "$DECRYPT" == true ]] || [[ "$FILENAME" == *.gpg ]]; then
  if [[ -z "$PASSWORD" ]]; then
    echo "❌ Decryption requires --password or \$BACKUP_PASSWORD"
    exit 1
  fi
  echo "🔐 Decrypting..."
  DECRYPTED="${DOWNLOADED%.gpg}"
  gpg --batch --yes --decrypt --passphrase "$PASSWORD" -o "$DECRYPTED" "$DOWNLOADED"
  DOWNLOADED="$DECRYPTED"
  FILENAME="${FILENAME%.gpg}"
fi

# Extract if compressed
if [[ "$FILENAME" == *.tar.gz ]] || [[ "$FILENAME" == *.tgz ]]; then
  echo "📦 Extracting to $TARGET..."
  tar xzf "$DOWNLOADED" -C "$TARGET"
elif [[ "$FILENAME" == *.tar ]]; then
  echo "📦 Extracting to $TARGET..."
  tar xf "$DOWNLOADED" -C "$TARGET"
else
  echo "📋 Copying to $TARGET..."
  cp "$DOWNLOADED" "$TARGET/"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Restore complete: $TARGET"
ls -la "$TARGET"
