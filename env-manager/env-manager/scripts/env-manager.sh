#!/bin/bash
# env-manager.sh — Manage .env files with encryption, diffing, templating
# Requires: age (https://github.com/FiloSottile/age), bash 4+

set -uo pipefail

VERSION="1.0.0"
CONFIG_DIR="${HOME}/.config/env-manager"
KEY_FILE="${CONFIG_DIR}/key.txt"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
BACKUP_DIR="${CONFIG_DIR}/backups"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_err()  { echo -e "${RED}❌ $1${NC}"; }
log_info() { echo -e "${BLUE}📋 $1${NC}"; }

usage() {
  cat <<EOF
env-manager v${VERSION} — Manage .env files

Usage: env-manager.sh <command> [options]

Commands:
  init                        Initialize env-manager (generate key + config)
  encrypt <file> [-o output]  Encrypt a .env file with age
  decrypt <file> [-o output]  Decrypt a .env.age file
  diff <file1> <file2>        Compare two .env files (supports .age)
  template <file> [-o output] Generate a template (keys only, no values)
  validate <file> --template <tmpl> [--strict]  Check for missing variables
  generate <template> [-o output]  Create .env from template with placeholders
  list <file>                 List all variables in a .env
  search <var> <files...>     Search for a variable across .env files
  sync <source> <target>      Add missing vars from source to target
  rotate-key <dir>            Generate new key and re-encrypt all .age files

Options:
  -o, --output <file>   Output file path
  --strict              Exit with code 1 on validation failure
  -h, --help            Show this help
  -v, --version         Show version
EOF
}

# Parse .env file into sorted KEY=VALUE pairs (strips comments, empty lines)
parse_env() {
  local file="$1"
  grep -v '^\s*#' "$file" | grep -v '^\s*$' | sort
}

# Extract just keys from a .env file
parse_keys() {
  local file="$1"
  parse_env "$file" | cut -d'=' -f1
}

# Auto-decrypt .age files to temp, return path
resolve_file() {
  local file="$1"
  if [[ "$file" == *.age ]]; then
    local tmp
    tmp=$(mktemp /tmp/env-manager.XXXXXX)
    age --decrypt -i "$KEY_FILE" -o "$tmp" "$file" 2>/dev/null || {
      log_err "Failed to decrypt $file"
      rm -f "$tmp"
      exit 1
    }
    echo "$tmp"
    return 0
  fi
  echo "$file"
}

# Backup a file before overwriting
backup_file() {
  local file="$1"
  if [ -f "$file" ]; then
    mkdir -p "$BACKUP_DIR"
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp "$file" "${BACKUP_DIR}/$(basename "$file").${ts}.bak"
  fi
}

cmd_init() {
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$CONFIG_DIR"

  if [ -f "$KEY_FILE" ]; then
    log_warn "Key already exists at $KEY_FILE"
    read -p "Overwrite? [y/N]: " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && exit 0
    backup_file "$KEY_FILE"
  fi

  age-keygen -o "$KEY_FILE" 2>/dev/null
  chmod 600 "$KEY_FILE"
  log_ok "Age key generated at $KEY_FILE"

  # Extract public key
  local pubkey
  pubkey=$(grep "public key:" "$KEY_FILE" | awk '{print $NF}')
  echo "🔑 Public key: $pubkey"

  if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<YAML
# env-manager configuration
key_path: ${KEY_FILE}
template_name: .env.template
redact_patterns:
  - "*_SECRET*"
  - "*_KEY*"
  - "*_PASSWORD*"
  - "*_TOKEN*"
backup: true
backup_dir: ${BACKUP_DIR}
YAML
    log_ok "Config created at $CONFIG_FILE"
  fi

  log_warn "Back up $KEY_FILE — losing it means losing access to encrypted .env files!"
}

