#!/bin/bash
# env-manager — Manage .env files: encrypt, decrypt, sync, validate, diff, protect
set -euo pipefail

VERSION="1.0.0"
KEY_DIR="${ENV_MANAGER_KEY_DIR:-$HOME/.config/env-manager}"
KEY_FILE="${ENV_MANAGER_KEY:-$KEY_DIR/key.txt}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_ok()   { echo -e "${GREEN}✅ $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
log_err()  { echo -e "${RED}❌ $*${NC}"; }
log_info() { echo -e "${BLUE}ℹ️  $*${NC}"; }

# ─── HELPERS ────────────────────────────────────────────────

ensure_age() {
  if ! command -v age &>/dev/null; then
    log_err "age not installed. Install: sudo apt-get install age (or brew install age)"
    exit 1
  fi
}

ensure_key() {
  if [ ! -f "$KEY_FILE" ]; then
    log_err "No encryption key found at $KEY_FILE"
    echo "  Generate one: age-keygen -o $KEY_FILE"
    exit 1
  fi
}

get_public_key() {
  age-keygen -y "$KEY_FILE" 2>/dev/null
}

parse_env_file() {
  local file="$1"
  # Output: KEY=VALUE lines, skipping comments and blanks
  grep -v '^\s*#' "$file" 2>/dev/null | grep -v '^\s*$' | sort
}

get_env_keys() {
  local file="$1"
  parse_env_file "$file" | cut -d= -f1
}

get_env_value() {
  local file="$1" key="$2"
  grep "^${key}=" "$file" 2>/dev/null | head -1 | cut -d= -f2-
}

# ─── COMMANDS ───────────────────────────────────────────────

cmd_init() {
  local project_dir="${1:-.}"
  
  echo "🔧 Initializing env-manager in $project_dir"
  
  # Create .env.example if .env exists
  if [ -f "$project_dir/.env" ]; then
    cmd_example "$project_dir/.env" "$project_dir/.env.example"
  fi
  
  # Create schema template
  if [ ! -f "$project_dir/.env.schema" ]; then
    cat > "$project_dir/.env.schema" << 'SCHEMA'
# .env.schema — Validation rules
# Format: VAR_NAME=required|optional [|default=X] [|type=string|number|bool|url] [|values=a,b,c]
#
# Examples:
# DATABASE_URL=required|type=url
# DEBUG=optional|default=false|type=bool
# LOG_LEVEL=optional|default=info|values=debug,info,warn,error
SCHEMA
    log_ok "Created .env.schema template"
  fi
  
  # Update .gitignore
  cmd_protect "$project_dir" --quiet
  
  log_ok "Project initialized in $project_dir"
}

cmd_encrypt() {
  local input="$1"
  local output="${2:-${input}.age}"
  
  ensure_age
  ensure_key
  
  if [ ! -f "$input" ]; then
    log_err "File not found: $input"
    exit 1
  fi
  
  local pubkey
  pubkey=$(get_public_key)
  
  age -r "$pubkey" -o "$output" "$input"
  log_ok "Encrypted → $output"
  echo "  Safe to commit $output to git"
}

cmd_decrypt() {
  local input="$1"
  local output="${2:-${input%.age}}"
  local custom_key="${KEY_FILE}"
  
  # Check for --key flag
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --key) custom_key="$2"; shift 2 ;;
      *) output="$1"; shift ;;
    esac
  done
  
  ensure_age
  
  if [ ! -f "$input" ]; then
    log_err "File not found: $input"
    exit 1
  fi
  
  age -d -i "$custom_key" -o "$output" "$input"
  log_ok "Decrypted → $output"
}

cmd_encrypt_all() {
  local dir="${1:-.}"
  local count=0
  
  ensure_age
  ensure_key
  
  local pubkey
  pubkey=$(get_public_key)
  
  while IFS= read -r -d '' envfile; do
    local outfile="${envfile}.age"
    age -r "$pubkey" -o "$outfile" "$envfile"
    log_ok "Encrypted: $envfile → $outfile"
    ((count++))
  done < <(find "$dir" -name ".env" -not -path "*/node_modules/*" -not -path "*/.git/*" -print0)
  
  log_ok "Encrypted $count .env files"
}

