#!/bin/bash
# Asciinema Terminal Recorder — Main script
set -e

RECORDINGS_DIR="${ASCIINEMA_RECORDINGS_DIR:-$HOME/.local/share/asciinema/recordings}"
mkdir -p "$RECORDINGS_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  cat << 'EOF'
🎬 Asciinema Terminal Recorder

USAGE:
  bash scripts/run.sh <command> [options]

COMMANDS:
  record    Record a terminal session
  play      Play back a recording
  upload    Upload to asciinema.org
  list      List local recordings
  gif       Convert recording to GIF
  svg       Convert recording to SVG
  trim      Trim a recording
  concat    Concatenate recordings
  info      Show recording metadata

EXAMPLES:
  bash scripts/run.sh record --title "Demo" --output demo.cast
  bash scripts/run.sh play demo.cast --speed 2
  bash scripts/run.sh upload demo.cast
  bash scripts/run.sh list
  bash scripts/run.sh gif demo.cast --output demo.gif
EOF
}

# Check asciinema is installed
check_deps() {
  if ! command -v asciinema &>/dev/null; then
    echo -e "${RED}❌ asciinema not found. Run: bash scripts/install.sh${NC}"
    exit 1
  fi
}

# Record a session
cmd_record() {
  local title="" output="" idle_limit="" cols="" rows="" command="" append=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --title|-t) title="$2"; shift 2 ;;
      --output|-o) output="$2"; shift 2 ;;
      --idle-limit|-i) idle_limit="$2"; shift 2 ;;
      --cols) cols="$2"; shift 2 ;;
      --rows) rows="$2"; shift 2 ;;
      --command|-c) command="$2"; shift 2 ;;
      --append) append="1"; shift ;;
      *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
  done

  # Default output filename
  if [ -z "$output" ]; then
    output="$RECORDINGS_DIR/$(date +%Y%m%d-%H%M%S).cast"
  fi

  # Build asciinema args
  local args=()
  [ -n "$title" ] && args+=(--title "$title")
  [ -n "$idle_limit" ] && args+=(--idle-time-limit "$idle_limit")
  [ -n "$cols" ] && args+=(--cols "$cols")
  [ -n "$rows" ] && args+=(--rows "$rows")
  [ -n "$command" ] && args+=(--command "$command")
  [ -n "$append" ] && args+=(--append)

  echo -e "${GREEN}🎬 Recording to: $output${NC}"
  echo -e "${YELLOW}   Exit shell (Ctrl+D or 'exit') to stop recording.${NC}"
  echo ""

  asciinema rec "${args[@]}" "$output"

  echo ""
  echo -e "${GREEN}✅ Recording saved: $output${NC}"

  # Show file size and duration
  if [ -f "$output" ]; then
    local size=$(du -h "$output" | cut -f1)
    local duration=$(tail -1 "$output" | python3 -c "import sys,json; print(f\"{json.loads(sys.stdin.readline())[0]:.1f}s\")" 2>/dev/null || echo "unknown")
    echo -e "   Size: $size | Duration: $duration"
  fi
}

# Play a recording
cmd_play() {
  local file="" speed=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --speed|-s) speed="$2"; shift 2 ;;
      -*) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
      *) file="$1"; shift ;;
    esac
  done

  if [ -z "$file" ]; then
    echo -e "${RED}❌ Specify a recording file to play.${NC}"
    exit 1
  fi

  if [ ! -f "$file" ]; then
    # Check recordings dir
    if [ -f "$RECORDINGS_DIR/$file" ]; then
      file="$RECORDINGS_DIR/$file"
    else
      echo -e "${RED}❌ File not found: $file${NC}"
      exit 1
    fi
  fi

  local args=()
  [ -n "$speed" ] && args+=(--speed "$speed")

  echo -e "${BLUE}▶️  Playing: $file${NC}"
  asciinema play "${args[@]}" "$file"
}