cmd_encrypt() {
  local input="$1"
  local output="${2:-${input}.age}"

  [ ! -f "$input" ] && { log_err "File not found: $input"; exit 1; }
  [ ! -f "$KEY_FILE" ] && { log_err "No key found. Run: env-manager.sh init"; exit 1; }

  local pubkey
  pubkey=$(grep "public key:" "$KEY_FILE" | awk '{print $NF}')
  local var_count
  var_count=$(parse_keys "$input" | wc -l | tr -d ' ')

  age -r "$pubkey" -o "$output" "$input"
  local size
  size=$(wc -c < "$output" | tr -d ' ')

  log_ok "Encrypted $input → $output ($var_count variables, ${size}B)"
  echo -e "${BLUE}💡 Add $(basename "$input") to .gitignore, commit $(basename "$output") instead${NC}"
}

cmd_decrypt() {
  local input="$1"
  local output="${2:-${input%.age}}"

  [ ! -f "$input" ] && { log_err "File not found: $input"; exit 1; }
  [ ! -f "$KEY_FILE" ] && { log_err "No key found. Run: env-manager.sh init"; exit 1; }

  if [ "$output" == "$input" ]; then
    output="${input}.decrypted"
  fi

  backup_file "$output"
  age --decrypt -i "$KEY_FILE" -o "$output" "$input"

  local var_count
  var_count=$(parse_keys "$output" | wc -l | tr -d ' ')
  log_ok "Decrypted $input → $output ($var_count variables)"
}

cmd_diff() {
  local file1="$1"
  local file2="$2"
  local tmpfiles=()

  [ ! -f "$file1" ] && { log_err "File not found: $file1"; exit 1; }
  [ ! -f "$file2" ] && { log_err "File not found: $file2"; exit 1; }

  local resolved1 resolved2
  resolved1=$(resolve_file "$file1")
  resolved2=$(resolve_file "$file2")
  [[ "$resolved1" != "$file1" ]] && tmpfiles+=("$resolved1")
  [[ "$resolved2" != "$file2" ]] && tmpfiles+=("$resolved2")

  echo -e "${BLUE}📊 Environment Diff: $file1 ↔ $file2${NC}"
  echo "────────────────────────────────────────"

  local keys1 keys2
  keys1=$(parse_keys "$resolved1")
  keys2=$(parse_keys "$resolved2")

  # Only in file1
  local only1
  only1=$(comm -23 <(echo "$keys1") <(echo "$keys2"))
  if [ -n "$only1" ]; then
    echo -e "\n${YELLOW}ONLY IN $file1:${NC}"
    while IFS= read -r key; do
      local val
      val=$(grep "^${key}=" "$resolved1" | head -1 | cut -d'=' -f2-)
      echo "  ${key}=${val}"
    done <<< "$only1"
  fi

  # Only in file2
  local only2
  only2=$(comm -13 <(echo "$keys1") <(echo "$keys2"))
  if [ -n "$only2" ]; then
    echo -e "\n${YELLOW}ONLY IN $file2:${NC}"
    while IFS= read -r key; do
      local val
      val=$(grep "^${key}=" "$resolved2" | head -1 | cut -d'=' -f2-)
      echo "  ${key}=${val}"
    done <<< "$only2"
  fi

  # Different values
  local common
  common=$(comm -12 <(echo "$keys1") <(echo "$keys2"))
  local diff_count=0
  local same_count=0
  local diff_output=""

  while IFS= read -r key; do
    [ -z "$key" ] && continue
    local val1 val2
    val1=$(grep "^${key}=" "$resolved1" | head -1 | cut -d'=' -f2-)
    val2=$(grep "^${key}=" "$resolved2" | head -1 | cut -d'=' -f2-)
    if [ "$val1" != "$val2" ]; then
      diff_output+="  ${key}: ${val1} → ${val2}\n"
      ((diff_count++))
    else
      ((same_count++))
    fi
  done <<< "$common"

  if [ $diff_count -gt 0 ]; then
    echo -e "\n${RED}DIFFERENT VALUES:${NC}"
    echo -e "$diff_output"
  fi

  echo -e "\n${GREEN}SAME IN BOTH: $same_count variables${NC}"

  # Cleanup temp files
  for tmp in "${tmpfiles[@]}"; do
    rm -f "$tmp"
  done
}

