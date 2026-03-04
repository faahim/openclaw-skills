---
name: espanso-text-expander
description: >-
  Install and configure Espanso text expander — create snippets that auto-expand as you type.
categories: [productivity, automation]
dependencies: [bash, curl, espanso]
---

# Espanso Text Expander

## What This Does

Installs [Espanso](https://espanso.org), a cross-platform text expander written in Rust, and manages your snippet library. Type a trigger like `:email` and it expands to your full email address — everywhere on your system. Works in any app.

**Example:** Type `:date` → `2026-03-04`, `:sig` → your full email signature, `:shrug` → `¯\_(ツ)_/¯`

## Quick Start (5 minutes)

### 1. Install Espanso

```bash
bash scripts/install.sh
```

This detects your OS (Linux/macOS) and installs the latest Espanso binary.

### 2. Start Espanso

```bash
espanso start
```

### 3. Add Your First Snippet

```bash
bash scripts/add-snippet.sh ":email" "yourname@example.com"
# Now type :email anywhere → yourname@example.com
```

### 4. Import a Starter Pack

```bash
bash scripts/import-pack.sh starter
# Adds: :date, :time, :shrug, :lenny, :tableflip, common typo fixes
```

## Core Workflows

### Workflow 1: Add a Simple Text Snippet

```bash
bash scripts/add-snippet.sh "<trigger>" "<replacement>"

# Examples:
bash scripts/add-snippet.sh ":addr" "123 Main St, Anytown, USA 12345"
bash scripts/add-snippet.sh ":phone" "+1-555-0123"
bash scripts/add-snippet.sh ":zoom" "https://zoom.us/j/1234567890"
```

### Workflow 2: Add Multi-Line Snippets

```bash
bash scripts/add-snippet.sh ":meeting" "Hi team,

Please find the meeting notes below:

- Topic:
- Action items:
- Next steps:

Best regards"
```

### Workflow 3: Dynamic Snippets (Date/Time)

```bash
bash scripts/add-dynamic.sh ":today" "{{date}}" "%Y-%m-%d"
bash scripts/add-dynamic.sh ":now" "{{time}}" "%H:%M"
bash scripts/add-dynamic.sh ":iso" "{{date}}" "%Y-%m-%dT%H:%M:%S%z"
```

### Workflow 4: Clipboard Snippets

```bash
# Wrap clipboard contents in markdown code block
bash scripts/add-clipboard.sh ":code" '```\n{{clipboard}}\n```'

# Create a link with clipboard URL
bash scripts/add-clipboard.sh ":link" '[link]({{clipboard}})'
```

### Workflow 5: List & Search Snippets

```bash
bash scripts/list-snippets.sh              # List all snippets
bash scripts/list-snippets.sh --search email  # Search by keyword
bash scripts/list-snippets.sh --file         # Show which file each snippet is in
```

### Workflow 6: Remove a Snippet

```bash
bash scripts/remove-snippet.sh ":email"
```

### Workflow 7: Backup & Restore

```bash
bash scripts/backup.sh                    # Creates timestamped backup
bash scripts/backup.sh /path/to/backup    # Custom backup location
bash scripts/restore.sh /path/to/backup   # Restore from backup
```

### Workflow 8: Import Community Packages

```bash
# Espanso Hub packages
espanso package install all-emojis
espanso package install lorem
espanso package install html-utils
espanso package install math-symbols

# List installed packages
espanso package list
```

## Configuration

### Config File Locations

```bash
# Show espanso config path
espanso path

# Typical locations:
# Linux:  ~/.config/espanso/
# macOS:  ~/Library/Application Support/espanso/
```

### File Structure

```
~/.config/espanso/
├── config/
│   └── default.yml          # Global settings
└── match/
    ├── base.yml              # Default snippets
    ├── email.yml             # Email templates
    ├── code.yml              # Code snippets
    └── personal.yml          # Personal info
```

### Global Config (`config/default.yml`)

```yaml
# Espanso global config
toggle_key: ALT              # Key to toggle on/off
search_shortcut: ALT+SPACE   # Search snippets
search_trigger: off           # Disable search trigger in text
backend: auto                 # auto, clipboard, inject
```

### Match File Format (`match/*.yml`)

```yaml
matches:
  # Simple text replacement
  - trigger: ":email"
    replace: "you@example.com"

  # Multi-line
  - trigger: ":sig"
    replace: |
      Best regards,
      John Doe
      Engineering Lead

  # Dynamic date
  - trigger: ":date"
    replace: "{{today}}"
    vars:
      - name: today
        type: date
        params:
          format: "%Y-%m-%d"

  # Clipboard integration
  - trigger: ":upper"
    replace: "{{clipboard}}"
    vars:
      - name: clipboard
        type: clipboard
    # Result is uppercased via shell
    
  # Shell command output
  - trigger: ":ip"
    replace: "{{output}}"
    vars:
      - name: output
        type: shell
        params:
          cmd: "curl -s ifconfig.me"

  # Cursor placement
  - trigger: ":div"
    replace: "<div>$|$</div>"

  # Word triggers (only match whole word)
  - trigger: "teh"
    replace: "the"
    word: true

  # Case propagation
  - trigger: ":name"
    replace: "john doe"
    propagate_case: true
    # :name → john doe
    # :Name → John Doe
    # :NAME → JOHN DOE
```

## Starter Packs

### Import with Script

```bash
bash scripts/import-pack.sh starter    # Common snippets + typo fixes
bash scripts/import-pack.sh dev        # Developer snippets (git, docker, etc.)
bash scripts/import-pack.sh email      # Email templates
```

### Starter Pack Contents

**starter:** `:date`, `:time`, `:shrug`, `:lenny`, `:tableflip`, `:check`, `:x`, common typo fixes

**dev:** `:gcp` (git commit+push), `:dps` (docker ps), `:todo` (TODO comment), `:fixme`, `:bug`, `:sout` (console.log)

**email:** `:ack` (acknowledgment), `:followup`, `:intro`, `:thanks`, `:ooo` (out of office)

## App-Specific Snippets

```yaml
# Only trigger in specific apps
filter_title: "Visual Studio Code"
matches:
  - trigger: ":log"
    replace: "console.log('$|$');"

  - trigger: ":fn"
    replace: |
      function $|$() {
        
      }
```

## Troubleshooting

### Issue: Espanso not expanding

**Check:**
1. Is espanso running? `espanso status`
2. Restart: `espanso restart`
3. Check config syntax: `espanso match list` (errors show here)

### Issue: Not working in some apps (Linux)

**Fix:** Some apps need X11 or specific backends:
```yaml
# In config/default.yml
backend: clipboard    # Try clipboard backend if inject doesn't work
```

### Issue: Snippets not loading

**Check:**
1. YAML syntax is valid: `python3 -c "import yaml; yaml.safe_load(open('match/base.yml'))"`
2. File is in correct directory: `espanso path`
3. Restart after changes: `espanso restart`

### Issue: Search not working

**Fix:**
```yaml
# In config/default.yml
search_shortcut: ALT+SPACE
```

## Advanced: Regex Triggers

```yaml
matches:
  # Match pattern: :calc/1+2 → 3
  - regex: ":calc/(?P<expr>.*)"
    replace: "{{result}}"
    vars:
      - name: result
        type: shell
        params:
          cmd: "echo '{{expr}}' | bc"
```

## Dependencies

- `bash` (4.0+)
- `curl` (for installation)
- `espanso` (installed by script)
- Optional: `python3` (for YAML validation)
