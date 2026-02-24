#!/bin/bash
# TOTP Manager — Main Script
# Generate and manage TOTP 2FA codes from the command line
set -euo pipefail

STORE="${TOTP_STORE:-$HOME/.config/totp-manager}"
ENCRYPT="${TOTP_ENCRYPT:-false}"
GPG_ID="${TOTP_GPG_ID:-}"
SECRETS_FILE="$STORE/secrets.json"
SECRETS_ENC="$STORE/secrets.enc"

# --- Helpers ---

ensure_store() {
    mkdir -p "$STORE"
    chmod 700 "$STORE"
}

load_secrets() {
    if [ "$ENCRYPT" = "true" ] && [ -f "$SECRETS_ENC" ]; then
        gpg --quiet --decrypt "$SECRETS_ENC" 2>/dev/null
    elif [ -f "$SECRETS_FILE" ]; then
        cat "$SECRETS_FILE"
    else
        echo '{"secrets":{}}'
    fi
}

save_secrets() {
    local data="$1"
    if [ "$ENCRYPT" = "true" ] && [ -n "$GPG_ID" ]; then
        echo "$data" | gpg --quiet --yes --recipient "$GPG_ID" --encrypt --output "$SECRETS_ENC"
        rm -f "$SECRETS_FILE"
    else
        echo "$data" > "$SECRETS_FILE"
        chmod 600 "$SECRETS_FILE"
    fi
}

get_remaining_seconds() {
    local period="${1:-30}"
    local now=$(date +%s)
    echo $(( period - (now % period) ))
}

generate_code() {
    local secret="$1"
    local digits="${2:-6}"
    local period="${3:-30}"
    local time_arg=""

    if [ -n "${TOTP_TIME:-}" ]; then
        # Convert ISO timestamp to unix for --now flag
        local unix_time=$(date -d "$TOTP_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$TOTP_TIME" +%s 2>/dev/null)
        time_arg="--now=$unix_time"
    fi

    oathtool --totp --base32 --digits="$digits" --time-step-size="${period}s" $time_arg "$secret" 2>/dev/null
}

# --- Commands ---

cmd_add() {
    local name="" secret="" digits=6 period=30 issuer="" uri=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift 2 ;;
            --secret) secret="$2"; shift 2 ;;
            --digits) digits="$2"; shift 2 ;;
            --period) period="$2"; shift 2 ;;
            --issuer) issuer="$2"; shift 2 ;;
            --uri) uri="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    # Parse otpauth:// URI
    if [ -n "$uri" ]; then
        secret=$(echo "$uri" | grep -oP 'secret=\K[^&]+' || echo "")
        name=$(echo "$uri" | grep -oP 'totp/\K[^?]+' | sed 's/%20/ /g; s/.*://' || echo "")
        issuer=$(echo "$uri" | grep -oP 'issuer=\K[^&]+' | sed 's/%20/ /g' || echo "")
        digits=$(echo "$uri" | grep -oP 'digits=\K[^&]+' || echo "6")
        period=$(echo "$uri" | grep -oP 'period=\K[^&]+' || echo "30")
    fi

    if [ -z "$name" ] || [ -z "$secret" ]; then
        echo "❌ Usage: run.sh add --name <name> --secret <base32-secret>"
        echo "   Or:   run.sh add --uri 'otpauth://totp/...'"
        exit 1
    fi

    # Normalize secret (remove spaces, uppercase)
    secret=$(echo "$secret" | tr -d ' ' | tr '[:lower:]' '[:upper:]')

    # Validate secret works
    if ! oathtool --totp --base32 "$secret" &>/dev/null; then
        echo "❌ Invalid base32 secret. Check the key and try again."
        exit 1
    fi

    ensure_store
    local data=$(load_secrets)
    data=$(echo "$data" | jq --arg n "$name" --arg s "$secret" --argjson d "$digits" --argjson p "$period" --arg i "$issuer" \
        '.secrets[$n] = {"secret": $s, "digits": $d, "period": $p, "issuer": $i, "added_at": (now | todate)}')
    save_secrets "$data"

    local code=$(generate_code "$secret" "$digits" "$period")
    local remaining=$(get_remaining_seconds "$period")
    echo "✅ Added '$name' — current code: $code (expires in ${remaining}s)"
}

