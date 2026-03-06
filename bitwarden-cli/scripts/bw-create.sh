#!/bin/bash
set -euo pipefail

# Bitwarden Create Item

NAME=""
USERNAME=""
PASSWORD=""
URL=""
FOLDER=""
NOTES=""
TYPE="login"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --username) USERNAME="$2"; shift 2 ;;
    --password) PASSWORD="$2"; shift 2 ;;
    --url) URL="$2"; shift 2 ;;
    --folder) FOLDER="$2"; shift 2 ;;
    --notes) NOTES="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$NAME" ]; then
  echo "Usage: bw-create.sh --name 'Item Name' [--username user] [--password pass] [--url https://...] [--folder 'Folder'] [--notes 'text'] [--type login|securenote]"
  exit 1
fi

if [ -z "${BW_SESSION:-}" ]; then
  echo "❌ Vault is locked. Run: export BW_SESSION=\$(bw unlock --raw)"
  exit 1
fi

# Resolve folder ID
FOLDER_ID="null"
if [ -n "$FOLDER" ]; then
  FOLDER_ID=$(bw list folders --search "$FOLDER" --session "$BW_SESSION" | jq -r '.[0].id // empty' 2>/dev/null)
  if [ -z "$FOLDER_ID" ]; then
    echo "📁 Folder '$FOLDER' not found. Creating..."
    FOLDER_ID=$(echo "{\"name\":\"$FOLDER\"}" | bw encode | bw create folder --session "$BW_SESSION" | jq -r '.id')
    echo "   Created folder: $FOLDER ($FOLDER_ID)"
  fi
fi

# Build JSON
if [ "$TYPE" = "securenote" ]; then
  ITEM_JSON=$(jq -n \
    --arg name "$NAME" \
    --arg notes "$NOTES" \
    --arg fid "$FOLDER_ID" \
    '{
      type: 2,
      secureNote: { type: 0 },
      name: $name,
      notes: $notes,
      folderId: (if $fid == "null" then null else $fid end)
    }')
else
  ITEM_JSON=$(jq -n \
    --arg name "$NAME" \
    --arg user "$USERNAME" \
    --arg pass "$PASSWORD" \
    --arg url "$URL" \
    --arg notes "$NOTES" \
    --arg fid "$FOLDER_ID" \
    '{
      type: 1,
      name: $name,
      notes: (if $notes == "" then null else $notes end),
      folderId: (if $fid == "null" then null else $fid end),
      login: {
        username: (if $user == "" then null else $user end),
        password: (if $pass == "" then null else $pass end),
        uris: (if $url == "" then [] else [{ uri: $url, match: null }] end)
      }
    }')
fi

RESULT=$(echo "$ITEM_JSON" | bw encode | bw create item --session "$BW_SESSION")
ITEM_ID=$(echo "$RESULT" | jq -r '.id')

echo "✅ Created: $NAME"
echo "   ID: $ITEM_ID"
echo "   Type: $TYPE"
[ -n "$USERNAME" ] && echo "   Username: $USERNAME"
[ -n "$URL" ] && echo "   URL: $URL"
[ -n "$FOLDER" ] && echo "   Folder: $FOLDER"
