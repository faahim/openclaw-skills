#!/bin/bash
# S3 File Manager — Wrapper around aws-cli for common S3 operations
# Usage: bash s3m.sh <command> [args...]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Globals
ENDPOINT_FLAG=""

# Parse global flags from end of args
parse_global_flags() {
  local new_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --endpoint)
        ENDPOINT_FLAG="--endpoint-url $2"
        shift 2
        ;;
      *)
        new_args+=("$1")
        shift
        ;;
    esac
  done
  PARSED_ARGS=("${new_args[@]}")
}

human_size() {
  local bytes=$1
  if [[ $bytes -ge 1073741824 ]]; then
    echo "$(echo "scale=1; $bytes/1073741824" | bc) GB"
  elif [[ $bytes -ge 1048576 ]]; then
    echo "$(echo "scale=1; $bytes/1048576" | bc) MB"
  elif [[ $bytes -ge 1024 ]]; then
    echo "$(echo "scale=1; $bytes/1024" | bc) KB"
  else
    echo "${bytes} B"
  fi
}

cmd_list_buckets() {
  echo -e "${BLUE}📦 S3 Buckets:${NC}"
  aws s3api list-buckets $ENDPOINT_FLAG --output json | jq -r '.Buckets[] | "\(.Name)\t\(.CreationDate)"' | while IFS=$'\t' read -r name created; do
    region=$(aws s3api get-bucket-location --bucket "$name" $ENDPOINT_FLAG --output text 2>/dev/null || echo "unknown")
    [[ "$region" == "None" ]] && region="us-east-1"
    printf "  %-30s (%s)  Created: %s\n" "$name" "$region" "${created:0:10}"
  done
}

cmd_upload() {
  local source="$1"
  local dest="$2"
  shift 2
  local extra_args=("$@")
  
  local recursive=""
  local acl=""
  for arg in "${extra_args[@]}"; do
    case "$arg" in
      --recursive) recursive="--recursive" ;;
      --acl) acl="--acl" ;;
      public-read|private|authenticated-read) acl="--acl $arg" ;;
    esac
  done

  local start=$(date +%s%3N)
  if [[ -d "$source" ]] || [[ -n "$recursive" ]]; then
    aws s3 cp "$source" "$dest" --recursive $acl $ENDPOINT_FLAG
  else
    aws s3 cp "$source" "$dest" $acl $ENDPOINT_FLAG
  fi
  local end=$(date +%s%3N)
  local elapsed=$(echo "scale=1; ($end - $start) / 1000" | bc)
  
  if [[ -f "$source" ]]; then
    local size=$(stat -f%z "$source" 2>/dev/null || stat -c%s "$source" 2>/dev/null || echo "?")
    local hsize=$(human_size "$size" 2>/dev/null || echo "${size} B")
    echo -e "${GREEN}✅ Uploaded $(basename "$source") → $dest ($hsize, ${elapsed}s)${NC}"
  else
    echo -e "${GREEN}✅ Uploaded $source → $dest (${elapsed}s)${NC}"
  fi
}

cmd_download() {
  local source="$1"
  local dest="$2"
  shift 2
  local extra_args=("$@")
  
  local recursive=""
  for arg in "${extra_args[@]}"; do
    [[ "$arg" == "--recursive" ]] && recursive="--recursive"
  done

  aws s3 cp "$source" "$dest" $recursive $ENDPOINT_FLAG
  echo -e "${GREEN}✅ Downloaded $source → $dest${NC}"
}

cmd_sync() {
  local source="$1"
  local dest="$2"
  shift 2
  
  aws s3 sync "$source" "$dest" "$@" $ENDPOINT_FLAG
  echo -e "${GREEN}✅ Synced $source → $dest${NC}"
}

cmd_ls() {
  local path="${1:-}"
  shift || true
  
  local flags=""
  local human=""
  for arg in "$@"; do
    case "$arg" in
      --recursive) flags="$flags --recursive" ;;
      --human) human="--human-readable --summarize" ;;
    esac
  done

  if [[ -z "$path" ]]; then
    aws s3 ls $ENDPOINT_FLAG
  else
    aws s3 ls "$path" $flags $human $ENDPOINT_FLAG
  fi
}

