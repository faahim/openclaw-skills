#!/bin/bash
# RSS Feed Reader — Aggregate, filter, and digest RSS/Atom feeds
# Requires: curl, xmlstarlet, bash 4.0+
set -euo pipefail

RSS_DIR="${RSS_READER_DIR:-$HOME/.rss-reader}"
FEEDS_FILE="$RSS_DIR/feeds.txt"
SEEN_FILE="$RSS_DIR/seen.db"
ITEMS_DIR="$RSS_DIR/items"
LOGS_DIR="$RSS_DIR/logs"
CONFIG_FILE="$RSS_DIR/config.yaml"

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# ─── Helpers ───

log() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }

hash_item() {
    echo -n "$1" | md5sum | cut -d' ' -f1
}

ensure_dirs() {
    mkdir -p "$RSS_DIR" "$ITEMS_DIR" "$LOGS_DIR"
    touch "$FEEDS_FILE" "$SEEN_FILE"
}

is_seen() {
    local hash
    hash=$(hash_item "$1")
    grep -qF "$hash" "$SEEN_FILE" 2>/dev/null
}

mark_seen() {
    local hash
    hash=$(hash_item "$1")
    echo "$hash" >> "$SEEN_FILE"
}

send_telegram() {
    local text="$1"
    local token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"
    if [[ -z "$token" || -z "$chat_id" ]]; then
        warn "Telegram not configured (set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID)"
        return 1
    fi
    # Truncate to Telegram's 4096 char limit
    text="${text:0:4000}"
    curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
        -d "chat_id=${chat_id}" \
        -d "text=${text}" \
        -d "parse_mode=Markdown" \
        -d "disable_web_page_preview=true" > /dev/null 2>&1
}

# ─── Parse RSS/Atom with xmlstarlet ───

parse_feed() {
    local xml="$1"
    local tmp_items=""

    # Try RSS 2.0 first
    local rss_count
    rss_count=$(echo "$xml" | xmlstarlet sel -t -v "count(//item)" 2>/dev/null || echo "0")

    if [[ "$rss_count" -gt 0 ]]; then
        # RSS 2.0 — only extract title, link, pubDate (skip description to avoid multiline issues)
        echo "$xml" | xmlstarlet sel -t \
            -m "//item" \
            -v "concat(title, '|||', link, '|||', pubDate)" \
            -n 2>/dev/null || true
        return
    fi

    # Try Atom
    local atom_count
    atom_count=$(echo "$xml" | xmlstarlet sel -N a="http://www.w3.org/2005/Atom" \
        -t -v "count(//a:entry)" 2>/dev/null || echo "0")

    if [[ "$atom_count" -gt 0 ]]; then
        echo "$xml" | xmlstarlet sel -N a="http://www.w3.org/2005/Atom" -t \
            -m "//a:entry" \
            -v "concat(a:title, '|||', a:link/@href, '|||', a:updated)" \
            -n 2>/dev/null || true
        return
    fi

    warn "Could not parse feed (neither RSS 2.0 nor Atom detected)"
}

# ─── Commands ───

cmd_init() {
    ensure_dirs
    log "${GREEN}✅${NC} Initialized RSS reader at $RSS_DIR"
    log "Add feeds with: $0 add <url> --tag <tag>"
}

cmd_add() {
    ensure_dirs
    local url="$1"
    local tag="${2:-general}"

    # Check for duplicates
    if grep -qF "$url" "$FEEDS_FILE" 2>/dev/null; then
        warn "Feed already exists: $url"
        return 1
    fi

    echo "${tag}|${url}" >> "$FEEDS_FILE"
    log "${GREEN}✅${NC} Added [${tag}] ${url}"
}

cmd_remove() {
    local url="$1"
    if grep -qF "$url" "$FEEDS_FILE" 2>/dev/null; then
        grep -vF "$url" "$FEEDS_FILE" > "$FEEDS_FILE.tmp" || true
        mv "$FEEDS_FILE.tmp" "$FEEDS_FILE"
        log "${GREEN}✅${NC} Removed ${url}"
    else
        warn "Feed not found: $url"
    fi
}

cmd_list() {
    ensure_dirs
    if [[ ! -s "$FEEDS_FILE" ]]; then
        log "No feeds configured. Add with: $0 add <url> --tag <tag>"
        return
    fi
    local i=1
    while IFS='|' read -r tag url; do
        echo "$i. [${tag}] ${url}"
        ((i++))
    done < "$FEEDS_FILE"
}