cmd_get() {
    local name="" raw=false time_override=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift 2 ;;
            --raw) raw=true; shift ;;
            --time) TOTP_TIME="$2"; shift 2 ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "❌ Usage: run.sh get --name <name>"
        exit 1
    fi

    local data=$(load_secrets)
    local entry=$(echo "$data" | jq -r --arg n "$name" '.secrets[$n] // empty')

    if [ -z "$entry" ]; then
        echo "❌ No secret found for '$name'"
        echo "Available: $(echo "$data" | jq -r '.secrets | keys[]' | tr '\n' ', ' | sed 's/,$//')"
        exit 1
    fi

    local secret=$(echo "$entry" | jq -r '.secret')
    local digits=$(echo "$entry" | jq -r '.digits // 6')
    local period=$(echo "$entry" | jq -r '.period // 30')

    local code=$(generate_code "$secret" "$digits" "$period")

    if [ "$raw" = true ]; then
        echo "$code"
    else
        local remaining=$(get_remaining_seconds "$period")
        echo "🔑 $name: $code (expires in ${remaining}s)"
    fi
}

cmd_list() {
    local data=$(load_secrets)
    local names=$(echo "$data" | jq -r '.secrets | keys[]')

    if [ -z "$names" ]; then
        echo "📭 No secrets stored. Add one with: run.sh add --name <name> --secret <key>"
        exit 0
    fi

    echo "🔐 TOTP Codes:"
    echo ""
    while IFS= read -r name; do
        local entry=$(echo "$data" | jq -r --arg n "$name" '.secrets[$n]')
        local secret=$(echo "$entry" | jq -r '.secret')
        local digits=$(echo "$entry" | jq -r '.digits // 6')
        local period=$(echo "$entry" | jq -r '.period // 30')
        local code=$(generate_code "$secret" "$digits" "$period")
        local remaining=$(get_remaining_seconds "$period")
        printf "  🔑 %-20s %s (%ds)\n" "$name" "$code" "$remaining"
    done <<< "$names"
}

cmd_remove() {
    local name="" force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift 2 ;;
            --force) force=true; shift ;;
            *) shift ;;
        esac
    done

    if [ -z "$name" ]; then
        echo "❌ Usage: run.sh remove --name <name>"
        exit 1
    fi

    local data=$(load_secrets)
    local exists=$(echo "$data" | jq -r --arg n "$name" '.secrets[$n] // empty')

    if [ -z "$exists" ]; then
        echo "❌ No secret found for '$name'"
        exit 1
    fi

    if [ "$force" != true ]; then
        read -p "⚠️  Remove '$name'? (y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Cancelled."
            exit 0
        fi
    fi

    data=$(echo "$data" | jq --arg n "$name" 'del(.secrets[$n])')
    save_secrets "$data"
    echo "✅ Removed '$name'"
}

cmd_export() {
    local gpg_recipient="" plain=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --gpg-recipient) gpg_recipient="$2"; shift 2 ;;
            --plain) plain=true; shift ;;
            *) shift ;;
        esac
    done

    local data=$(load_secrets)

    if [ "$plain" = true ]; then
        echo "$data" | jq .
    elif [ -n "$gpg_recipient" ]; then
        echo "$data" | gpg --recipient "$gpg_recipient" --encrypt --armor
    else
        echo "❌ Usage: run.sh export --plain OR --gpg-recipient <email>"
        exit 1
    fi
}

