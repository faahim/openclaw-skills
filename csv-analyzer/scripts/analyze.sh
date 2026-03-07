#!/bin/bash
# CSV Analyzer — Analyze, filter, transform structured data using Miller
set -e

COMMAND="${1:-help}"
FILE="$2"
ARG3="$3"
ARG4="$4"
ARG5="$5"

# Detect input format from extension
detect_format() {
  local f="$1"
  case "${f##*.}" in
    json)     echo "json" ;;
    tsv)      echo "tsv" ;;
    jsonl)    echo "jsonl" ;;
    *)        echo "csv" ;;
  esac
}

check_file() {
  if [[ -z "$FILE" || ! -f "$FILE" ]]; then
    echo "❌ Error: File '$FILE' not found"
    exit 1
  fi
}

check_mlr() {
  if ! command -v mlr &>/dev/null; then
    echo "❌ Miller (mlr) not installed. Run: bash scripts/install.sh"
    exit 1
  fi
}

fmt() { detect_format "$FILE"; }

case "$COMMAND" in

  stats)
    check_file; check_mlr
    FMT=$(fmt)
    ROWS=$(mlr --"$FMT" count-distinct -f __none__ "$FILE" 2>/dev/null || mlr --"$FMT" tail -n 0 "$FILE" | wc -l)
    ROWS=$(mlr --"$FMT" cat "$FILE" | wc -l)
    ROWS=$((ROWS - 1))  # subtract header for CSV
    [[ "$FMT" == "json" ]] && ROWS=$(mlr --json cat "$FILE" | grep -c "^{" || echo "?")
    
    COLS=$(mlr --"$FMT" head -n 0 "$FILE" 2>/dev/null | head -1 | tr ',' '\n' | wc -l)
    HEADER=$(mlr --"$FMT" head -n 1 "$FILE" 2>/dev/null | head -1)
    
    echo "=== File: $FILE ==="
    echo "Rows: $ROWS"
    echo "Columns: $HEADER"
    echo ""
    echo "=== Numeric Column Stats ==="
    mlr --"$FMT" --opprint stats1 -a count,min,max,mean,sum -f $(mlr --"$FMT" head -n 1 "$FILE" | head -1 | tr -d '"') "$FILE" 2>/dev/null || \
    mlr --"$FMT" --opprint stats1 -a count,min,max,mean,sum "$FILE" 2>/dev/null || \
    echo "(No numeric columns detected)"
    ;;

  filter)
    check_file; check_mlr
    FMT=$(fmt)
    EXPR="$ARG3"
    if [[ -z "$EXPR" ]]; then
      echo "Usage: analyze.sh filter <file> '<expression>'"
      echo "Example: analyze.sh filter sales.csv 'revenue > 1000'"
      exit 1
    fi
    mlr --"$FMT" --opprint filter "\$$EXPR" "$FILE" 2>/dev/null || \
    mlr --"$FMT" --opprint filter "$EXPR" "$FILE"
    ;;

  search)
    check_file; check_mlr
    FMT=$(fmt)
    TERM="$ARG3"
    if [[ -z "$TERM" ]]; then
      echo "Usage: analyze.sh search <file> <term>"
      exit 1
    fi
    mlr --"$FMT" --opprint filter "$(mlr --"$FMT" head -n 1 "$FILE" | head -1 | tr ',' '\n' | sed 's/.*/tolower($&) =~ \"'"$(echo "$TERM" | tr '[:upper:]' '[:lower:]')"'\"/' | tr '\n' ' || ' | sed 's/ || $//')" "$FILE" 2>/dev/null || \
    grep -i "$TERM" "$FILE"
    ;;

  top)
    check_file; check_mlr
    FMT=$(fmt)
    COL="$ARG3"
    N="${ARG4:-10}"
    if [[ -z "$COL" ]]; then
      echo "Usage: analyze.sh top <file> <column> [N]"
      exit 1
    fi
    mlr --"$FMT" --opprint sort -nr "$COL" then head -n "$N" "$FILE"
    ;;

  bottom)
    check_file; check_mlr
    FMT=$(fmt)
    COL="$ARG3"
    N="${ARG4:-10}"
    if [[ -z "$COL" ]]; then
      echo "Usage: analyze.sh bottom <file> <column> [N]"
      exit 1
    fi
    mlr --"$FMT" --opprint sort -nf "$COL" then head -n "$N" "$FILE"
    ;;

  sort)
    check_file; check_mlr
    FMT=$(fmt)
    COLS="$ARG3"
    DIR="${ARG4:-asc}"
    if [[ -z "$COLS" ]]; then
      echo "Usage: analyze.sh sort <file> <col1,col2> [asc|desc]"
      exit 1
    fi
    if [[ "$DIR" == "desc" ]]; then
      mlr --"$FMT" --opprint sort -nr "$COLS" "$FILE"
    else
      mlr --"$FMT" --opprint sort -nf "$COLS" "$FILE"
    fi
    ;;

  group)
    check_file; check_mlr
    FMT=$(fmt)
    GROUP_COL="$ARG3"
    AGGS="$ARG4"
    if [[ -z "$GROUP_COL" || -z "$AGGS" ]]; then
      echo "Usage: analyze.sh group <file> <group_col> '<agg1:col1,agg2:col2,count>'"
      echo "Aggregations: sum, mean, min, max, count, mode, median"
      echo "Example: analyze.sh group sales.csv region 'sum:revenue,count'"
      exit 1
    fi
    
    # Parse aggregations into mlr stats1 flags
    declare -A AGG_TYPES
    AGG_FIELDS_LIST=""
    HAS_COUNT=false
    
    IFS=',' read -ra PARTS <<< "$AGGS"
    for part in "${PARTS[@]}"; do
      part=$(echo "$part" | xargs)  # trim
      if [[ "$part" == "count" ]]; then
        HAS_COUNT=true
      elif [[ "$part" == *":"* ]]; then
        AGG_TYPE="${part%%:*}"
        AGG_COL="${part#*:}"
        AGG_TYPES["$AGG_TYPE"]=1
        AGG_FIELDS_LIST="$AGG_FIELDS_LIST,$AGG_COL"
      fi
    done
    AGG_FIELDS_LIST="${AGG_FIELDS_LIST#,}"
    
    # Build -a flag
    AGG_A=""
    for t in "${!AGG_TYPES[@]}"; do
      [[ -n "$AGG_A" ]] && AGG_A="$AGG_A,$t" || AGG_A="$t"
    done
    
    if [[ -n "$AGG_FIELDS_LIST" && -n "$AGG_A" ]]; then
      if [[ "$HAS_COUNT" == true ]]; then
        mlr --"$FMT" --opprint stats1 -a "$AGG_A,count" -f "$AGG_FIELDS_LIST" -g "$GROUP_COL" "$FILE"
      else
        mlr --"$FMT" --opprint stats1 -a "$AGG_A" -f "$AGG_FIELDS_LIST" -g "$GROUP_COL" "$FILE"
      fi
    elif [[ "$HAS_COUNT" == true ]]; then
      mlr --"$FMT" --opprint uniq -g "$GROUP_COL" -c "$FILE"
    fi
    ;;

  freq)
    check_file; check_mlr
    FMT=$(fmt)
    COL="$ARG3"
    N="${ARG4:-20}"
    if [[ -z "$COL" ]]; then
      echo "Usage: analyze.sh freq <file> <column> [N]"
      exit 1
    fi
    TOTAL=$(mlr --"$FMT" cat "$FILE" | wc -l)
    TOTAL=$((TOTAL - 1))
    mlr --"$FMT" --opprint uniq -g "$COL" -c then sort -nr count then head -n "$N" "$FILE"
    ;;

  convert)
    check_file; check_mlr
    IN_FMT=$(fmt)
    OUT_FMT="${ARG3:-json}"
    OUT_FILE="${FILE%.*}.$OUT_FMT"
    
    case "$OUT_FMT" in
      json)     mlr --i"$IN_FMT" --ojson cat "$FILE" > "$OUT_FILE" ;;
      csv)      mlr --i"$IN_FMT" --ocsv cat "$FILE" > "$OUT_FILE" ;;
      tsv)      mlr --i"$IN_FMT" --otsv cat "$FILE" > "$OUT_FILE" ;;
      markdown) mlr --i"$IN_FMT" --omd cat "$FILE" ; exit 0 ;;
      *)        echo "Supported formats: json, csv, tsv, markdown"; exit 1 ;;
    esac
    echo "✅ Converted to $OUT_FILE"
    ;;

  join)
    check_file; check_mlr
    FILE2="$ARG3"
    JOIN_COL="$ARG4"
    if [[ -z "$FILE2" || -z "$JOIN_COL" ]]; then
      echo "Usage: analyze.sh join <file1> <file2> <join_column>"
      exit 1
    fi
    FMT1=$(detect_format "$FILE")
    FMT2=$(detect_format "$FILE2")
    mlr --"$FMT1" --opprint join -j "$JOIN_COL" -f "$FILE2" "$FILE"
    ;;

  dedup)
    check_file; check_mlr
    FMT=$(fmt)
    COL="$ARG3"
    if [[ -n "$COL" ]]; then
      mlr --"$FMT" --opprint uniq -g "$COL" "$FILE"
    else
      mlr --"$FMT" --opprint uniq -a "$FILE"
    fi
    ;;

  select)
    check_file; check_mlr
    FMT=$(fmt)
    COLS="$ARG3"
    if [[ -z "$COLS" ]]; then
      echo "Usage: analyze.sh select <file> 'col1,col2,col3'"
      exit 1
    fi
    mlr --"$FMT" --opprint cut -f "$COLS" "$FILE"
    ;;

  calc)
    check_file; check_mlr
    FMT=$(fmt)
    EXPR="$ARG3"
    if [[ -z "$EXPR" ]]; then
      echo "Usage: analyze.sh calc <file> 'new_col = expr'"
      echo "Example: analyze.sh calc data.csv 'margin = revenue - cost'"
      exit 1
    fi
    mlr --"$FMT" --opprint put "\$$EXPR" "$FILE"
    ;;

  rename)
    check_file; check_mlr
    FMT=$(fmt)
    MAPPINGS="$ARG3"
    if [[ -z "$MAPPINGS" ]]; then
      echo "Usage: analyze.sh rename <file> 'old=new,old2=new2'"
      exit 1
    fi
    mlr --"$FMT" --opprint rename "$MAPPINGS" "$FILE"
    ;;

  head)
    check_file; check_mlr
    FMT=$(fmt)
    N="${ARG3:-5}"
    mlr --"$FMT" --opprint head -n "$N" "$FILE"
    ;;

  tail)
    check_file; check_mlr
    FMT=$(fmt)
    N="${ARG3:-5}"
    mlr --"$FMT" --opprint tail -n "$N" "$FILE"
    ;;

  sample)
    check_file; check_mlr
    FMT=$(fmt)
    N="${ARG3:-10}"
    mlr --"$FMT" --opprint sample -k "$N" "$FILE"
    ;;

  help|*)
    cat << 'EOF'
