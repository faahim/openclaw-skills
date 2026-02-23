#!/bin/bash
# env-manager.sh — Manage, validate, encrypt, and sync .env files
# Dependencies: bash 4+, age (encryption), diff, git (optional)

set -uo pipefail

VERSION="1.0.0"
CONFIG_DIR="${HOME}/.config/env-manager"
KEY_FILE="${ENV_MANAGER_KEY:-${CONFIG_DIR}/key.txt}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
env-manager v${VERSION} — Manage .env files securely

USAGE:
    env-manager <command> [options]

COMMANDS:
    validate <project-dir>              Validate .env against .env.example
    encrypt <env-file>                  Encrypt .env file with age
    decrypt <enc-file>                  Decrypt .env.enc file
    diff <file1> <file2>               Compare two .env files
    sync <source> <target> [--dry-run]  Sync missing vars between envs
    scan <repo-dir>                     Scan git history for leaked .env files
    template <env-file>                 Generate .env.example from .env
    keygen                              Generate age encryption key

OPTIONS:
    --strict        Fail on extra vars (validate)
    --recipient     Encrypt for specific age recipient
    --identity      Decrypt with specific key file
    --dry-run       Preview changes without applying
    -h, --help      Show this help
EOF
    exit 0
}

# Parse .env file into sorted KEY=VALUE pairs (strips comments, empty lines)
parse_env() {
    local file="$1"
    grep -v '^#' "$file" 2>/dev/null | grep -v '^\s*$' | sed 's/^export //' | sort
}

# Extract just keys from .env file
parse_keys() {
    local file="$1"
    parse_env "$file" | cut -d'=' -f1
}

# ── KEYGEN ──────────────────────────────────────────────────────────────────

cmd_keygen() {
    if ! command -v age-keygen &>/dev/null; then
        echo -e "${RED}Error: age not installed. Install with: sudo apt-get install age${NC}"
        exit 1
    fi

    mkdir -p "$CONFIG_DIR"

    if [[ -f "$KEY_FILE" ]]; then
        echo -e "${YELLOW}⚠️  Key already exists at ${KEY_FILE}${NC}"
        echo "   Public key: $(grep '^# public key:' "$KEY_FILE" | sed 's/# public key: //')"
        echo "   Delete it first if you want to regenerate."
        exit 1
    fi

    age-keygen -o "$KEY_FILE" 2>&1
    chmod 600 "$KEY_FILE"

    local pubkey
    pubkey=$(grep '^# public key:' "$KEY_FILE" | sed 's/# public key: //')

    echo -e "${GREEN}🔑 Key generated at ${KEY_FILE}${NC}"
    echo "   Public key: ${pubkey}"
    echo "   Share this public key with your team for encryption."
    echo "   Keep ${KEY_FILE} private — it's your decryption key."
}

# ── VALIDATE ────────────────────────────────────────────────────────────────

cmd_validate() {
    local project_dir="${1:-.}"
    local strict=false
    shift || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --strict) strict=true; shift ;;
            *) shift ;;
        esac
    done

    local env_file="${project_dir}/.env"
    local example_file="${project_dir}/.env.example"

    if [[ ! -f "$env_file" ]]; then
        echo -e "${RED}❌ No .env file found at ${env_file}${NC}"
        exit 1
    fi

    if [[ ! -f "$example_file" ]]; then
        echo -e "${RED}❌ No .env.example found at ${example_file}${NC}"
        echo "   Generate one: env-manager template ${env_file}"
        exit 1
    fi

    echo -e "${BLUE}📋 Validating ${env_file} against .env.example${NC}"
    echo ""

    local missing=0
    local present=0
    local extra=0

    # Check required vars (in .env.example but not in .env)
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if grep -q "^${key}=" "$env_file" 2>/dev/null; then
            echo -e "  ${GREEN}✅ ${key}${NC} — present"
            ((present++))
        else
            echo -e "  ${RED}❌ ${key}${NC} — MISSING (defined in .env.example)"
            ((missing++))
        fi
    done < <(parse_keys "$example_file")

    # Check extra vars (in .env but not in .env.example)
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if ! grep -q "^${key}=" "$example_file" 2>/dev/null; then
            echo -e "  ${YELLOW}⚠️  ${key}${NC} — Extra (not in .env.example)"
            ((extra++))
        fi
    done < <(parse_keys "$env_file")

    echo ""
    echo "Result: ${present} present, ${missing} missing, ${extra} extra"

    # Check .gitignore
    if [[ -f "${project_dir}/.gitignore" ]]; then
        if ! grep -q '^\.env$' "${project_dir}/.gitignore" 2>/dev/null; then
            echo -e "${YELLOW}⚠️  .env is NOT in .gitignore — secrets may leak!${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No .gitignore found — add one with .env listed${NC}"
    fi

    if [[ $missing -gt 0 ]]; then
        exit 1
    fi
    if [[ "$strict" == true && $extra -gt 0 ]]; then
        exit 1
    fi
}

# ── ENCRYPT ─────────────────────────────────────────────────────────────────

