#!/bin/bash
# Data Pipeline Tool — Multi-step pipeline runner
# Usage: bash run-pipeline.sh --input data.csv --output result.json --steps "filter:amount>100,sort:-amount,head:10,format:json"

set -e

INPUT=""
OUTPUT=""
STEPS=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --input|-i) INPUT="$2"; shift 2 ;;
    --output|-o) OUTPUT="$2"; shift 2 ;;
    --steps|-s) STEPS="$2"; shift 2 ;;
    --verbose|-v) VERBOSE=true; shift ;;
    --help|-h)
      echo "Usage: bash run-pipeline.sh --input FILE --output FILE --steps STEPS"
      echo ""
      echo "Steps (comma-separated):"
      echo "  filter:EXPR        Filter rows (e.g., filter:revenue>1000)"
      echo "  cut:COL1:COL2      Select columns"
      echo "  sort:COL           Sort ascending (prefix - for descending)"
      echo "  head:N             First N rows"
      echo "  tail:N             Last N rows"
      echo "  uniq:COL           Deduplicate by column (or all)"
      echo "  rename:OLD:NEW     Rename column"
      echo "  put:EXPR           Add/transform column (e.g., put:total=price*qty)"
      echo "  group:COL:AGG:FIELD  Aggregate (sum/mean/count/min/max)"
      echo "  join:FILE:KEY      Join with another file"
      echo "  sample:N           Random sample of N rows"
      echo "  format:FMT         Output format (csv/json/tsv/markdown)"
      echo ""
      echo "Example:"
      echo "  bash run-pipeline.sh -i sales.csv -o report.json \\"
      echo "    -s 'filter:revenue>1000,group:region:sum:revenue,sort:-revenue_sum,format:json'"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$INPUT" ]]; then
  echo "Error: --input required"
  exit 1
fi

if [[ ! -f "$INPUT" ]]; then
  echo "Error: Input file not found: $INPUT"
  exit 1
fi

# Detect input format
case "$INPUT" in
  *.json) IN_FMT="json" ;;
  *.tsv)  IN_FMT="tsv" ;;
  *)      IN_FMT="csv" ;;
esac

# Build Miller command chain
MLR_CHAIN=""
OUT_FMT="$IN_FMT"

IFS=',' read -ra STEP_LIST <<< "$STEPS"
for step in "${STEP_LIST[@]}"; do
  IFS=':' read -ra PARTS <<< "$step"
  CMD="${PARTS[0]}"
  
  case "$CMD" in
    filter)
      EXPR="${step#filter:}"
      MLR_CHAIN="$MLR_CHAIN then filter '\$$EXPR'"
      ;;
    cut)
      COLS=$(echo "${step#cut:}" | tr ':' ',')
      MLR_CHAIN="$MLR_CHAIN then cut -f $COLS"
      ;;
    sort)
      COL="${PARTS[1]}"
      if [[ "$COL" == -* ]]; then
        MLR_CHAIN="$MLR_CHAIN then sort-by -nr ${COL#-}"
      else
        MLR_CHAIN="$MLR_CHAIN then sort-by $COL"
      fi
      ;;
    head)
      N="${PARTS[1]:-10}"
      MLR_CHAIN="$MLR_CHAIN then head -n $N"
      ;;
    tail)
      N="${PARTS[1]:-10}"
      MLR_CHAIN="$MLR_CHAIN then tail -n $N"
      ;;
    uniq)
      COL="${PARTS[1]}"
      if [[ -n "$COL" ]]; then
        MLR_CHAIN="$MLR_CHAIN then uniq -f $COL"
      else
        MLR_CHAIN="$MLR_CHAIN then uniq -a"
      fi
      ;;
    rename)
      OLD="${PARTS[1]}"
      NEW="${PARTS[2]}"
      MLR_CHAIN="$MLR_CHAIN then rename $OLD,$NEW"
      ;;
    put)
      EXPR="${step#put:}"
      MLR_CHAIN="$MLR_CHAIN then put '\$$EXPR'"
      ;;
    group)
      GRP="${PARTS[1]}"
      AGG="${PARTS[2]:-sum}"
      FIELD="${PARTS[3]}"
      MLR_CHAIN="$MLR_CHAIN then stats1 -a $AGG -f $FIELD -g $GRP"
      ;;
    join)
      FILE="${PARTS[1]}"
      KEY="${PARTS[2]}"
      MLR_CHAIN="$MLR_CHAIN then join -j $KEY -f $FILE"
      ;;
    sample)
      N="${PARTS[1]:-100}"
      MLR_CHAIN="$MLR_CHAIN then sample -k $N"
      ;;
    format)
      OUT_FMT="${PARTS[1]}"
      ;;
    *)
      echo "Warning: Unknown step '$CMD', skipping"
      ;;
  esac
done

# Remove leading " then "
MLR_CHAIN="${MLR_CHAIN# then }"

# If no steps, just cat
if [[ -z "$MLR_CHAIN" ]]; then
  MLR_CHAIN="cat"
fi

# Build full command
FULL_CMD="mlr --i${IN_FMT} --o${OUT_FMT} $MLR_CHAIN '$INPUT'"

if [[ "$VERBOSE" == "true" ]]; then
  echo "📋 Pipeline: $FULL_CMD"
  echo ""
fi

# Execute
if [[ -n "$OUTPUT" ]]; then
  eval $FULL_CMD > "$OUTPUT"
  echo "✅ Output written to $OUTPUT ($(wc -l < "$OUTPUT") lines)"
else
  eval $FULL_CMD
fi