CSV Analyzer — Analyze structured data with Miller

USAGE: bash analyze.sh <command> <file> [args...]

COMMANDS:
  stats   <file>                         Quick statistics on all columns
  filter  <file> '<expr>'                Filter rows (e.g. 'revenue > 1000')
  search  <file> <term>                  Search for text across all columns
  top     <file> <col> [N]               Top N rows by column (default 10)
  bottom  <file> <col> [N]               Bottom N rows by column
  sort    <file> <cols> [asc|desc]       Sort by columns
  group   <file> <col> '<aggs>'          Group by column with aggregations
  freq    <file> <col> [N]               Frequency count of column values
  convert <file> <format>                Convert to json/csv/tsv/markdown
  join    <file1> <file2> <join_col>     Join two files on a column
  dedup   <file> [col]                   Remove duplicates
  select  <file> 'col1,col2'             Select specific columns
  calc    <file> 'new = expr'            Add calculated column
  rename  <file> 'old=new'               Rename columns
  head    <file> [N]                     First N rows (default 5)
  tail    <file> [N]                     Last N rows (default 5)
  sample  <file> [N]                     Random sample of N rows

AGGREGATIONS (for group command):
  sum:col, mean:col, min:col, max:col, count, mode:col, median:col

EXAMPLES:
  bash analyze.sh stats sales.csv
  bash analyze.sh filter orders.csv 'total > 500 && status == "shipped"'
  bash analyze.sh group sales.csv region 'sum:revenue,count'
  bash analyze.sh top customers.csv lifetime_value 20
  bash analyze.sh convert data.csv json
EOF
    ;;
esac