cmd_encrypt() {
    local env_file="$1"
    local recipient=""
    shift || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --recipient) recipient="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ ! -f "$env_file" ]]; then
        echo -e "${RED}❌ File not found: ${env_file}${NC}"
        exit 1
    fi

    if ! command -v age &>/dev/null; then
        echo -e "${RED}Error: age not installed. Install with: sudo apt-get install age${NC}"
        exit 1
    fi

    local output="${env_file}.enc"

    if [[ -n "$recipient" ]]; then
        age -r "$recipient" -o "$output" "$env_file"
    elif [[ -f "$KEY_FILE" ]]; then
        local pubkey
        pubkey=$(grep '^# public key:' "$KEY_FILE" | sed 's/# public key: //')
        age -r "$pubkey" -o "$output" "$env_file"
    else
        echo -e "${RED}❌ No key found. Run: env-manager keygen${NC}"
        exit 1
    fi

    local size
    size=$(wc -c < "$output")
    echo -e "${GREEN}🔒 Encrypted ${env_file}${NC}"
    echo "   → ${output} (${size} bytes)"
    echo "   ✅ Safe to commit ${output} to git"
}

# ── DECRYPT ─────────────────────────────────────────────────────────────────

cmd_decrypt() {
    local enc_file="$1"
    local identity="$KEY_FILE"
    shift || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --identity) identity="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ ! -f "$enc_file" ]]; then
        echo -e "${RED}❌ File not found: ${enc_file}${NC}"
        exit 1
    fi

    if [[ ! -f "$identity" ]]; then
        echo -e "${RED}❌ Key not found at ${identity}${NC}"
        echo "   Run: env-manager keygen"
        exit 1
    fi

    local output="${enc_file%.enc}"
    if [[ "$output" == "$enc_file" ]]; then
        output="${enc_file}.decrypted"
    fi

    age -d -i "$identity" -o "$output" "$enc_file"
    echo -e "${GREEN}🔓 Decrypted ${enc_file}${NC}"
    echo "   → ${output}"
    echo -e "${YELLOW}⚠️  Don't commit ${output} to git!${NC}"
}

# ── DIFF ────────────────────────────────────────────────────────────────────

cmd_diff() {
    local file1="$1"
    local file2="$2"

    if [[ ! -f "$file1" || ! -f "$file2" ]]; then
        echo -e "${RED}❌ Both files must exist${NC}"
        exit 1
    fi

    echo -e "${BLUE}🔍 Comparing $(basename "$file1") vs $(basename "$file2")${NC}"
    echo ""

    local keys1 keys2
    keys1=$(parse_keys "$file1")
    keys2=$(parse_keys "$file2")

    local all_keys
    all_keys=$(echo -e "${keys1}\n${keys2}" | sort -u)

    local different=0
    local only_first=0
    local only_second=0

    while IFS= read -r key; do
        [[ -z "$key" ]] && continue

        local val1 val2
        val1=$(grep "^${key}=" "$file1" 2>/dev/null | head -1 | cut -d'=' -f2-)
        val2=$(grep "^${key}=" "$file2" 2>/dev/null | head -1 | cut -d'=' -f2-)

        if [[ -z "$val1" && -n "$val2" ]]; then
            echo -e "  ${YELLOW}Only in $(basename "$file2"):${NC}"
            echo "    ${key}=${val2}"
            ((only_second++))
        elif [[ -n "$val1" && -z "$val2" ]]; then
            echo -e "  ${YELLOW}Only in $(basename "$file1"):${NC}"
            echo "    ${key}=${val1}"
            ((only_first++))
        elif [[ "$val1" != "$val2" ]]; then
            echo -e "  ${BLUE}${key}:${NC}"
            echo -e "    ${RED}$(basename "$file1"):  ${val1}${NC}"
            echo -e "    ${GREEN}$(basename "$file2"):  ${val2}${NC}"
            ((different++))
        fi
    done <<< "$all_keys"

    echo ""
    echo "Summary: ${different} different, ${only_first} only in $(basename "$file1"), ${only_second} only in $(basename "$file2")"
}

# ── SYNC ────────────────────────────────────────────────────────────────────

cmd_sync() {
    local source="$1"
    local target="$2"
    local dry_run=false
    shift 2 || true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run) dry_run=true; shift ;;
            *) shift ;;
        esac
    done

    if [[ ! -f "$source" || ! -f "$target" ]]; then
        echo -e "${RED}❌ Both files must exist${NC}"
        exit 1
    fi

    local source_keys target_keys
    source_keys=$(parse_keys "$source")
    target_keys=$(parse_keys "$target")

    local missing_count=0

    echo -e "${BLUE}🔄 Syncing missing vars from $(basename "$source") → $(basename "$target")${NC}"
    echo ""

    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if ! echo "$target_keys" | grep -q "^${key}$"; then
            local val
            val=$(grep "^${key}=" "$source" | head -1)
            if [[ "$dry_run" == true ]]; then
                echo -e "  ${YELLOW}Would add:${NC} ${val}"
            else
                echo "$val" >> "$target"
                echo -e "  ${GREEN}Added:${NC} ${val}"
            fi
            ((missing_count++))
        fi
    done <<< "$source_keys"

    if [[ $missing_count -eq 0 ]]; then
        echo "  ✅ Target already has all vars from source"
    else
        echo ""
        if [[ "$dry_run" == true ]]; then
            echo "${missing_count} vars would be added. Run without --dry-run to apply."
        else
            echo "${missing_count} vars added to $(basename "$target")"
        fi
    fi
}

