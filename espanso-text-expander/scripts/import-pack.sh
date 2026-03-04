#!/bin/bash
set -euo pipefail

PACK="${1:-}"

if [ -z "$PACK" ]; then
    echo "Usage: bash scripts/import-pack.sh <pack-name>"
    echo ""
    echo "Available packs:"
    echo "  starter  — Common snippets, emoji shortcuts, typo fixes"
    echo "  dev      — Developer shortcuts (git, docker, code templates)"
    echo "  email    — Email response templates"
    exit 1
fi

CONFIG_DIR="${ESPANSO_CONFIG:-}"
if [ -z "$CONFIG_DIR" ]; then
    if command -v espanso &>/dev/null; then
        CONFIG_DIR="$(espanso path config 2>/dev/null || echo "")"
    fi
fi
[ -z "$CONFIG_DIR" ] && CONFIG_DIR="$HOME/.config/espanso"

MATCH_DIR="$CONFIG_DIR/match"
mkdir -p "$MATCH_DIR"

case "$PACK" in
    starter)
        cat > "$MATCH_DIR/starter-pack.yml" << 'YAML'
matches:
  # Date & Time
  - trigger: ":date"
    replace: "{{today}}"
    vars:
      - name: today
        type: date
        params:
          format: "%Y-%m-%d"

  - trigger: ":time"
    replace: "{{now}}"
    vars:
      - name: now
        type: date
        params:
          format: "%H:%M"

  - trigger: ":datetime"
    replace: "{{dt}}"
    vars:
      - name: dt
        type: date
        params:
          format: "%Y-%m-%d %H:%M"

  # Emoji shortcuts
  - trigger: ":shrug"
    replace: "¯\\_(ツ)_/¯"

  - trigger: ":lenny"
    replace: "( ͡° ͜ʖ ͡°)"

  - trigger: ":tableflip"
    replace: "(╯°□°)╯︵ ┻━┻"

  - trigger: ":check"
    replace: "✅"

  - trigger: ":x"
    replace: "❌"

  - trigger: ":star"
    replace: "⭐"

  - trigger: ":fire"
    replace: "🔥"

  - trigger: ":rocket"
    replace: "🚀"

  - trigger: ":think"
    replace: "🤔"

  - trigger: ":thumbsup"
    replace: "👍"

  # Common typo fixes
  - trigger: "teh"
    replace: "the"
    word: true

  - trigger: "recieve"
    replace: "receive"
    word: true

  - trigger: "occured"
    replace: "occurred"
    word: true

  - trigger: "seperate"
    replace: "separate"
    word: true

  - trigger: "definately"
    replace: "definitely"
    word: true

  # Arrows & symbols
  - trigger: ":arrow"
    replace: "→"

  - trigger: ":larrow"
    replace: "←"

  - trigger: ":uarrow"
    replace: "↑"

  - trigger: ":darrow"
    replace: "↓"

  - trigger: ":degree"
    replace: "°"

  - trigger: ":bullet"
    replace: "•"

  - trigger: ":tm"
    replace: "™"

  - trigger: ":copy"
    replace: "©"
YAML
        echo "✅ Imported starter pack (28 snippets)"
        ;;

    dev)
        cat > "$MATCH_DIR/dev-pack.yml" << 'YAML'
matches:
  # Git
  - trigger: ":gst"
    replace: "git status"

  - trigger: ":gaa"
    replace: "git add -A"

  - trigger: ":gcm"
    replace: "git commit -m \"$|$\""

  - trigger: ":gcp"
    replace: "git add -A && git commit -m \"$|$\" && git push"

  - trigger: ":gpl"
    replace: "git pull origin main"

  - trigger: ":gco"
    replace: "git checkout $|$"

  - trigger: ":gbr"
    replace: "git branch -a"

  # Docker
  - trigger: ":dps"
    replace: "docker ps --format 'table {{.Names}}\\t{{.Status}}\\t{{.Ports}}'"

  - trigger: ":dcu"
    replace: "docker compose up -d"

  - trigger: ":dcd"
    replace: "docker compose down"

  - trigger: ":dcl"
    replace: "docker compose logs -f --tail=100"

  # Code comments
  - trigger: ":todo"
    replace: "// TODO: $|$"

  - trigger: ":fixme"
    replace: "// FIXME: $|$"

  - trigger: ":hack"
    replace: "// HACK: $|$"

  - trigger: ":note"
    replace: "// NOTE: $|$"

  # Debug
  - trigger: ":clog"
    replace: "console.log('$|$', );"

  - trigger: ":pdb"
    replace: "import pdb; pdb.set_trace()"

  - trigger: ":bp"
    replace: "breakpoint()"

  # Misc dev
  - trigger: ":lorem"
    replace: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

  - trigger: ":uuid"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: "python3 -c 'import uuid; print(uuid.uuid4())' 2>/dev/null || uuidgen"

  - trigger: ":ip"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: "curl -s ifconfig.me"
YAML
        echo "✅ Imported dev pack (21 snippets)"
        ;;

    email)
        cat > "$MATCH_DIR/email-pack.yml" << 'YAML'
matches:
  - trigger: ":ack"
    replace: |
      Thanks for reaching out! I've received your message and will get back to you shortly.

  - trigger: ":followup"
    replace: |
      Hi,

      Just following up on my previous message. Would love to hear your thoughts when you get a chance.

      Best regards

  - trigger: ":intro"
    replace: |
      Hi $|$,

      I hope this message finds you well. I'm reaching out because

  - trigger: ":thanks"
    replace: |
      Thank you so much for this! I really appreciate your help.

      Best regards

  - trigger: ":ooo"
    replace: |
      Hi,

      Thank you for your email. I'm currently out of office and will return on [DATE]. I'll have limited access to email during this time.

      For urgent matters, please contact [CONTACT].

      Best regards

  - trigger: ":meeting"
    replace: |
      Hi $|$,

      Would you be available for a quick call this week? I'd love to discuss [TOPIC].

      Here are some times that work for me:
      - 
      - 

      Let me know what works best for you!

  - trigger: ":decline"
    replace: |
      Thank you for thinking of me! Unfortunately, I won't be able to take this on right now due to other commitments.

      I appreciate the opportunity and hope we can work together in the future.

      Best regards
YAML
        echo "✅ Imported email pack (7 snippets)"
        ;;

    *)
        echo "❌ Unknown pack: $PACK"
        echo "   Available: starter, dev, email"
        exit 1
        ;;
esac

if command -v espanso &>/dev/null && espanso status 2>/dev/null | grep -q "running"; then
    espanso restart 2>/dev/null && echo "🔄 Espanso restarted" || true
fi
