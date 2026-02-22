#!/bin/bash
# Configure an rclone remote for cloud storage
set -e

REMOTE_NAME="${1:?Usage: setup-remote.sh <name> --provider <type> [options]}"
shift

PROVIDER=""
ACCESS_KEY=""
SECRET_KEY=""
REGION="us-east-1"
BUCKET=""
ACCOUNT=""
KEY=""
ENDPOINT=""
HOST=""
USER=""
PORT="22"

while [[ $# -gt 0 ]]; do
  case $1 in
    --provider)    PROVIDER="$2"; shift 2 ;;
    --access-key)  ACCESS_KEY="$2"; shift 2 ;;
    --secret-key)  SECRET_KEY="$2"; shift 2 ;;
    --region)      REGION="$2"; shift 2 ;;
    --bucket)      BUCKET="$2"; shift 2 ;;
    --account)     ACCOUNT="$2"; shift 2 ;;
    --key)         KEY="$2"; shift 2 ;;
    --endpoint)    ENDPOINT="$2"; shift 2 ;;
    --host)        HOST="$2"; shift 2 ;;
    --user)        USER="$2"; shift 2 ;;
    --port)        PORT="$2"; shift 2 ;;
    *)             echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$PROVIDER" ]]; then
  echo "❌ --provider required. Options: AWS, B2, DO, MinIO, Wasabi, R2, SFTP, GDrive, Dropbox"
  exit 1
fi

echo "🔧 Configuring remote: $REMOTE_NAME ($PROVIDER)"

case "$PROVIDER" in
  AWS|S3)
    rclone config create "$REMOTE_NAME" s3 \
      provider AWS \
      access_key_id "$ACCESS_KEY" \
      secret_access_key "$SECRET_KEY" \
      region "$REGION" \
      env_auth false
    ;;
  B2)
    rclone config create "$REMOTE_NAME" b2 \
      account "$ACCOUNT" \
      key "$KEY"
    ;;
  DO|DigitalOcean)
    rclone config create "$REMOTE_NAME" s3 \
      provider DigitalOcean \
      access_key_id "$ACCESS_KEY" \
      secret_access_key "$SECRET_KEY" \
      endpoint "${REGION}.digitaloceanspaces.com"
    ;;
  MinIO)
    rclone config create "$REMOTE_NAME" s3 \
      provider Minio \
      access_key_id "$ACCESS_KEY" \
      secret_access_key "$SECRET_KEY" \
      endpoint "$ENDPOINT" \
      env_auth false
    ;;
  Wasabi)
    rclone config create "$REMOTE_NAME" s3 \
      provider Wasabi \
      access_key_id "$ACCESS_KEY" \
      secret_access_key "$SECRET_KEY" \
      region "$REGION" \
      endpoint "s3.${REGION}.wasabisys.com"
    ;;
  R2|Cloudflare)
    rclone config create "$REMOTE_NAME" s3 \
      provider Cloudflare \
      access_key_id "$ACCESS_KEY" \
      secret_access_key "$SECRET_KEY" \
      endpoint "$ENDPOINT"
    ;;
  SFTP)
    rclone config create "$REMOTE_NAME" sftp \
      host "$HOST" \
      user "$USER" \
      port "$PORT"
    ;;
  GDrive)
    echo "Google Drive requires interactive OAuth."
    echo "Run: rclone config"
    echo "Choose 'Google Drive', follow the prompts."
    exit 0
    ;;
  Dropbox)
    echo "Dropbox requires interactive OAuth."
    echo "Run: rclone config"
    echo "Choose 'Dropbox', follow the prompts."
    exit 0
    ;;
  *)
    echo "❌ Unknown provider: $PROVIDER"
    echo "Supported: AWS, B2, DO, MinIO, Wasabi, R2, SFTP, GDrive, Dropbox"
    echo "For other providers: rclone config"
    exit 1
    ;;
esac

# Verify connection
echo ""
echo "🔍 Verifying connection..."
if rclone lsd "${REMOTE_NAME}:" --max-depth 0 2>/dev/null; then
  echo "✅ Remote '$REMOTE_NAME' configured and connected!"
  echo ""
  echo "Test: rclone lsd ${REMOTE_NAME}:"
  echo "Usage: bash scripts/backup.sh --source /path --remote ${REMOTE_NAME}:${BUCKET:-bucket}/path"
else
  echo "⚠️  Remote created but connection test failed. Check credentials."
  echo "Debug: rclone lsd ${REMOTE_NAME}: -v"
fi