# ── SCAN ────────────────────────────────────────────────────────────────────

cmd_scan() {
    local repo_dir="${1:-.}"

    if [[ ! -d "${repo_dir}/.git" ]]; then
        echo -e "${RED}❌ Not a git repository: ${repo_dir}${NC}"
        exit 1
    fi

    cd "$repo_dir"

    echo -e "${BLUE}🔍 Scanning git history for .env files...${NC}"
    echo ""

    local found=0

    # Check current working tree
    local env_files
    env_files=$(find . -name ".env" -not -path "./.git/*" -not -name "*.example" -not -name "*.enc" -not -name "*.sample" 2>/dev/null || true)

    if [[ -n "$env_files" ]]; then
        while IFS= read -r f; do
            if git ls-files --error-unmatch "$f" &>/dev/null; then
                echo -e "  ${RED}🚨 ${f} — TRACKED in git (active!)${NC}"
                ((found++))
            else
                echo -e "  ${GREEN}✅ ${f} — exists but NOT tracked (good)${NC}"
            fi
        done <<< "$env_files"
    fi

    # Check git history for deleted .env files
    local history_envs
    history_envs=$(git log --all --diff-filter=D --name-only --pretty=format: -- '*.env' '.env*' 2>/dev/null | grep -v '^$' | grep -v '.example' | grep -v '.enc' | grep -v '.sample' | sort -u || true)

    if [[ -n "$history_envs" ]]; then
        echo ""
        echo -e "  ${YELLOW}⚠️  .env files found in git history (deleted but recoverable):${NC}"
        while IFS= read -r f; do
            [[ -z "$f" ]] && continue
            local commit
            commit=$(git log --all --diff-filter=D --pretty=format:"%h %as" -- "$f" | head -1)
            echo "    - ${f} (${commit})"
            ((found++))
        done <<< "$history_envs"
    fi

    echo ""
    if [[ $found -gt 0 ]]; then
        echo -e "${RED}🚨 ${found} potential secret leak(s) found!${NC}"
        echo ""
        echo "  To remove from history, use BFG Repo Cleaner:"
        echo "    bfg --delete-files .env"
        echo "    git reflog expire --expire=now --all && git gc --prune=now"
        exit 1
    else
        echo -e "${GREEN}✅ No .env files found in git — clean!${NC}"
    fi
}

# ── TEMPLATE ────────────────────────────────────────────────────────────────

cmd_template() {
    local env_file="$1"
    local output_dir
    output_dir=$(dirname "$env_file")
    local output="${output_dir}/.env.example"

    if [[ ! -f "$env_file" ]]; then
        echo -e "${RED}❌ File not found: ${env_file}${NC}"
        exit 1
    fi

    echo -e "${BLUE}📝 Generating .env.example from $(basename "$env_file")${NC}"
    echo ""

    > "$output"

    while IFS= read -r line; do
        # Preserve comments and empty lines
        if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
            echo "$line" >> "$output"
            continue
        fi

        local key val
        key=$(echo "$line" | cut -d'=' -f1)
        val=$(echo "$line" | cut -d'=' -f2-)

        # Keep values that look like defaults (localhost, development, etc.)
        if [[ "$val" =~ ^(true|false|development|staging|production|test|localhost|127\.0\.0\.1|0|1|3000|5432|6379|8080)$ ]]; then
            echo "${key}=${val}" >> "$output"
        elif [[ "$val" =~ ^redis://localhost ]] || [[ "$val" =~ ^postgres://localhost ]] || [[ "$val" =~ ^http://localhost ]]; then
            echo "${key}=${val}" >> "$output"
        else
            echo "${key}=" >> "$output"
        fi
    done < "$env_file"

    echo -e "${GREEN}Written to: ${output}${NC}"
    echo "  (Kept default-looking values, stripped secrets)"
}

# ── MAIN ────────────────────────────────────────────────────────────────────

[[ $# -eq 0 ]] && usage

COMMAND="$1"
shift

case "$COMMAND" in
    keygen)     cmd_keygen "$@" ;;
    validate)   cmd_validate "$@" ;;
    encrypt)    cmd_encrypt "$@" ;;
    decrypt)    cmd_decrypt "$@" ;;
    diff)       cmd_diff "$@" ;;
    sync)       cmd_sync "$@" ;;
    scan)       cmd_scan "$@" ;;
    template)   cmd_template "$@" ;;
    -h|--help)  usage ;;
    *)          echo -e "${RED}Unknown command: ${COMMAND}${NC}"; usage ;;
esac
