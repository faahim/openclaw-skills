#!/bin/bash
# Import calendar (.ics) or contacts (.vcf) into Radicale
set -e

RADICALE_DATA="${RADICALE_DATA_DIR:-$HOME/.local/share/radicale/collections}"
USER=""
TYPE=""
FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --user) USER="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --file) FILE="$2"; shift 2 ;;
    --help)
      echo "Usage: bash import.sh --user USERNAME --type calendar|contacts --file PATH"
      exit 0
      ;;
    *) echo "Unknown: $1"; exit 1 ;;
  esac
done

[ -z "$USER" ] && { echo "❌ --user required"; exit 1; }
[ -z "$TYPE" ] && { echo "❌ --type required (calendar or contacts)"; exit 1; }
[ -z "$FILE" ] && { echo "❌ --file required"; exit 1; }
[ ! -f "$FILE" ] && { echo "❌ File not found: $FILE"; exit 1; }

COLLECTION_DIR="$RADICALE_DATA/collection-root/$USER"

case "$TYPE" in
  calendar)
    DEST_DIR="$COLLECTION_DIR/calendar.ics"
    mkdir -p "$DEST_DIR"

    # Write collection properties
    cat > "$DEST_DIR/.Radicale.props" <<'EOF'
{"tag": "VCALENDAR", "D:displayname": "Imported Calendar", "C:supported-calendar-component-set": "VEVENT,VTODO,VJOURNAL"}
EOF

    # Split ICS into individual events and copy
    cp "$FILE" "$DEST_DIR/imported.ics"
    echo "✅ Calendar imported to $DEST_DIR"
    ;;

  contacts)
    DEST_DIR="$COLLECTION_DIR/contacts.vcf"
    mkdir -p "$DEST_DIR"

    cat > "$DEST_DIR/.Radicale.props" <<'EOF'
{"tag": "VADDRESSBOOK", "D:displayname": "Imported Contacts"}
EOF

    cp "$FILE" "$DEST_DIR/imported.vcf"
    echo "✅ Contacts imported to $DEST_DIR"
    ;;

  *)
    echo "❌ Unknown type: $TYPE (use 'calendar' or 'contacts')"
    exit 1
    ;;
esac

echo "   Restart Radicale to pick up changes: bash scripts/install.sh --restart"
