#!/bin/bash
# CSV to SQLite — Import CSV/TSV files into SQLite and query them
# Dependencies: sqlite3, bash 4.0+

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat <<EOF
CSV to SQLite v${VERSION}

Usage:
  $(basename "$0") import <csv-file|-> <db-file> [options]
  $(basename "$0") import-dir <directory> <db-file> [options]
  $(basename "$0") query <db-file> <sql> [--csv|--json|--markdown]
  $(basename "$0") export <db-file> <table-name>
  $(basename "$0") schema <db-file>
  $(basename "$0") stats <db-file> <table-name>

Import Options:
  --table <name>       Custom table name (default: filename without extension)
  --delimiter <char>   Column delimiter (default: auto-detect)
  --drop-existing      Drop table if it exists before import
  --append             Append to existing table
  --skip-lines <n>     Skip first N lines (default: 0)
  --no-header          CSV has no header row (columns named col1, col2, ...)
  --all-text           Import all columns as TEXT (skip type detection)
  --flexible           Allow rows with different column counts
  --batch              Minimal output, faster import

Query Output:
  --csv                Output as CSV
  --json               Output as JSON (one object per line)
  --markdown           Output as Markdown table
  (default)            Formatted ASCII table

Examples:
  $(basename "$0") import sales.csv analytics.sqlite
  $(basename "$0") import data.tsv mydb.sqlite --delimiter $'\t'
  $(basename "$0") import-dir ./exports/ combined.sqlite
  $(basename "$0") query mydb.sqlite "SELECT * FROM sales LIMIT 10"
  $(basename "$0") query mydb.sqlite "SELECT * FROM sales" --csv > out.csv
  $(basename "$0") schema mydb.sqlite
  $(basename "$0") stats mydb.sqlite sales
EOF
  exit 1
}

# Check dependencies
check_deps() {
  if ! command -v sqlite3 &>/dev/null; then
    echo -e "${RED}Error: sqlite3 not found${NC}"
    echo "Install: sudo apt install sqlite3  (Debian/Ubuntu)"
    echo "         brew install sqlite3       (macOS)"
    exit 1
  fi
}

# Detect delimiter from first line
detect_delimiter() {
  local file="$1"
  local first_line
  first_line=$(head -1 "$file")

  # Count occurrences of common delimiters
  local tab_count comma_count pipe_count semi_count
  tab_count=$(echo "$first_line" | tr -cd '\t' | wc -c)
  comma_count=$(echo "$first_line" | tr -cd ',' | wc -c)
  pipe_count=$(echo "$first_line" | tr -cd '|' | wc -c)
  semi_count=$(echo "$first_line" | tr -cd ';' | wc -c)

  # Pick the most frequent
  local max=$comma_count
  local delim=","

  if [ "$tab_count" -gt "$max" ]; then max=$tab_count; delim=$'\t'; fi
  if [ "$pipe_count" -gt "$max" ]; then max=$pipe_count; delim='|'; fi
  if [ "$semi_count" -gt "$max" ]; then max=$semi_count; delim=';'; fi

  echo "$delim"
}

# Detect column types from sample data
detect_types() {
  local file="$1"
  local delimiter="$2"
  local skip=$3
  local num_cols=$4

  # Sample first 100 data rows (after header)
  local start=$((skip + 2))  # +1 for header, +1 for 1-indexed
  local sample
  sample=$(sed -n "${start},$((start + 99))p" "$file")

  local types=()
  for ((i = 1; i <= num_cols; i++)); do
    local col_data
    col_data=$(echo "$sample" | awk -F"$delimiter" -v col="$i" '{
      gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", $col)
      if ($col != "") print $col
    }' | head -50)

    if [ -z "$col_data" ]; then
      types+=("TEXT")
      continue
    fi

    # Check if all values are integers
    if echo "$col_data" | grep -qvE '^-?[0-9]+$'; then
      # Not all integers — check if all numeric (with decimals)
      if echo "$col_data" | grep -qvE '^-?[0-9]*\.?[0-9]+$'; then
        types+=("TEXT")
      else
        types+=("REAL")
      fi
    else
      types+=("INTEGER")
    fi
  done

  echo "${types[@]}"
}

# Sanitize table/column names for SQL
sanitize_name() {
  echo "$1" | sed 's/[^a-zA-Z0-9_]/_/g' | sed 's/^[0-9]/_&/' | tr '[:upper:]' '[:lower:]'
}