cmd_import() {
    local file=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --file) file="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "❌ Usage: run.sh import --file <path>"
        exit 1
    fi

    local import_data
    if echo "$file" | grep -q '\.gpg$\|\.enc$'; then
        import_data=$(gpg --quiet --decrypt "$file")
    else
        import_data=$(cat "$file")
    fi

    # Validate JSON
    if ! echo "$import_data" | jq '.secrets' &>/dev/null; then
        echo "❌ Invalid format — expected JSON with 'secrets' key"
        exit 1
    fi

    ensure_store
    local current=$(load_secrets)
    local merged=$(echo "$current" "$import_data" | jq -s '.[0].secrets * .[1].secrets | {secrets: .}')
    save_secrets "$merged"

    local count=$(echo "$import_data" | jq '.secrets | length')
    echo "✅ Imported $count secrets"
}

cmd_verify() {
    local name="" code=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --name) name="$2"; shift 2 ;;
            --code) code="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [ -z "$name" ] || [ -z "$code" ]; then
        echo "❌ Usage: run.sh verify --name <name> --code <code>"
        exit 1
    fi

    local data=$(load_secrets)
    local entry=$(echo "$data" | jq -r --arg n "$name" '.secrets[$n] // empty')

    if [ -z "$entry" ]; then
        echo "❌ No secret found for '$name'"
        exit 1
    fi

    local secret=$(echo "$entry" | jq -r '.secret')
    local digits=$(echo "$entry" | jq -r '.digits // 6')
    local period=$(echo "$entry" | jq -r '.period // 30')

    # Check current and adjacent windows
    if oathtool --totp --base32 --digits="$digits" --time-step-size="${period}s" -w 1 "$secret" 2>/dev/null | grep -q "^${code}$"; then
        echo "✅ Code is valid"
    else
        echo "❌ Code is invalid"
        exit 1
    fi
}

cmd_watch() {
    echo "🔐 TOTP Watch Mode (Ctrl+C to stop)"
    echo ""
    while true; do
        clear
        echo "🔐 TOTP Codes — $(date '+%H:%M:%S')"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        local data=$(load_secrets)
        local names=$(echo "$data" | jq -r '.secrets | keys[]')
        while IFS= read -r name; do
            [ -z "$name" ] && continue
            local entry=$(echo "$data" | jq -r --arg n "$name" '.secrets[$n]')
            local secret=$(echo "$entry" | jq -r '.secret')
            local digits=$(echo "$entry" | jq -r '.digits // 6')
            local period=$(echo "$entry" | jq -r '.period // 30')
            local code=$(generate_code "$secret" "$digits" "$period")
            local remaining=$(get_remaining_seconds "$period")
            local filled=$((remaining * 10 / period))
            local bar=""
            for ((i=0; i<10; i++)); do
                if [ $i -lt $filled ]; then bar+="█"; else bar+="░"; fi
            done
            printf "  🔑 %-18s %s %s %ds\n" "$name" "$code" "$bar" "$remaining"
        done <<< "$names"
        sleep 1
    done
}

# --- Main ---

if [ $# -eq 0 ]; then
    echo "🔐 TOTP Manager — CLI two-factor authentication"
    echo ""
    echo "Commands:"
    echo "  add      Add a new TOTP secret"
    echo "  get      Generate current code for a service"
    echo "  list     Show all current codes"
    echo "  remove   Delete a stored secret"
    echo "  verify   Check if a code is valid"
    echo "  export   Backup secrets (plain or GPG-encrypted)"
    echo "  import   Restore secrets from backup"
    echo "  watch    Live-updating code display"
    echo ""
    echo "Examples:"
    echo "  bash run.sh add --name github --secret JBSWY3DPEHPK3PXP"
    echo "  bash run.sh get --name github"
    echo "  bash run.sh get --name github --raw"
    echo "  bash run.sh list"
    exit 0
fi

CMD="$1"
shift

case "$CMD" in
    add) cmd_add "$@" ;;
    get) cmd_get "$@" ;;
    list) cmd_list "$@" ;;
    remove) cmd_remove "$@" ;;
    verify) cmd_verify "$@" ;;
    export) cmd_export "$@" ;;
    import) cmd_import "$@" ;;
    watch) cmd_watch "$@" ;;
    *) echo "❌ Unknown command: $CMD"; exit 1 ;;
esac
