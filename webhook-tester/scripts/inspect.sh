#!/bin/bash
# Webhook Tester — Inspect captured webhooks
set -e

WEBHOOK_DIR="${WEBHOOK_TESTER_DIR:-./webhooks}"
ACTION="${1:-list}"
shift 2>/dev/null || true

case "$ACTION" in
  list)
    FILTER_PATH=""
    FILTER_HEADER=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --path) FILTER_PATH="$2"; shift 2 ;;
        --header) FILTER_HEADER="$2"; shift 2 ;;
        *) shift ;;
      esac
    done

    printf "%-4s | %-19s | %-6s | %-30s | %-8s | %s\n" "#" "Time" "Method" "Path" "Size" "Content-Type"
    printf "%s\n" "-----+---------------------+--------+--------------------------------+----------+------------------"

    for f in $(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | sort); do
      num=$(jq -r '.number' "$f")
      ts=$(jq -r '.timestamp' "$f" | cut -c1-19 | tr 'T' ' ')
      method=$(jq -r '.method' "$f")
      path=$(jq -r '.path' "$f")
      size=$(jq -r '.content_length' "$f")
      ct=$(jq -r '.headers["Content-Type"] // "unknown"' "$f" | cut -d';' -f1)

      # Apply filters
      if [[ -n "$FILTER_PATH" && "$path" != *"$FILTER_PATH"* ]]; then continue; fi
      if [[ -n "$FILTER_HEADER" ]]; then
        has_header=$(jq -r ".headers[\"$FILTER_HEADER\"] // empty" "$f")
        if [[ -z "$has_header" ]]; then continue; fi
      fi

      # Format size
      if [[ $size -gt 1024 ]]; then
        size_fmt="$(echo "scale=1; $size/1024" | bc) KB"
      else
        size_fmt="${size} B"
      fi

      printf "%-4s | %-19s | %-6s | %-30s | %-8s | %s\n" "$num" "$ts" "$method" "${path:0:30}" "$size_fmt" "$ct"
    done
    ;;

  show)
    TARGET="$1"
    if [[ "$TARGET" == "latest" ]]; then
      FILE=$(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | sort | tail -1)
    else
      FILE=$(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | sort | sed -n "${TARGET}p")
    fi

    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
      echo "❌ Webhook #$TARGET not found"
      exit 1
    fi

    echo "═══════════════════════════════════════════════════"
    echo "Webhook #$(jq -r '.number' "$FILE")"
    echo "═══════════════════════════════════════════════════"
    echo "Time:   $(jq -r '.timestamp' "$FILE")"
    echo "Method: $(jq -r '.method' "$FILE")"
    echo "Path:   $(jq -r '.path' "$FILE")"
    echo "Client: $(jq -r '.client' "$FILE")"
    echo "Size:   $(jq -r '.content_length' "$FILE") bytes"
    echo ""
    echo "── Headers ──"
    jq -r '.headers | to_entries[] | "  \(.key): \(.value)"' "$FILE"
    echo ""
    echo "── Body ──"
    BODY=$(jq -r '.body_parsed // .body_raw' "$FILE")
    if echo "$BODY" | jq . >/dev/null 2>&1; then
      echo "$BODY" | jq .
    else
      echo "$BODY"
    fi
    echo ""
    echo "File: $FILE"
    ;;

  diff)
    F1=$(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | sort | sed -n "${1}p")
    F2=$(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | sort | sed -n "${2}p")
    if [[ -z "$F1" || -z "$F2" ]]; then
      echo "❌ Need two webhook numbers: inspect.sh diff 1 2"
      exit 1
    fi
    diff <(jq -S '.body_parsed // .body_raw' "$F1") <(jq -S '.body_parsed // .body_raw' "$F2") || true
    ;;

  export)
    TARGET="$1"
    FILE=$(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | sort | sed -n "${TARGET}p")
    if [[ -z "$FILE" || ! -f "$FILE" ]]; then
      echo "❌ Webhook #$TARGET not found"
      exit 1
    fi

    METHOD=$(jq -r '.method' "$FILE")
    PATH_URL=$(jq -r '.path' "$FILE")
    BODY=$(jq -r '.body_raw' "$FILE")

    echo "curl -X $METHOD http://localhost:9876$PATH_URL \\"
    jq -r '.headers | to_entries[] | select(.key != "Host" and .key != "Content-Length" and .key != "User-Agent" and .key != "Accept") | "  -H \"\(.key): \(.value)\" \\"' "$FILE"
    echo "  -d '$(echo "$BODY" | sed "s/'/'\\\\''/g")'"
    ;;

  status)
    PID_FILE="$WEBHOOK_DIR/server.pid"
    if [[ -f "$PID_FILE" ]]; then
      PID=$(cat "$PID_FILE")
      if kill -0 "$PID" 2>/dev/null; then
        COUNT=$(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | wc -l)
        echo "✅ Webhook Tester running (PID $PID)"
        echo "   Captured: $COUNT webhooks"
        echo "   Directory: $WEBHOOK_DIR"
      else
        echo "❌ Webhook Tester not running (stale PID file)"
        rm -f "$PID_FILE"
      fi
    else
      echo "❌ Webhook Tester not running"
    fi
    ;;

  stop)
    PID_FILE="$WEBHOOK_DIR/server.pid"
    if [[ -f "$PID_FILE" ]]; then
      PID=$(cat "$PID_FILE")
      kill "$PID" 2>/dev/null && echo "🛑 Stopped (PID $PID)" || echo "❌ Not running"
      rm -f "$PID_FILE"
    else
      echo "❌ No PID file found"
    fi
    ;;

  verify-stripe)
    TARGET="$1"; shift
    SECRET=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --secret) SECRET="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    FILE=$(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | sort | sed -n "${TARGET}p")
    if [[ -z "$FILE" || -z "$SECRET" ]]; then
      echo "Usage: inspect.sh verify-stripe <num> --secret whsec_xxx"
      exit 1
    fi
    SIG=$(jq -r '.headers["X-Stripe-Signature"] // .headers["Stripe-Signature"] // empty' "$FILE")
    if [[ -z "$SIG" ]]; then
      echo "❌ No Stripe signature header found"
      exit 1
    fi
    TIMESTAMP=$(echo "$SIG" | grep -o 't=[0-9]*' | cut -d= -f2)
    BODY=$(jq -r '.body_raw' "$FILE")
    EXPECTED=$(echo -n "${TIMESTAMP}.${BODY}" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')
    V1=$(echo "$SIG" | grep -o 'v1=[a-f0-9]*' | cut -d= -f2)
    if [[ "$EXPECTED" == "$V1" ]]; then
      echo "✅ Stripe signature valid"
    else
      echo "❌ Stripe signature INVALID"
      echo "   Expected: $EXPECTED"
      echo "   Got:      $V1"
    fi
    ;;

  verify-github)
    TARGET="$1"; shift
    SECRET=""
    while [[ $# -gt 0 ]]; do
      case $1 in
        --secret) SECRET="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    FILE=$(ls "$WEBHOOK_DIR"/*.json 2>/dev/null | sort | sed -n "${TARGET}p")
    if [[ -z "$FILE" || -z "$SECRET" ]]; then
      echo "Usage: inspect.sh verify-github <num> --secret ghsec_xxx"
      exit 1
    fi
    SIG=$(jq -r '.headers["X-Hub-Signature-256"] // empty' "$FILE")
    if [[ -z "$SIG" ]]; then
      echo "❌ No GitHub signature header found"
      exit 1
    fi
    BODY=$(jq -r '.body_raw' "$FILE")
    EXPECTED="sha256=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | awk '{print $2}')"
    if [[ "$EXPECTED" == "$SIG" ]]; then
      echo "✅ GitHub signature valid"
    else
      echo "❌ GitHub signature INVALID"
    fi
    ;;

  *)
    echo "Usage: inspect.sh <action> [args]"
    echo ""
    echo "Actions:"
    echo "  list [--path /x] [--header X-Y]  List captured webhooks"
    echo "  show <num|latest>                 Show webhook details"
    echo "  diff <num1> <num2>                Diff two webhook bodies"
    echo "  export <num>                      Export as curl command"
    echo "  status                            Check server status"
    echo "  stop                              Stop the server"
    echo "  verify-stripe <num> --secret x    Verify Stripe signature"
    echo "  verify-github <num> --secret x    Verify GitHub signature"
    ;;
esac