# Import CSV into SQLite
do_import() {
  local csv_file="$1"
  local db_file="$2"
  shift 2

  # Parse options
  local table_name="" delimiter="" drop_existing=false append=false
  local skip_lines=0 no_header=false all_text=false flexible=false batch=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --table) table_name="$2"; shift 2 ;;
      --delimiter) delimiter="$2"; shift 2 ;;
      --drop-existing) drop_existing=true; shift ;;
      --append) append=true; shift ;;
      --skip-lines) skip_lines="$2"; shift 2 ;;
      --no-header) no_header=true; shift ;;
      --all-text) all_text=true; shift ;;
      --flexible) flexible=true; shift ;;
      --batch) batch=true; shift ;;
      *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
  done

  # Handle stdin
  local tmp_file=""
  if [ "$csv_file" = "-" ]; then
    tmp_file=$(mktemp /tmp/csv-sqlite-XXXXXX.csv)
    cat > "$tmp_file"
    csv_file="$tmp_file"
  fi

  # Validate file
  if [ ! -f "$csv_file" ]; then
    echo -e "${RED}Error: File not found: $csv_file${NC}"
    [ -n "$tmp_file" ] && rm -f "$tmp_file"
    exit 1
  fi

  # Default table name from filename
  if [ -z "$table_name" ]; then
    table_name=$(basename "$csv_file" | sed 's/\.[^.]*$//')
    table_name=$(sanitize_name "$table_name")
  fi

  # Auto-detect delimiter
  if [ -z "$delimiter" ]; then
    delimiter=$(detect_delimiter "$csv_file")
  fi

  local delim_name="comma"
  case "$delimiter" in
    $'\t') delim_name="tab" ;;
    '|') delim_name="pipe" ;;
    ';') delim_name="semicolon" ;;
  esac

  # Get headers
  local header_line
  header_line=$(sed -n "$((skip_lines + 1))p" "$csv_file")

  # Parse column names
  local columns=()
  if $no_header; then
    local num_cols
    num_cols=$(echo "$header_line" | awk -F"$delimiter" '{print NF}')
    for ((i = 1; i <= num_cols; i++)); do
      columns+=("col${i}")
    done
  else
    IFS="$delimiter" read -ra raw_cols <<< "$header_line"
    for col in "${raw_cols[@]}"; do
      col=$(echo "$col" | sed 's/^[[:space:]"]*//;s/[[:space:]"]*$//')
      columns+=("$(sanitize_name "$col")")
    done
  fi

  local num_cols=${#columns[@]}

  # Detect types
  local types
  if $all_text; then
    types=()
    for ((i = 0; i < num_cols; i++)); do types+=("TEXT"); done
  else
    read -ra types <<< "$(detect_types "$csv_file" "$delimiter" "$skip_lines" "$num_cols")"
  fi

  # Build CREATE TABLE SQL
  local create_sql="CREATE TABLE IF NOT EXISTS \"${table_name}\" ("
  for ((i = 0; i < num_cols; i++)); do
    [ $i -gt 0 ] && create_sql+=", "
    create_sql+="\"${columns[$i]}\" ${types[$i]:-TEXT}"
  done
  create_sql+=");"

  # Drop if requested
  if $drop_existing; then
    sqlite3 "$db_file" "DROP TABLE IF EXISTS \"${table_name}\";"
  fi

  # Create table (unless appending to existing)
  if ! $append; then
    sqlite3 "$db_file" "$create_sql"
  fi

  # Import using sqlite3's .import
  local data_start=$((skip_lines + 1))
  $no_header || data_start=$((data_start + 1))

  # Count total lines for progress
  local total_lines
  total_lines=$(wc -l < "$csv_file")
  local data_lines=$((total_lines - data_start + 1))

  # Use sqlite3 .import with .mode csv
  local sqlite_delim
  case "$delimiter" in
    $'\t') sqlite_delim="\t" ;;
    *) sqlite_delim="$delimiter" ;;
  esac

  # Create temp file with just data rows
  local data_file
  data_file=$(mktemp /tmp/csv-sqlite-data-XXXXXX.csv)
  tail -n +${data_start} "$csv_file" > "$data_file"

  sqlite3 "$db_file" <<EOSQL
.mode csv
.separator "${sqlite_delim}"
.import ${data_file} ${table_name}
EOSQL

  rm -f "$data_file"

  # Count imported rows
  local row_count
  row_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM \"${table_name}\";")

  if ! $batch; then
    echo -e "${GREEN}✅ Imported ${csv_file} → ${db_file}${NC} (table: ${table_name})"
    echo -e "${BLUE}📊 ${row_count} rows, ${num_cols} columns detected (${delim_name}-delimited)${NC}"
    echo -n "   Columns: "
    for ((i = 0; i < num_cols; i++)); do
      [ $i -gt 0 ] && echo -n ", "
      echo -n "${columns[$i]} (${types[$i]:-TEXT})"
    done
    echo ""
  fi

  [ -n "$tmp_file" ] && rm -f "$tmp_file"
}

