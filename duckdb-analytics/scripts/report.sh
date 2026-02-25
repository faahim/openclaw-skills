#!/bin/bash
# Generate a markdown summary report from a data file (CSV/JSON/Parquet)
set -e

FILE="${1:?Usage: report.sh <data-file> [output-file]}"
OUTPUT="${2:-report.md}"

if [ ! -f "$FILE" ]; then
  echo "❌ File not found: $FILE"
  exit 1
fi

if ! command -v duckdb &>/dev/null; then
  echo "❌ DuckDB not installed. Run: bash scripts/install.sh"
  exit 1
fi

echo "📊 Generating report for: $FILE"

cat > "$OUTPUT" <<HEADER
# Data Report: $(basename "$FILE")

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Source:** \`$FILE\`
**Size:** $(du -h "$FILE" | cut -f1)

HEADER

# Row count
ROWS=$(duckdb -noheader -csv -c "SELECT COUNT(*) FROM '$FILE'" 2>/dev/null | head -1)
echo "**Rows:** $ROWS" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Schema
echo "## Schema" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
duckdb -c "DESCRIBE SELECT * FROM '$FILE'" 2>/dev/null >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Summary statistics
echo "## Summary Statistics" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
duckdb -c "SUMMARIZE SELECT * FROM '$FILE'" 2>/dev/null >> "$OUTPUT" || echo "(Summary not available)" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Sample rows
echo "## Sample Data (first 5 rows)" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
duckdb -c "SELECT * FROM '$FILE' LIMIT 5" 2>/dev/null >> "$OUTPUT"
echo '```' >> "$OUTPUT"
echo "" >> "$OUTPUT"

# Null counts per column
echo "## Null Counts" >> "$OUTPUT"
echo "" >> "$OUTPUT"
echo '```' >> "$OUTPUT"
COLS=$(duckdb -noheader -separator ',' -c "SELECT column_name FROM (DESCRIBE SELECT * FROM '$FILE')" 2>/dev/null)
if [ -n "$COLS" ]; then
  NULL_QUERY="SELECT "
  FIRST=true
  IFS=',' read -ra COL_ARRAY <<< "$(echo "$COLS" | tr '\n' ',')"
  for col in "${COL_ARRAY[@]}"; do
    col=$(echo "$col" | xargs)
    [ -z "$col" ] && continue
    if [ "$FIRST" = true ]; then
      FIRST=false
    else
      NULL_QUERY+=", "
    fi
    NULL_QUERY+="SUM(CASE WHEN \"$col\" IS NULL THEN 1 ELSE 0 END) as \"${col}_nulls\""
  done
  NULL_QUERY+=" FROM '$FILE'"
  duckdb -c "$NULL_QUERY" 2>/dev/null >> "$OUTPUT" || echo "(Could not compute nulls)" >> "$OUTPUT"
fi
echo '```' >> "$OUTPUT"

echo ""
echo "✅ Report saved to: $OUTPUT"