cmd_sync() {
  local source="$1"
  local target="$2"
  
  if [ ! -f "$source" ]; then
    log_err "Source not found: $source"
    exit 1
  fi
  
  echo "🔄 Syncing $source → $target"
  
  local added=0 kept=0 target_only=0
  local tmp_target
  tmp_target=$(mktemp)
  
  # Start with target contents (if exists)
  if [ -f "$target" ]; then
    cp "$target" "$tmp_target"
  else
    touch "$tmp_target"
  fi
  
  # Add vars from source that aren't in target
  while IFS= read -r line; do
    local key
    key=$(echo "$line" | cut -d= -f1)
    if ! grep -q "^${key}=" "$tmp_target" 2>/dev/null; then
      echo "$line" >> "$tmp_target"
      echo -e "  ${GREEN}+ Added: $key${NC} (from source)"
      ((added++))
    else
      echo -e "  ${BLUE}= Kept: $key${NC} (target override)"
      ((kept++))
    fi
  done < <(parse_env_file "$source")
  
  # Count target-only vars
  while IFS= read -r key; do
    if ! grep -q "^${key}=" "$source" 2>/dev/null; then
      echo -e "  ${YELLOW}- Target-only: $key${NC} (kept)"
      ((target_only++))
    fi
  done < <(get_env_keys "$tmp_target")
  
  # Sort and write
  sort "$tmp_target" > "$target"
  rm "$tmp_target"
  
  local total=$((added + kept + target_only))
  log_ok "Synced $total vars ($added added, $kept kept, $target_only target-only)"
}

cmd_validate() {
  local envfile="$1"
  shift
  local schema=""
  local strict=false
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --schema) schema="$2"; shift 2 ;;
      --strict) strict=true; shift ;;
      *) shift ;;
    esac
  done
  
  if [ ! -f "$envfile" ]; then
    log_err "Env file not found: $envfile"
    exit 1
  fi
  
  # Auto-detect schema
  if [ -z "$schema" ]; then
    local dir
    dir=$(dirname "$envfile")
    if [ -f "$dir/.env.schema" ]; then
      schema="$dir/.env.schema"
    else
      log_err "No schema found. Use --schema or create .env.schema"
      exit 1
    fi
  fi
  
  if [ ! -f "$schema" ]; then
    log_err "Schema not found: $schema"
    exit 1
  fi
  
  echo "🔍 Validating $envfile against $schema"
  echo ""
  
  local errors=0 warnings=0
  
  while IFS= read -r rule; do
    # Skip comments and blanks
    [[ "$rule" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${rule// }" ]] && continue
    
    local varname
    varname=$(echo "$rule" | cut -d= -f1)
    local constraints
    constraints=$(echo "$rule" | cut -d= -f2-)
    
    local required=false default_val="" var_type="string" allowed_values=""
    
    IFS='|' read -ra parts <<< "$constraints"
    for part in "${parts[@]}"; do
      case "$part" in
        required) required=true ;;
        optional) required=false ;;
        default=*) default_val="${part#default=}" ;;
        type=*) var_type="${part#type=}" ;;
        values=*) allowed_values="${part#values=}" ;;
      esac
    done
    
    local value
    value=$(get_env_value "$envfile" "$varname")
    
    if [ -z "$value" ]; then
      if $required; then
        log_err "$varname = MISSING (required)"
        ((errors++))
      elif [ -n "$default_val" ]; then
        log_ok "$varname = $default_val (default)"
      else
        log_warn "$varname = empty (optional)"
        ((warnings++))
      fi
      continue
    fi
    
    # Type validation
    local type_ok=true
    case "$var_type" in
      number)
        [[ "$value" =~ ^[0-9]+$ ]] || type_ok=false
        ;;
      bool)
        [[ "$value" =~ ^(true|false|1|0|yes|no)$ ]] || type_ok=false
        ;;
      url)
        [[ "$value" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]] || type_ok=false
        ;;
    esac
    
    if ! $type_ok; then
      log_err "$varname = $value (invalid $var_type)"
      ((errors++))
      continue
    fi
    
    # Values validation
    if [ -n "$allowed_values" ]; then
      local found=false
      IFS=',' read -ra vals <<< "$allowed_values"
      for v in "${vals[@]}"; do
        [ "$value" = "$v" ] && found=true
      done
      if ! $found; then
        log_err "$varname = $value (not in: $allowed_values)"
        ((errors++))
        continue
      fi
    fi
    
    # Mask secrets
    if [[ "$varname" =~ (KEY|SECRET|TOKEN|PASSWORD|PASS) ]]; then
      log_ok "$varname = *** (set)"
    else
      log_ok "$varname = $value"
    fi
    
  done < "$schema"
  
  echo ""
  if [ $errors -gt 0 ]; then
    log_err "Validation FAILED: $errors error(s), $warnings warning(s)"
    exit 1
  else
    log_ok "Validation PASSED ($warnings warning(s))"
  fi
}