cmd_find() {
  local path="$1"
  local pattern="$2"
  
  aws s3 ls "$path" --recursive $ENDPOINT_FLAG | grep -i "$pattern" || echo "No matches found."
}

cmd_du() {
  local path="$1"
  
  local result=$(aws s3 ls "$path" --recursive --summarize $ENDPOINT_FLAG | tail -2)
  echo -e "${BLUE}📊 Storage usage for $path${NC}"
  echo "$result"
}

cmd_rm() {
  local path="$1"
  shift
  
  local flags=""
  for arg in "$@"; do
    case "$arg" in
      --recursive) flags="$flags --recursive" ;;
      --dry-run) flags="$flags --dryrun" ;;
    esac
  done

  aws s3 rm "$path" $flags $ENDPOINT_FLAG
  echo -e "${GREEN}✅ Deleted $path${NC}"
}

cmd_create_bucket() {
  local name="$1"
  shift
  
  local region="${AWS_DEFAULT_REGION:-us-east-1}"
  for arg in "$@"; do
    [[ "$arg" == "--region" ]] && { shift; region="$1"; }
  done

  if [[ "$region" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "$name" $ENDPOINT_FLAG
  else
    aws s3api create-bucket --bucket "$name" --create-bucket-configuration LocationConstraint="$region" $ENDPOINT_FLAG
  fi
  echo -e "${GREEN}✅ Created bucket: $name ($region)${NC}"
}

cmd_delete_bucket() {
  local name="$1"
  aws s3api delete-bucket --bucket "$name" $ENDPOINT_FLAG
  echo -e "${GREEN}✅ Deleted bucket: $name${NC}"
}

cmd_bucket_info() {
  local name="$1"
  
  echo -e "${BLUE}📦 Bucket: $name${NC}"
  
  local region=$(aws s3api get-bucket-location --bucket "$name" $ENDPOINT_FLAG --output text 2>/dev/null || echo "unknown")
  [[ "$region" == "None" ]] && region="us-east-1"
  echo "  Region: $region"
  
  local summary=$(aws s3 ls "s3://$name" --recursive --summarize $ENDPOINT_FLAG 2>/dev/null | tail -2)
  echo "  $summary"
}

cmd_lifecycle() {
  local bucket="$1"
  shift
  
  local show=false
  local expire_days=""
  local glacier_days=""
  local abort_days=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --show) show=true; shift ;;
      --expire-days) expire_days="$2"; shift 2 ;;
      --glacier-days) glacier_days="$2"; shift 2 ;;
      --abort-incomplete-days) abort_days="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if $show; then
    echo -e "${BLUE}📋 Lifecycle rules for $bucket:${NC}"
    aws s3api get-bucket-lifecycle-configuration --bucket "$bucket" $ENDPOINT_FLAG 2>/dev/null || echo "  No lifecycle rules configured."
    return
  fi

  local rules='{"Rules":['
  local has_rule=false

  if [[ -n "$expire_days" ]]; then
    $has_rule && rules+=","
    rules+='{"ID":"auto-expire","Filter":{"Prefix":""},"Status":"Enabled","Expiration":{"Days":'$expire_days'}}'
    has_rule=true
  fi

  if [[ -n "$glacier_days" ]]; then
    $has_rule && rules+=","
    rules+='{"ID":"glacier-transition","Filter":{"Prefix":""},"Status":"Enabled","Transitions":[{"Days":'$glacier_days',"StorageClass":"GLACIER"}]}'
    has_rule=true
  fi

  if [[ -n "$abort_days" ]]; then
    $has_rule && rules+=","
    rules+='{"ID":"abort-incomplete","Filter":{"Prefix":""},"Status":"Enabled","AbortIncompleteMultipartUpload":{"DaysAfterInitiation":'$abort_days'}}'
    has_rule=true
  fi

  rules+=']}'

  aws s3api put-bucket-lifecycle-configuration --bucket "$bucket" --lifecycle-configuration "$rules" $ENDPOINT_FLAG
  echo -e "${GREEN}✅ Lifecycle policy applied to $bucket${NC}"
}

