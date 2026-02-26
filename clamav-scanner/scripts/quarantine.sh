#!/bin/bash
# ClamAV — Manage quarantined files
set -e

QUARANTINE_DIR="${CLAMAV_QUARANTINE_DIR:-/var/clamav/quarantine}"
ACTION=""
TARGET=""
PURGE_DAYS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --list) ACTION="list"; shift ;;
        --restore) ACTION="restore"; TARGET="$2"; shift 2 ;;
        --delete) ACTION="delete"; TARGET="$2"; shift 2 ;;
        --purge) ACTION="purge"; PURGE_DAYS="$2"; shift 2 ;;
        --count) ACTION="count"; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

case "$ACTION" in
    list)
        if [[ -d "$QUARANTINE_DIR" ]] && [[ -n "$(ls -A "$QUARANTINE_DIR" 2>/dev/null)" ]]; then
            echo "📦 Quarantined files ($QUARANTINE_DIR):"
            echo ""
            printf "%-40s %-12s %s\n" "File" "Size" "Date"
            printf "%-40s %-12s %s\n" "----" "----" "----"
            find "$QUARANTINE_DIR" -type f -printf "%-40f %-12s %T+\n" 2>/dev/null | sort -k3 -r
        else
            echo "✅ Quarantine is empty"
        fi
        ;;
    restore)
        if [[ -f "$TARGET" ]]; then
            DEST=$(dirname "$TARGET" | sed "s|$QUARANTINE_DIR||")
            if [[ -z "$DEST" || "$DEST" == "/" ]]; then
                DEST="/tmp/restored"
            fi
            mkdir -p "$DEST"
            mv "$TARGET" "$DEST/"
            echo "✅ Restored: $(basename "$TARGET") → $DEST/"
        else
            echo "❌ File not found: $TARGET"
            exit 1
        fi
        ;;
    delete)
        if [[ -f "$TARGET" ]]; then
            rm -f "$TARGET"
            echo "🗑️  Deleted: $TARGET"
        else
            echo "❌ File not found: $TARGET"
            exit 1
        fi
        ;;
    purge)
        DAYS="${PURGE_DAYS:-30}"
        COUNT=$(find "$QUARANTINE_DIR" -type f -mtime +"$DAYS" 2>/dev/null | wc -l)
        if [[ "$COUNT" -gt 0 ]]; then
            find "$QUARANTINE_DIR" -type f -mtime +"$DAYS" -delete
            echo "🗑️  Purged $COUNT files older than $DAYS days"
        else
            echo "✅ No files older than $DAYS days"
        fi
        ;;
    count)
        COUNT=$(find "$QUARANTINE_DIR" -type f 2>/dev/null | wc -l)
        echo "$COUNT quarantined files"
        ;;
    *)
        echo "Usage:"
        echo "  bash quarantine.sh --list"
        echo "  bash quarantine.sh --restore /path/to/quarantined/file"
        echo "  bash quarantine.sh --delete /path/to/quarantined/file"
        echo "  bash quarantine.sh --purge 30  (delete files older than 30 days)"
        echo "  bash quarantine.sh --count"
        ;;
esac