cmd_diff() {
  local file1="$1"
  local file2="$2"
  
  if [ ! -f "$file1" ] || [ ! -f "$file2" ]; then
    log_err "Both files must exist"
    exit 1
  fi
  
  echo "📊 Environment Diff: $file1 ↔ $file2"
  echo "─────────────────────────────────────────"
  printf "%-25s │ %-20s │ %-20s\n" "Variable" "$(basename "$file1")" "$(basename "$file2")"
  echo "─────────────────────────────────────────"
  
  local different=0 only1=0 only2=0
  
  # Get all unique keys
  local all_keys
  all_keys=$(cat <(get_env_keys "$file1") <(get_env_keys "$file2") | sort -u)
  
  while IFS= read -r key; do
    [ -z "$key" ] && continue
    local val1 val2
    val1=$(get_env_value "$file1" "$key")
    val2=$(get_env_value "$file2" "$key")
    
    # Mask secrets
    local d_val1="$val1" d_val2="$val2"
    if [[ "$key" =~ (KEY|SECRET|TOKEN|PASSWORD|PASS) ]]; then
      [ -n "$val1" ] && d_val1="***"
      [ -n "$val2" ] && d_val2="***"
    fi
    
    # Truncate long values
    [ ${#d_val1} -gt 18 ] && d_val1="${d_val1:0:15}..."
    [ ${#d_val2} -gt 18 ] && d_val2="${d_val2:0:15}..."
    
    if [ -z "$val1" ]; then
      printf "%-25s │ %-20s │ %-20s\n" "$key" "(missing)" "$d_val2"
      ((only2++))
    elif [ -z "$val2" ]; then
      printf "%-25s │ %-20s │ %-20s\n" "$key" "$d_val1" "(missing)"
      ((only1++))
    elif [ "$val1" != "$val2" ]; then
      printf "%-25s │ %-20s │ %-20s\n" "$key" "$d_val1" "$d_val2"
      ((different++))
    fi
  done <<< "$all_keys"
  
  echo "─────────────────────────────────────────"
  echo "Summary: $different different, $only1 only-in-$(basename "$file1"), $only2 only-in-$(basename "$file2")"
}

cmd_example() {
  local input="$1"
  local output="${2:-${input%.env*}.env.example}"
  
  if [ ! -f "$input" ]; then
    log_err "File not found: $input"
    exit 1
  fi
  
  local count=0
  > "$output"
  
  while IFS= read -r line; do
    # Pass through comments
    if [[ "$line" =~ ^[[:space:]]*# ]] || [ -z "$line" ]; then
      echo "$line" >> "$output"
      continue
    fi
    
    local key value
    key=$(echo "$line" | cut -d= -f1)
    value=$(echo "$line" | cut -d= -f2-)
    
    # Strip secrets, keep safe defaults
    if [[ "$key" =~ (KEY|SECRET|TOKEN|PASSWORD|PASS|PRIVATE) ]]; then
      echo "${key}=" >> "$output"
    elif [[ "$value" =~ ^(true|false|[0-9]+|debug|info|warn|error)$ ]]; then
      echo "${key}=${value}" >> "$output"
    else
      echo "${key}=" >> "$output"
    fi
    ((count++))
  done < "$input"
  
  log_ok "Generated $output ($count vars, secrets stripped, defaults kept)"
}

cmd_protect() {
  local project_dir="${1:-.}"
  local quiet=false
  [ "${2:-}" = "--quiet" ] && quiet=true
  
  # Update .gitignore
  local gitignore="$project_dir/.gitignore"
  local entries=(".env" ".env.local" ".env.*.local" ".env.production" ".env.staging")
  local added=0
  
  touch "$gitignore"
  for entry in "${entries[@]}"; do
    if ! grep -qxF "$entry" "$gitignore"; then
      echo "$entry" >> "$gitignore"
      ((added++))
    fi
  done
  
  $quiet || log_ok ".gitignore updated ($added entries added)"
  
  # Install pre-commit hook
  local hooks_dir="$project_dir/.git/hooks"
  if [ -d "$project_dir/.git" ]; then
    mkdir -p "$hooks_dir"
    cat > "$hooks_dir/pre-commit" << 'HOOK'
#!/bin/bash
# env-manager: Block .env file commits
FILES=$(git diff --cached --name-only | grep -E '\.env$|\.env\.[^age]' | grep -v '.env.example' | grep -v '.env.schema' | grep -v '.env.age')
if [ -n "$FILES" ]; then
  echo "❌ BLOCKED: Attempting to commit .env files:"
  echo "$FILES"
  echo ""
  echo "Encrypt first: env-manager encrypt <file>"
  echo "Or force: git commit --no-verify"
  exit 1
fi
HOOK
    chmod +x "$hooks_dir/pre-commit"
    $quiet || log_ok "pre-commit hook installed"
  fi
  
  # Scan git history
  if [ -d "$project_dir/.git" ] && ! $quiet; then
    local leaked
    leaked=$(cd "$project_dir" && git log --all --diff-filter=A --name-only --pretty=format: 2>/dev/null | grep -E '\.env$' | head -5)
    if [ -n "$leaked" ]; then
      log_warn "Found .env in git history:"
      echo "$leaked" | while read -r f; do echo "  - $f"; done
      echo "  Remove with: git filter-branch or BFG Repo-Cleaner"
    fi
  fi
}

cmd_rotate() {
  local dir="$1"
  shift
  local old_key="" new_key=""
  
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --old-key) old_key="$2"; shift 2 ;;
      --new-key) new_key="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  
  ensure_age
  
  [ -z "$old_key" ] && old_key="$KEY_FILE"
  [ -z "$new_key" ] && { log_err "Specify --new-key"; exit 1; }
  
  local new_pubkey
  new_pubkey=$(age-keygen -y "$new_key" 2>/dev/null)
  local count=0
  
  while IFS= read -r -d '' agefile; do
    local tmp
    tmp=$(mktemp)
    age -d -i "$old_key" -o "$tmp" "$agefile"
    age -r "$new_pubkey" -o "$agefile" "$tmp"
    rm "$tmp"
    log_ok "Re-encrypted: $agefile"
    ((count++))
  done < <(find "$dir" -name "*.env.age" -o -name ".env.age" | tr '\n' '\0')
  
  log_ok "Rotated $count files to new key"
}

# ─── MAIN ───────────────────────────────────────────────────

usage() {
  cat << EOF
env-manager v$VERSION — Manage .env files

USAGE:
  env-manager <command> [options]

COMMANDS:
  init <dir>                    Initialize project with env-manager
  encrypt <file> [output]       Encrypt .env file with age
  decrypt <file> [output]       Decrypt .env.age file
  encrypt-all <dir>             Encrypt all .env files in directory
  sync <source> <target>        Sync env vars (keeps target overrides)
  validate <file> [--schema X]  Validate against schema
  diff <file1> <file2>          Compare two env files
  example <file> [output]       Generate .env.example (strip secrets)
  protect <dir>                 Set up git protection hooks
  rotate <dir> --old-key X --new-key Y  Re-encrypt with new key

OPTIONS:
  --schema <file>    Schema file for validation
  --strict           Fail on warnings too
  --key <file>       Custom key file for decrypt

EXAMPLES:
  env-manager init .
  env-manager encrypt .env
  env-manager validate .env --schema .env.schema
  env-manager diff .env.dev .env.prod
  env-manager sync .env.dev .env.staging
EOF
}

COMMAND="${1:-help}"
shift 2>/dev/null || true

case "$COMMAND" in
  init)         cmd_init "$@" ;;
  encrypt)      cmd_encrypt "$@" ;;
  decrypt)      cmd_decrypt "$@" ;;
  encrypt-all)  cmd_encrypt_all "$@" ;;
  sync)         cmd_sync "$@" ;;
  validate)     cmd_validate "$@" ;;
  diff)         cmd_diff "$@" ;;
  example)      cmd_example "$@" ;;
  protect)      cmd_protect "$@" ;;
  rotate)       cmd_rotate "$@" ;;
  help|--help|-h) usage ;;
  version|--version|-v) echo "env-manager v$VERSION" ;;
  *) log_err "Unknown command: $COMMAND"; usage; exit 1 ;;
esac