cmd_template() {
  local input="$1"
  local output="${2:-${input}.template}"

  [ ! -f "$input" ] && { log_err "File not found: $input"; exit 1; }

  local resolved
  resolved=$(resolve_file "$input")

  {
    echo "# Environment Template"
    echo "# Generated from $(basename "$input") on $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Fill in values and rename to .env"
    echo ""
    parse_env "$resolved" | while IFS='=' read -r key value; do
      # Check if value looks like a secret
      if echo "$key" | grep -qiE '(SECRET|KEY|PASSWORD|TOKEN|PRIVATE)'; then
        echo "${key}=<required-secret>"
      elif [ -z "$value" ]; then
        echo "${key}=<required>"
      else
        echo "# Default: ${value}"
        echo "${key}=${value}"
      fi
    done
  } > "$output"

  [[ "$resolved" != "$input" ]] && rm -f "$resolved"

  local key_count
  key_count=$(parse_keys "$input" | wc -l | tr -d ' ')
  log_ok "Template created: $output ($key_count variables)"
}

cmd_validate() {
  local input="$1"
  local template="$2"
  local strict="${3:-false}"

  [ ! -f "$input" ] && { log_err "File not found: $input"; exit 1; }
  [ ! -f "$template" ] && { log_err "Template not found: $template"; exit 1; }

  local resolved_input resolved_template
  resolved_input=$(resolve_file "$input")
  resolved_template=$(resolve_file "$template")

  local input_keys template_keys
  input_keys=$(parse_keys "$resolved_input")
  template_keys=$(parse_keys "$resolved_template")

  local missing
  missing=$(comm -13 <(echo "$input_keys") <(echo "$template_keys"))

  local extra
  extra=$(comm -23 <(echo "$input_keys") <(echo "$template_keys"))

  local present
  present=$(comm -12 <(echo "$input_keys") <(echo "$template_keys") | wc -l | tr -d ' ')

  if [ -z "$missing" ]; then
    log_ok "All $present required variables present in $input"
  else
    local missing_count
    missing_count=$(echo "$missing" | wc -l | tr -d ' ')
    log_err "Missing $missing_count variables in $input:"
    echo "$missing" | while read -r key; do
      echo "  - $key"
    done
  fi

  if [ -n "$extra" ]; then
    local extra_count
    extra_count=$(echo "$extra" | wc -l | tr -d ' ')
    log_info "$extra_count extra variables not in template (OK)"
  fi

  [[ "$resolved_input" != "$input" ]] && rm -f "$resolved_input"
  [[ "$resolved_template" != "$template" ]] && rm -f "$resolved_template"

  if [ -n "$missing" ] && [ "$strict" == "true" ]; then
    exit 1
  fi
}

cmd_generate() {
  local template="$1"
  local output="${2:-.env.local}"

  [ ! -f "$template" ] && { log_err "Template not found: $template"; exit 1; }

  local resolved
  resolved=$(resolve_file "$template")

  backup_file "$output"

  {
    echo "# Generated from $(basename "$template") on $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "# Fill in the <required> values"
    echo ""
    cat "$resolved"
  } > "$output"

  [[ "$resolved" != "$template" ]] && rm -f "$resolved"

  log_ok "Generated $output from $(basename "$template")"
  log_warn "Fill in values marked <required> or <required-secret>"
}