# Import all CSV/TSV files from a directory
do_import_dir() {
  local dir="$1"
  local db_file="$2"
  shift 2

  if [ ! -d "$dir" ]; then
    echo -e "${RED}Error: Directory not found: $dir${NC}"
    exit 1
  fi

  local count=0
  for f in "$dir"/*.csv "$dir"/*.tsv "$dir"/*.CSV "$dir"/*.TSV; do
    [ -f "$f" ] || continue
    do_import "$f" "$db_file" "$@"
    count=$((count + 1))
  done

  if [ $count -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No CSV/TSV files found in ${dir}${NC}"
  else
    echo -e "\n${GREEN}📊 ${count} tables created in ${db_file}${NC}"
  fi
}

# Run a query
do_query() {
  local db_file="$1"
  local sql="$2"
  shift 2

  if [ ! -f "$db_file" ]; then
    echo -e "${RED}Error: Database not found: $db_file${NC}"
    exit 1
  fi

  local format="table"
  while [[ $# -gt 0 ]]; do
    case $1 in
      --csv) format="csv"; shift ;;
      --json) format="json"; shift ;;
      --markdown) format="markdown"; shift ;;
      *) shift ;;
    esac
  done

  case "$format" in
    csv)
      sqlite3 -csv -header "$db_file" "$sql"
      ;;
    json)
      sqlite3 -json "$db_file" "$sql"
      ;;
    markdown)
      sqlite3 -markdown "$db_file" "$sql"
      ;;
    table)
      sqlite3 -column -header "$db_file" "$sql"
      ;;
  esac
}

# Show database schema
do_schema() {
  local db_file="$1"

  if [ ! -f "$db_file" ]; then
    echo -e "${RED}Error: Database not found: $db_file${NC}"
    exit 1
  fi

  local size
  size=$(du -h "$db_file" | cut -f1)
  echo -e "${BLUE}📋 Database: ${db_file} (${size})${NC}"
  echo ""

  local tables
  tables=$(sqlite3 "$db_file" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;")

  for table in $tables; do
    local row_count
    row_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM \"${table}\";")
    echo -e "${GREEN}Table: ${table}${NC} (${row_count} rows)"

    sqlite3 "$db_file" "PRAGMA table_info(\"${table}\");" | while IFS='|' read -r cid name type notnull dflt pk; do
      printf "  %-20s %s" "$name" "$type"
      [ "$pk" = "1" ] && printf " PRIMARY KEY"
      [ "$notnull" = "1" ] && printf " NOT NULL"
      echo ""
    done
    echo ""
  done
}

# Show table statistics
do_stats() {
  local db_file="$1"
  local table="$2"

  if [ ! -f "$db_file" ]; then
    echo -e "${RED}Error: Database not found: $db_file${NC}"
    exit 1
  fi

  local row_count
  row_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM \"${table}\";")

  local col_info
  col_info=$(sqlite3 "$db_file" "PRAGMA table_info(\"${table}\");")
  local num_cols
  num_cols=$(echo "$col_info" | wc -l)

  echo -e "${BLUE}📊 Table: ${table}${NC}"
  echo "Rows: ${row_count}"
  echo "Columns: ${num_cols}"
  echo ""
  echo "Column Stats:"

  echo "$col_info" | while IFS='|' read -r cid name type notnull dflt pk; do
    local null_count
    null_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM \"${table}\" WHERE \"${name}\" IS NULL;")

    if [ "$type" = "INTEGER" ] || [ "$type" = "REAL" ]; then
      local stats
      stats=$(sqlite3 "$db_file" "SELECT MIN(\"${name}\"), MAX(\"${name}\"), ROUND(AVG(\"${name}\"), 2) FROM \"${table}\" WHERE \"${name}\" IS NOT NULL;")
      IFS='|' read -r min_val max_val avg_val <<< "$stats"
      echo -e "  ${name} (${type}): min=${min_val}, max=${max_val}, avg=${avg_val}, nulls=${null_count}"
    else
      local unique_count
      unique_count=$(sqlite3 "$db_file" "SELECT COUNT(DISTINCT \"${name}\") FROM \"${table}\";")
      # Show top 5 values
      local top_vals
      top_vals=$(sqlite3 "$db_file" "SELECT \"${name}\" || ': ' || COUNT(*) FROM \"${table}\" WHERE \"${name}\" IS NOT NULL GROUP BY \"${name}\" ORDER BY COUNT(*) DESC LIMIT 5;" | tr '\n' ', ' | sed 's/, $//')
      echo -e "  ${name} (${type}): unique=${unique_count}, nulls=${null_count}"
      [ -n "$top_vals" ] && echo "    top: ${top_vals}"
    fi
  done
}

# Export table as CSV
do_export() {
  local db_file="$1"
  local table="$2"

  if [ ! -f "$db_file" ]; then
    echo -e "${RED}Error: Database not found: $db_file${NC}" >&2
    exit 1
  fi

  sqlite3 -csv -header "$db_file" "SELECT * FROM \"${table}\";"
}

# Main
check_deps

if [ $# -lt 1 ]; then
  usage
fi

command="$1"
shift

case "$command" in
  import)
    [ $# -lt 2 ] && usage
    do_import "$@"
    ;;
  import-dir)
    [ $# -lt 2 ] && usage
    do_import_dir "$@"
    ;;
  query)
    [ $# -lt 2 ] && usage
    do_query "$@"
    ;;
  export)
    [ $# -lt 2 ] && usage
    do_export "$@"
    ;;
  schema)
    [ $# -lt 1 ] && usage
    do_schema "$@"
    ;;
  stats)
    [ $# -lt 2 ] && usage
    do_stats "$@"
    ;;
  --help|-h|help)
    usage
    ;;
  *)
    echo -e "${RED}Unknown command: ${command}${NC}"
    usage
    ;;
esac