# Upload a recording
cmd_upload() {
  local file="$1"

  if [ -z "$file" ]; then
    echo -e "${RED}❌ Specify a recording file to upload.${NC}"
    exit 1
  fi

  if [ ! -f "$file" ]; then
    if [ -f "$RECORDINGS_DIR/$file" ]; then
      file="$RECORDINGS_DIR/$file"
    else
      echo -e "${RED}❌ File not found: $file${NC}"
      exit 1
    fi
  fi

  echo -e "${BLUE}⬆️  Uploading: $file${NC}"
  local result
  result=$(asciinema upload "$file" 2>&1)
  echo "$result"

  # Extract URL
  local url=$(echo "$result" | grep -oP 'https://asciinema\.org/a/\S+' | head -1)
  if [ -n "$url" ]; then
    echo ""
    echo -e "${GREEN}✅ Uploaded: $url${NC}"
    echo -e "📋 Embed HTML:  <script src=\"${url}.js\" id=\"asciicast\" async></script>"
    echo -e "📋 Embed MD:    [![asciicast](${url}.svg)](${url})"
  fi
}

# List recordings
cmd_list() {
  echo -e "${BLUE}📁 Recordings in: $RECORDINGS_DIR${NC}"
  echo ""

  if [ -z "$(ls -A "$RECORDINGS_DIR"/*.cast 2>/dev/null)" ]; then
    echo "   No recordings found."
    return
  fi

  printf "%-35s %-10s %-25s %s\n" "FILE" "SIZE" "DATE" "TITLE"
  printf "%-35s %-10s %-25s %s\n" "----" "----" "----" "-----"

  for f in "$RECORDINGS_DIR"/*.cast; do
    local name=$(basename "$f")
    local size=$(du -h "$f" | cut -f1)
    local date=$(date -r "$f" '+%Y-%m-%d %H:%M')
    local title=$(head -1 "$f" | python3 -c "import sys,json; d=json.loads(sys.stdin.readline()); print(d.get('title',''))" 2>/dev/null || echo "")
    printf "%-35s %-10s %-25s %s\n" "$name" "$size" "$date" "$title"
  done
}

# Convert to GIF
cmd_gif() {
  local file="" output=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --output|-o) output="$2"; shift 2 ;;
      -*) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
      *) file="$1"; shift ;;
    esac
  done

  if [ -z "$file" ]; then
    echo -e "${RED}❌ Specify a .cast file.${NC}"; exit 1
  fi

  if [ -z "$output" ]; then
    output="${file%.cast}.gif"
  fi

  if command -v agg &>/dev/null; then
    echo -e "${BLUE}🎞️  Converting to GIF with agg...${NC}"
    agg "$file" "$output"
    echo -e "${GREEN}✅ GIF saved: $output ($(du -h "$output" | cut -f1))${NC}"
  else
    echo -e "${RED}❌ agg not installed.${NC}"
    echo "   Install: cargo install agg"
    echo "   Or download from: https://github.com/asciinema/agg/releases"
    exit 1
  fi
}

# Convert to SVG
cmd_svg() {
  local file="" output=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --output|-o) output="$2"; shift 2 ;;
      -*) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
      *) file="$1"; shift ;;
    esac
  done

  if [ -z "$file" ]; then
    echo -e "${RED}❌ Specify a .cast file.${NC}"; exit 1
  fi

  if [ -z "$output" ]; then
    output="${file%.cast}.svg"
  fi

  if command -v svg-term &>/dev/null; then
    echo -e "${BLUE}🎨 Converting to SVG...${NC}"
    cat "$file" | svg-term --out "$output"
    echo -e "${GREEN}✅ SVG saved: $output${NC}"
  else
    echo -e "${RED}❌ svg-term-cli not installed.${NC}"
    echo "   Install: npm install -g svg-term-cli"
    exit 1
  fi
}

# Trim a recording
cmd_trim() {
  local file="" output="" start_time="" end_time=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --start|-s) start_time="$2"; shift 2 ;;
      --end|-e) end_time="$2"; shift 2 ;;
      --output|-o) output="$2"; shift 2 ;;
      -*) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
      *) file="$1"; shift ;;
    esac
  done

  if [ -z "$file" ]; then
    echo -e "${RED}❌ Specify a .cast file.${NC}"; exit 1
  fi

  if [ -z "$output" ]; then
    output="${file%.cast}-trimmed.cast"
  fi

  python3 -c "
import json, sys

start = float('${start_time:-0}')
end = float('${end_time:-999999}')

with open('$file') as f:
    header = f.readline()
    events = []
    for line in f:
        try:
            ev = json.loads(line)
            if start <= ev[0] <= end:
                ev[0] = round(ev[0] - start, 6)
                events.append(ev)
        except:
            pass

with open('$output', 'w') as f:
    f.write(header)
    for ev in events:
        f.write(json.dumps(ev) + '\n')

print(f'Trimmed {len(events)} events to $output')
"

  echo -e "${GREEN}✅ Trimmed: $output${NC}"
}

# Concatenate recordings
cmd_concat() {
  local files=() output=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --output|-o) output="$2"; shift 2 ;;
      -*) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
      *) files+=("$1"); shift ;;
    esac
  done

  if [ ${#files[@]} -lt 2 ]; then
    echo -e "${RED}❌ Specify at least 2 .cast files to concatenate.${NC}"; exit 1
  fi

  if [ -z "$output" ]; then
    output="combined.cast"
  fi

  python3 -c "
import json, sys

files = '${files[*]}'.split()
output_events = []
offset = 0.0

for i, fname in enumerate(files):
    with open(fname) as f:
        header = json.loads(f.readline())
        if i == 0:
            out_header = header
        for line in f:
            try:
                ev = json.loads(line)
                ev[0] = round(ev[0] + offset, 6)
                output_events.append(ev)
            except:
                pass
    if output_events:
        offset = output_events[-1][0] + 0.5

with open('$output', 'w') as f:
    f.write(json.dumps(out_header) + '\n')
    for ev in output_events:
        f.write(json.dumps(ev) + '\n')

print(f'Combined {len(files)} files ({len(output_events)} events) into $output')
"

  echo -e "${GREEN}✅ Combined: $output${NC}"
}

# Show info about a recording
cmd_info() {
  local file="$1"

  if [ -z "$file" ]; then
    echo -e "${RED}❌ Specify a .cast file.${NC}"; exit 1
  fi

  python3 -c "
import json

with open('$file') as f:
    header = json.loads(f.readline())
    event_count = 0
    last_ts = 0
    for line in f:
        try:
            ev = json.loads(line)
            last_ts = ev[0]
            event_count += 1
        except:
            pass

print(f'📄 File: $file')
print(f'📝 Title: {header.get(\"title\", \"(none)\")}')
print(f'⏱️  Duration: {last_ts:.1f}s')
print(f'📊 Events: {event_count}')
w = header.get('width', '?')
h = header.get('height', '?')
print(f'📐 Size: {w}x{h}')
print(f'🔧 Version: {header.get(\"version\", \"?\")}')
env = header.get('env', {})
if env:
    print(f'🐚 Shell: {env.get(\"SHELL\", \"?\")}')
    print(f'💻 Term: {env.get(\"TERM\", \"?\")}')
"
}

# Main dispatch
check_deps

case "${1:-}" in
  record)  shift; cmd_record "$@" ;;
  play)    shift; cmd_play "$@" ;;
  upload)  shift; cmd_upload "$@" ;;
  list)    shift; cmd_list "$@" ;;
  gif)     shift; cmd_gif "$@" ;;
  svg)     shift; cmd_svg "$@" ;;
  trim)    shift; cmd_trim "$@" ;;
  concat)  shift; cmd_concat "$@" ;;
  info)    shift; cmd_info "$@" ;;
  help|-h|--help|"") usage ;;
  *) echo -e "${RED}Unknown command: $1${NC}"; usage; exit 1 ;;
esac