cmd_list() {
  local input="$1"

  [ ! -f "$input" ] && { log_err "File not found: $input"; exit 1; }

  local resolved
  resolved=$(resolve_file "$input")

  echo -e "${BLUE}📋 Variables in $input:${NC}"
  echo "────────────────────────────────────────"

  local count=0
  parse_env "$resolved" | while IFS='=' read -r key value; do
    # Redact sensitive values
    if echo "$key" | grep -qiE '(SECRET|KEY|PASSWORD|TOKEN|PRIVATE|CREDENTIAL)'; then
      echo "  ${key}=****"
    else
      echo "  ${key}=${value}"
    fi
    ((count++))
  done

  local total
  total=$(parse_keys "$resolved" | wc -l | tr -d ' ')
  echo ""
  echo "Total: $total variables"

  [[ "$resolved" != "$input" ]] && rm -f "$resolved"
}

cmd_search() {
  local var="$1"
  shift
  local files=("$@")

  echo -e "${BLUE}🔍 Searching for: $var${NC}"
  echo "────────────────────────────────────────"

  local found=0
  for file in "${files[@]}"; do
    [ ! -f "$file" ] && continue
    local resolved
    resolved=$(resolve_file "$file")
    local match
    match=$(grep "^${var}=" "$resolved" 2>/dev/null | head -1)
    if [ -n "$match" ]; then
      local val
      val=$(echo "$match" | cut -d'=' -f2-)
      if echo "$var" | grep -qiE '(SECRET|KEY|PASSWORD|TOKEN|PRIVATE)'; then
        echo "  $file = ****"
      else
        echo "  $file = $val"
      fi
      ((found++))
    fi
    [[ "$resolved" != "$file" ]] && rm -f "$resolved"
  done

  if [ $found -eq 0 ]; then
    log_warn "$var not found in any file"
  else
    echo ""
    echo "Found in $found file(s)"
  fi
}

cmd_sync() {
  local source="$1"
  local target="$2"

  [ ! -f "$source" ] && { log_err "Source not found: $source"; exit 1; }
  [ ! -f "$target" ] && { log_err "Target not found: $target"; exit 1; }

  local resolved_source resolved_target
  resolved_source=$(resolve_file "$source")
  resolved_target=$(resolve_file "$target")

  local source_keys target_keys
  source_keys=$(parse_keys "$resolved_source")
  target_keys=$(parse_keys "$resolved_target")

  local missing
  missing=$(comm -23 <(echo "$source_keys") <(echo "$target_keys"))

  if [ -z "$missing" ]; then
    log_ok "Target $target already has all variables from $source"
    [[ "$resolved_source" != "$source" ]] && rm -f "$resolved_source"
    [[ "$resolved_target" != "$target" ]] && rm -f "$resolved_target"
    return
  fi

  local count
  count=$(echo "$missing" | wc -l | tr -d ' ')
  echo -e "${BLUE}🔄 Syncing $source → $target${NC}"
  echo "New variables to add:"
  while IFS= read -r key; do
    local val
    val=$(grep "^${key}=" "$resolved_source" | head -1 | cut -d'=' -f2-)
    if [ -n "$val" ]; then
      echo "  ${key}=${val} (default)"
    else
      echo "  ${key}= (no default)"
    fi
  done <<< "$missing"

  echo ""
  read -p "Add these $count variables? [y/N]: " confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    backup_file "$target"
    echo "" >> "$target"
    echo "# Synced from $(basename "$source") on $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$target"
    while IFS= read -r key; do
      local line
      line=$(grep "^${key}=" "$resolved_source" | head -1)
      echo "$line" >> "$target"
    done <<< "$missing"
    log_ok "Added $count variables to $target"
  else
    log_info "Cancelled"
  fi

  [[ "$resolved_source" != "$source" ]] && rm -f "$resolved_source"
  [[ "$resolved_target" != "$target" ]] && rm -f "$resolved_target"
}