cmd_fetch() {
    ensure_dirs
    local filter_tag=""
    local filter_include=""
    local filter_exclude=""
    local do_mark_read=false
    local do_alert=""
    local new_items=()
    local total_new=0
    local total_items=0

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag) filter_tag="$2"; shift 2 ;;
            --filter) filter_include="$2"; shift 2 ;;
            --exclude) filter_exclude="$2"; shift 2 ;;
            --mark-read) do_mark_read=true; shift ;;
            --alert) do_alert="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ ! -s "$FEEDS_FILE" ]]; then
        log "No feeds configured."
        return
    fi

    local feed_count
    feed_count=$(wc -l < "$FEEDS_FILE")
    log "Fetching ${feed_count} feeds..."

    while IFS='|' read -r tag url; do
        [[ -z "$url" ]] && continue
        [[ -n "$filter_tag" && "$tag" != "$filter_tag" ]] && continue

        # Fetch with timeout
        local xml
        xml=$(curl -s --max-time 15 -H "User-Agent: RSSReader/1.0" "$url" 2>/dev/null) || {
            err "Failed to fetch: $url"
            continue
        }

        if [[ -z "$xml" ]]; then
            warn "Empty response from $url"
            continue
        fi

        # Parse
        local items_text
        items_text=$(parse_feed "$xml" 2>/dev/null) || {
            warn "Failed to parse: $url"
            continue
        }

        local feed_total=0
        local feed_new=0

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            ((feed_total++)) || true
            ((total_items++)) || true

            local title link pubdate
            title=$(echo "$line" | awk -F'\\|\\|\\|' '{print $1}' | sed 's/^[[:space:]]*//')
            link=$(echo "$line" | awk -F'\\|\\|\\|' '{print $2}' | sed 's/^[[:space:]]*//')
            pubdate=$(echo "$line" | awk -F'\\|\\|\\|' '{print $3}' | sed 's/^[[:space:]]*//')
            local desc="$title"

            # Dedup key = url + title
            local key="${url}::${title}"

            if is_seen "$key"; then
                continue
            fi

            # Keyword filter (include)
            if [[ -n "$filter_include" ]]; then
                local match=false
                IFS=',' read -ra keywords <<< "$filter_include"
                for kw in "${keywords[@]}"; do
                    kw=$(echo "$kw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if echo "$title $desc" | grep -qi "$kw" 2>/dev/null; then
                        match=true
                        break
                    fi
                done
                [[ "$match" == "false" ]] && continue
            fi

            # Keyword filter (exclude)
            if [[ -n "$filter_exclude" ]]; then
                local excluded=false
                IFS=',' read -ra keywords <<< "$filter_exclude"
                for kw in "${keywords[@]}"; do
                    kw=$(echo "$kw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    if echo "$title $desc" | grep -qi "$kw" 2>/dev/null; then
                        excluded=true
                        break
                    fi
                done
                [[ "$excluded" == "true" ]] && continue
            fi

            ((feed_new++)) || true
            ((total_new++)) || true

            new_items+=("[$tag] $title")
            new_items+=("  $link")
            new_items+=("  $pubdate")
            new_items+=("")

            if [[ "$do_mark_read" == true ]]; then
                mark_seen "$key"
            fi

        done <<< "$items_text"

        local domain
        domain=$(echo "$url" | sed 's|https\?://||; s|/.*||')
        log "${GREEN}✅${NC} ${domain} — ${feed_total} items (${feed_new} new)"

    done < "$FEEDS_FILE"

    echo ""
    if [[ $total_new -eq 0 ]]; then
        log "No new items."
    else
        log "=== ${total_new} New Items ==="
        echo ""
        printf '%s\n' "${new_items[@]}"
    fi

    # Alert
    if [[ -n "$do_alert" && $total_new -gt 0 ]]; then
        case "$do_alert" in
            telegram)
                local alert_text="📰 *RSS Digest* — ${total_new} new items\n\n"
                local count=0
                for ((i=0; i<${#new_items[@]}; i+=4)); do
                    ((count++))
                    [[ $count -gt 20 ]] && { alert_text+="\n...and $((total_new - 20)) more"; break; }
                    alert_text+="${new_items[$i]}\n${new_items[$((i+1))]}\n\n"
                done
                send_telegram "$alert_text"
                log "📱 Telegram alert sent"
                ;;
        esac
    fi
}

cmd_digest() {
    ensure_dirs
    local do_telegram=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --telegram) do_telegram=true; shift ;;
            *) shift ;;
        esac
    done

    local date_str
    date_str=$(date '+%Y-%m-%d')
    local digest_file="$RSS_DIR/digest-${date_str}.md"

    # Fetch without marking read, capture output
    local output
    output=$(cmd_fetch --mark-read 2>&1) || true

    # Write digest
    {
        echo "# Feed Digest — $(date '+%b %d, %Y')"
        echo ""
        echo "$output" | grep -E '^\[|^  http|^  [0-9]' || echo "No new items today."
    } > "$digest_file"

    log "${GREEN}✅${NC} Digest saved to $digest_file"

    if [[ "$do_telegram" == true ]]; then
        local text
        text=$(cat "$digest_file" | head -c 3900)
        send_telegram "$text"
        log "📱 Digest sent to Telegram"
    fi
}

cmd_import() {
    ensure_dirs
    local opml_file="$1"

    if [[ ! -f "$opml_file" ]]; then
        err "OPML file not found: $opml_file"
        return 1
    fi

    local count=0
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        if ! grep -qF "$url" "$FEEDS_FILE" 2>/dev/null; then
            echo "imported|${url}" >> "$FEEDS_FILE"
            ((count++))
        fi
    done < <(xmlstarlet sel -t -m "//outline[@xmlUrl]" -v "@xmlUrl" -n "$opml_file" 2>/dev/null)

    log "${GREEN}✅${NC} Imported ${count} feeds from OPML"
}

cmd_export() {
    ensure_dirs
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<opml version="2.0">'
    echo '  <head><title>RSS Reader Feeds</title></head>'
    echo '  <body>'
    while IFS='|' read -r tag url; do
        [[ -z "$url" ]] && continue
        echo "    <outline text=\"${tag}\" xmlUrl=\"${url}\" />"
    done < "$FEEDS_FILE"
    echo '  </body>'
    echo '</opml>'
}

cmd_stats() {
    ensure_dirs
    local feed_count
    feed_count=$(wc -l < "$FEEDS_FILE" 2>/dev/null || echo "0")
    local seen_count
    seen_count=$(wc -l < "$SEEN_FILE" 2>/dev/null || echo "0")
    echo "Feeds: $feed_count"
    echo "Seen items: $seen_count"
    echo "Data dir: $RSS_DIR"
}

cmd_reset() {
    > "$SEEN_FILE"
    log "${GREEN}✅${NC} Reset read state — all items will appear as new"
}

# ─── Main ───

usage() {
    cat <<EOF
RSS Feed Reader v1.0

Usage: $0 <command> [options]

Commands:
  init                    Initialize RSS reader
  add <url> [--tag TAG]   Add a feed
  remove <url>            Remove a feed
  list                    List all feeds
  fetch [options]         Fetch and display new items
    --tag TAG             Filter by tag
    --filter KEYWORDS     Include items matching keywords (comma-separated)
    --exclude KEYWORDS    Exclude items matching keywords
    --mark-read           Mark fetched items as read
    --alert telegram      Send alert for new items
  digest [--telegram]     Generate daily digest
  import <file.opml>      Import feeds from OPML
  export                  Export feeds as OPML
  stats                   Show statistics
  reset                   Reset read state

Environment:
  TELEGRAM_BOT_TOKEN      Telegram bot token (for alerts)
  TELEGRAM_CHAT_ID        Telegram chat ID (for alerts)
  RSS_READER_DIR          Data directory (default: ~/.rss-reader)
EOF
}

main() {
    local cmd="${1:-help}"
    shift || true

    case "$cmd" in
        init) cmd_init ;;
        add)
            local url="${1:?URL required}"
            shift
            local tag="general"
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --tag) tag="$2"; shift 2 ;;
                    *) shift ;;
                esac
            done
            cmd_add "$url" "$tag"
            ;;
        remove) cmd_remove "${1:?URL required}" ;;
        list) cmd_list ;;
        fetch) cmd_fetch "$@" ;;
        digest) cmd_digest "$@" ;;
        import) cmd_import "${1:?OPML file required}" ;;
        export) cmd_export ;;
        stats) cmd_stats ;;
        reset) cmd_reset ;;
        help|--help|-h) usage ;;
        *) err "Unknown command: $cmd"; usage; exit 1 ;;
    esac
}

main "$@"