cmd_presign() {
  local path="$1"
  shift
  
  local expires=3600
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --expires) expires="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local url=$(aws s3 presign "$path" --expires-in "$expires" $ENDPOINT_FLAG)
  echo -e "${BLUE}🔗 Pre-signed URL (expires in ${expires}s):${NC}"
  echo "$url"
}

cmd_report() {
  echo -e "${BLUE}📊 S3 Storage Report ($(date +%Y-%m-%d))${NC}"
  echo ""
  printf "  %-30s %-10s %-12s %-10s\n" "Bucket" "Objects" "Size" "Region"
  printf "  %-30s %-10s %-12s %-10s\n" "------------------------------" "----------" "------------" "----------"
  
  local total_objects=0
  local total_size=0
  
  aws s3api list-buckets $ENDPOINT_FLAG --output json | jq -r '.Buckets[].Name' | while read -r bucket; do
    local region=$(aws s3api get-bucket-location --bucket "$bucket" $ENDPOINT_FLAG --output text 2>/dev/null || echo "?")
    [[ "$region" == "None" ]] && region="us-east-1"
    
    local info=$(aws s3 ls "s3://$bucket" --recursive --summarize $ENDPOINT_FLAG 2>/dev/null | tail -2)
    local objects=$(echo "$info" | grep "Total Objects" | awk '{print $3}')
    local size=$(echo "$info" | grep "Total Size" | awk '{print $3}')
    
    objects=${objects:-0}
    size=${size:-0}
    local hsize=$(human_size "$size")
    
    printf "  %-30s %-10s %-12s %-10s\n" "$bucket" "$objects" "$hsize" "$region"
  done
}

# --- Main ---

if [[ $# -lt 1 ]]; then
  echo "Usage: s3m.sh <command> [args...]"
  echo ""
  echo "Commands:"
  echo "  list-buckets              List all S3 buckets"
  echo "  upload <src> <dst>        Upload file(s) to S3"
  echo "  download <src> <dst>      Download file(s) from S3"
  echo "  sync <src> <dst>          Sync directories"
  echo "  ls [path]                 List files"
  echo "  find <path> <pattern>     Search files by pattern"
  echo "  du <path>                 Show storage usage"
  echo "  rm <path>                 Delete file(s)"
  echo "  create-bucket <name>      Create a new bucket"
  echo "  delete-bucket <name>      Delete an empty bucket"
  echo "  bucket-info <name>        Show bucket details"
  echo "  lifecycle <bucket>        Manage lifecycle policies"
  echo "  presign <path>            Generate pre-signed URL"
  echo "  report                    Full storage report"
  echo ""
  echo "Global flags:"
  echo "  --endpoint <url>          Use S3-compatible endpoint"
  exit 1
fi

COMMAND="$1"
shift

parse_global_flags "$@"
set -- "${PARSED_ARGS[@]}"

case "$COMMAND" in
  list-buckets)   cmd_list_buckets "$@" ;;
  upload)         cmd_upload "$@" ;;
  download)       cmd_download "$@" ;;
  sync)           cmd_sync "$@" ;;
  ls)             cmd_ls "$@" ;;
  find)           cmd_find "$@" ;;
  du)             cmd_du "$@" ;;
  rm)             cmd_rm "$@" ;;
  create-bucket)  cmd_create_bucket "$@" ;;
  delete-bucket)  cmd_delete_bucket "$@" ;;
  bucket-info)    cmd_bucket_info "$@" ;;
  lifecycle)      cmd_lifecycle "$@" ;;
  presign)        cmd_presign "$@" ;;
  report)         cmd_report "$@" ;;
  *)
    echo -e "${RED}❌ Unknown command: $COMMAND${NC}"
    echo "Run 's3m.sh' without arguments to see available commands."
    exit 1
    ;;
esac