cmd_rotate_key() {
  local dir="$1"

  [ ! -d "$dir" ] && { log_err "Directory not found: $dir"; exit 1; }
  [ ! -f "$KEY_FILE" ] && { log_err "No key found. Run: env-manager.sh init"; exit 1; }

  local age_files
  age_files=$(find "$dir" -name "*.age" -type f)

  if [ -z "$age_files" ]; then
    log_warn "No .age files found in $dir"
    return
  fi

  local count
  count=$(echo "$age_files" | wc -l | tr -d ' ')
  echo -e "${BLUE}🔄 Rotating encryption key for $count file(s)...${NC}"

  # Backup old key
  cp "$KEY_FILE" "${KEY_FILE}.bak"

  # Decrypt all files with old key
  local tmpdir
  tmpdir=$(mktemp -d /tmp/env-manager-rotate.XXXXXX)

  while IFS= read -r agefile; do
    local base
    base=$(basename "$agefile")
    age --decrypt -i "${KEY_FILE}.bak" -o "${tmpdir}/${base}" "$agefile"
  done <<< "$age_files"

  # Generate new key
  age-keygen -o "$KEY_FILE" 2>/dev/null
  chmod 600 "$KEY_FILE"
  log_ok "New key generated"

  local pubkey
  pubkey=$(grep "public key:" "$KEY_FILE" | awk '{print $NF}')

  # Re-encrypt with new key
  while IFS= read -r agefile; do
    local base
    base=$(basename "$agefile")
    age -r "$pubkey" -o "$agefile" "${tmpdir}/${base}"
  done <<< "$age_files"

  # Cleanup
  rm -rf "$tmpdir"

  log_ok "Re-encrypted $count files"
  log_warn "Old key backed up to ${KEY_FILE}.bak"
}

# ─── Main ────────────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
  usage
  exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
  init)
    cmd_init
    ;;
  encrypt)
    output=""
    input="$1"; shift
    while [[ $# -gt 0 ]]; do
      case $1 in
        -o|--output) output="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    cmd_encrypt "$input" "${output:-${input}.age}"
    ;;
  decrypt)
    output=""
    input="$1"; shift
    while [[ $# -gt 0 ]]; do
      case $1 in
        -o|--output) output="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    cmd_decrypt "$input" "${output:-${input%.age}}"
    ;;
  diff)
    [ $# -lt 2 ] && { log_err "Usage: env-manager.sh diff <file1> <file2>"; exit 1; }
    cmd_diff "$1" "$2"
    ;;
  template)
    output=""
    input="$1"; shift
    while [[ $# -gt 0 ]]; do
      case $1 in
        -o|--output) output="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    cmd_template "$input" "${output:-${input}.template}"
    ;;
  validate)
    template=""
    strict="false"
    input="$1"; shift
    while [[ $# -gt 0 ]]; do
      case $1 in
        --template) template="$2"; shift 2 ;;
        --strict) strict="true"; shift ;;
        *) shift ;;
      esac
    done
    [ -z "$template" ] && { log_err "Usage: env-manager.sh validate <file> --template <tmpl>"; exit 1; }
    cmd_validate "$input" "$template" "$strict"
    ;;
  generate)
    output=""
    input="$1"; shift
    while [[ $# -gt 0 ]]; do
      case $1 in
        -o|--output) output="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    cmd_generate "$input" "${output:-.env.local}"
    ;;
  list)
    [ $# -lt 1 ] && { log_err "Usage: env-manager.sh list <file>"; exit 1; }
    cmd_list "$1"
    ;;
  search)
    [ $# -lt 2 ] && { log_err "Usage: env-manager.sh search <var> <files...>"; exit 1; }
    var="$1"; shift
    cmd_search "$var" "$@"
    ;;
  sync)
    [ $# -lt 2 ] && { log_err "Usage: env-manager.sh sync <source> <target>"; exit 1; }
    cmd_sync "$1" "$2"
    ;;
  rotate-key)
    [ $# -lt 1 ] && { log_err "Usage: env-manager.sh rotate-key <dir>"; exit 1; }
    cmd_rotate_key "$1"
    ;;
  -h|--help|help)
    usage
    ;;
  -v|--version|version)
    echo "env-manager v${VERSION}"
    ;;
  *)
    log_err "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
