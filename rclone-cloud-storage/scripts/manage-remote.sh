#!/bin/bash
# Manage rclone remotes (add, remove, list, test)
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") <action> [args]

Actions:
  list                         List configured remotes
  add <name> <type> [options]  Add a new remote
  remove <name>                Remove a remote
  test <name>                  Test remote connectivity
  add-crypt <name> <remote>    Add encrypted remote wrapping another remote

Supported types:
  s3        Amazon S3, Backblaze B2, Wasabi, MinIO, Cloudflare R2
  drive     Google Drive
  dropbox   Dropbox
  onedrive  Microsoft OneDrive
  b2        Backblaze B2 (native API)
  sftp      SFTP/SSH server
  gcs       Google Cloud Storage
  azureblob Azure Blob Storage
  ftp       FTP server
  webdav    WebDAV (Nextcloud, ownCloud, etc.)
  mega      Mega.nz
  pcloud    pCloud
  crypt     Encrypted overlay (use add-crypt)

Options for 's3':
  --endpoint URL       S3 endpoint (for non-AWS)
  --access-key KEY     Access key ID
  --secret-key SECRET  Secret access key
  --region REGION      AWS region (default: us-east-1)
  --provider PROV      S3 provider (AWS, Backblaze, Wasabi, Cloudflare, Minio, Other)

Options for 'sftp':
  --host HOST          SFTP host
  --user USER          Username
  --port PORT          Port (default: 22)
  --key-file PATH      SSH key file path

Examples:
  $(basename "$0") list
  $(basename "$0") add myb2 s3 --provider Backblaze --endpoint https://s3.us-west-002.backblazeb2.com --access-key XXX --secret-key YYY
  $(basename "$0") add mysftp sftp --host example.com --user admin --key-file ~/.ssh/id_rsa
  $(basename "$0") add-crypt encrypted-backup myb2:encrypted-data
  $(basename "$0") test myb2
  $(basename "$0") remove myb2
EOF
  exit 0
}

ACTION="${1:-}"
shift 2>/dev/null || true

case "$ACTION" in
  list)
    echo "📋 Configured remotes:"
    echo ""
    REMOTES=$(rclone listremotes 2>/dev/null)
    if [[ -z "$REMOTES" ]]; then
      echo "   No remotes configured."
      echo "   Add one: $(basename "$0") add <name> <type>"
    else
      for remote in $REMOTES; do
        TYPE=$(rclone config show "${remote%:}" 2>/dev/null | grep "^type" | cut -d= -f2 | tr -d ' ')
        echo "   📁 ${remote%:} (${TYPE:-unknown})"
      done
    fi
    ;;

  add)
    NAME="${1:-}"
    TYPE="${2:-}"
    shift 2 2>/dev/null || true

    if [[ -z "$NAME" || -z "$TYPE" ]]; then
      echo "❌ Usage: $(basename "$0") add <name> <type> [options]"
      exit 1
    fi

    # Check if remote already exists
    if rclone listremotes 2>/dev/null | grep -q "^${NAME}:$"; then
      echo "❌ Remote '$NAME' already exists. Remove it first: $(basename "$0") remove $NAME"
      exit 1
    fi

    echo "🔧 Configuring remote '$NAME' (type: $TYPE)..."

    case "$TYPE" in
      s3)
        ENDPOINT="" ACCESS_KEY="" SECRET_KEY="" REGION="us-east-1" PROVIDER="AWS"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --endpoint) ENDPOINT="$2"; shift 2 ;;
            --access-key) ACCESS_KEY="$2"; shift 2 ;;
            --secret-key) SECRET_KEY="$2"; shift 2 ;;
            --region) REGION="$2"; shift 2 ;;
            --provider) PROVIDER="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
          esac
        done

        rclone config create "$NAME" s3 \
          provider "$PROVIDER" \
          access_key_id "$ACCESS_KEY" \
          secret_access_key "$SECRET_KEY" \
          region "$REGION" \
          ${ENDPOINT:+endpoint "$ENDPOINT"} \
          --non-interactive
        ;;

      sftp)
        HOST="" USER="" PORT="22" KEY_FILE=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --host) HOST="$2"; shift 2 ;;
            --user) USER="$2"; shift 2 ;;
            --port) PORT="$2"; shift 2 ;;
            --key-file) KEY_FILE="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
          esac
        done

        if [[ -z "$HOST" ]]; then
          echo "❌ --host is required for SFTP"
          exit 1
        fi

        rclone config create "$NAME" sftp \
          host "$HOST" \
          user "${USER:-$(whoami)}" \
          port "$PORT" \
          ${KEY_FILE:+key_file "$KEY_FILE"} \
          --non-interactive
        ;;

      drive|dropbox|onedrive)
        echo "⚠️  $TYPE requires OAuth authentication."
        echo "   Running interactive config..."
        rclone config create "$NAME" "$TYPE" --non-interactive || rclone config
        ;;

      b2)
        ACCOUNT="" KEY=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --account) ACCOUNT="$2"; shift 2 ;;
            --key) KEY="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
          esac
        done
        rclone config create "$NAME" b2 \
          account "$ACCOUNT" \
          key "$KEY" \
          --non-interactive
        ;;

      *)
        echo "⚠️  Type '$TYPE' — running interactive config..."
        rclone config create "$NAME" "$TYPE" --non-interactive 2>/dev/null || rclone config
        ;;
    esac

    echo "✅ Remote '$NAME' configured!"
    echo "   Test with: $(basename "$0") test $NAME"
    ;;

  add-crypt)
    NAME="${1:-}"
    REMOTE="${2:-}"

    if [[ -z "$NAME" || -z "$REMOTE" ]]; then
      echo "❌ Usage: $(basename "$0") add-crypt <name> <remote-path>"
      echo "   Example: $(basename "$0") add-crypt encrypted-backup mycloud:encrypted-data"
      exit 1
    fi

    echo "🔐 Creating encrypted remote '$NAME' wrapping '$REMOTE'..."
    echo "⚠️  You'll need to set a password. Running interactive config..."
    rclone config create "$NAME" crypt remote "$REMOTE"
    echo "✅ Encrypted remote '$NAME' configured!"
    ;;

  remove)
    NAME="${1:-}"
    if [[ -z "$NAME" ]]; then
      echo "❌ Usage: $(basename "$0") remove <name>"
      exit 1
    fi
    rclone config delete "$NAME"
    echo "✅ Remote '$NAME' removed."
    ;;

  test)
    NAME="${1:-}"
    if [[ -z "$NAME" ]]; then
      echo "❌ Usage: $(basename "$0") test <name>"
      exit 1
    fi

    echo "🔍 Testing remote '$NAME'..."
    if rclone lsd "${NAME}:" --max-depth 1 2>/dev/null; then
      echo "✅ Remote '$NAME' is working!"
    else
      echo "❌ Failed to connect to '$NAME'"
      echo "   Check config: rclone config show $NAME"
      exit 1
    fi
    ;;

  -h|--help|help|"")
    usage
    ;;

  *)
    echo "❌ Unknown action: $ACTION"
    usage
    ;;
esac
