---
name: font-installer
description: >-
  Install, manage, and organize system fonts from Google Fonts or local files.
categories: [design, productivity]
dependencies: [bash, curl, unzip, fc-cache]
---

# Font Installer

## What This Does

Download and install fonts from Google Fonts or local files with a single command. Search the Google Fonts catalog, batch-install font families, list installed fonts, and clean up unused ones. No GUI needed — everything runs in the terminal.

**Example:** "Install Inter, Fira Code, and JetBrains Mono, then list all monospace fonts on the system."

## Quick Start (2 minutes)

### 1. Install a Google Font

```bash
bash scripts/font-installer.sh install "Inter"
# Output:
# ✅ Downloaded Inter (4 variants)
# ✅ Installed to ~/.local/share/fonts/Inter/
# ✅ Font cache updated
```

### 2. Search Google Fonts

```bash
bash scripts/font-installer.sh search "mono"
# Output:
# 🔍 Results for "mono":
#   Fira Mono (3 variants) — monospace
#   JetBrains Mono (8 variants) — monospace
#   Space Mono (4 variants) — monospace
#   ...
```

### 3. List Installed Fonts

```bash
bash scripts/font-installer.sh list
# Output:
# 📋 Installed fonts (user):
#   Inter (Regular, Bold, Italic, Bold Italic)
#   Fira Code (Light, Regular, Medium, Bold)
```

## Core Workflows

### Workflow 1: Install from Google Fonts

```bash
# Single font
bash scripts/font-installer.sh install "Fira Code"

# Multiple fonts at once
bash scripts/font-installer.sh install "Inter" "JetBrains Mono" "Fira Code" "Roboto"

# Specific category
bash scripts/font-installer.sh install-category monospace
```

### Workflow 2: Install from Local File

```bash
# Install a .ttf or .otf file
bash scripts/font-installer.sh install-file /path/to/MyFont.ttf

# Install all fonts from a directory
bash scripts/font-installer.sh install-dir /path/to/fonts/

# Install from a .zip archive
bash scripts/font-installer.sh install-zip /path/to/fonts.zip
```

### Workflow 3: Search & Browse

```bash
# Search by name
bash scripts/font-installer.sh search "roboto"

# Browse by category
bash scripts/font-installer.sh browse serif
bash scripts/font-installer.sh browse sans-serif
bash scripts/font-installer.sh browse monospace
bash scripts/font-installer.sh browse display
bash scripts/font-installer.sh browse handwriting

# Show font details
bash scripts/font-installer.sh info "Inter"
```

### Workflow 4: List & Manage

```bash
# List user-installed fonts
bash scripts/font-installer.sh list

# List all system fonts matching a pattern
bash scripts/font-installer.sh list-all "mono"

# Remove a font family
bash scripts/font-installer.sh remove "Inter"

# Check if a font is installed
bash scripts/font-installer.sh check "Fira Code"
```

### Workflow 5: Batch Install from File

```bash
# Create a fonts.txt with one font per line
cat > fonts.txt << 'EOF'
Inter
Fira Code
JetBrains Mono
Roboto
Open Sans
Lato
Source Code Pro
EOF

# Install all
bash scripts/font-installer.sh install-list fonts.txt
```

### Workflow 6: Popular Font Packs

```bash
# Install popular developer fonts
bash scripts/font-installer.sh pack dev
# Installs: Fira Code, JetBrains Mono, Source Code Pro, Cascadia Code, Hack

# Install popular UI/design fonts
bash scripts/font-installer.sh pack design
# Installs: Inter, Roboto, Open Sans, Lato, Montserrat, Poppins

# Install popular serif fonts
bash scripts/font-installer.sh pack serif
# Installs: Merriweather, Lora, Playfair Display, Crimson Text, Libre Baskerville
```

## Configuration

### Environment Variables

```bash
# Custom font directory (default: ~/.local/share/fonts)
export FONT_DIR="$HOME/.local/share/fonts"

# Google Fonts API key (optional — increases rate limits)
export GOOGLE_FONTS_API_KEY="your-api-key"
```

### Font Directory Structure

```
~/.local/share/fonts/
├── Inter/
│   ├── Inter-Regular.ttf
│   ├── Inter-Bold.ttf
│   ├── Inter-Italic.ttf
│   └── Inter-BoldItalic.ttf
├── FiraCode/
│   ├── FiraCode-Light.ttf
│   ├── FiraCode-Regular.ttf
│   ├── FiraCode-Medium.ttf
│   └── FiraCode-Bold.ttf
└── ...
```

## Troubleshooting

### Issue: "fc-cache: command not found"

```bash
# Ubuntu/Debian
sudo apt-get install fontconfig

# Mac (use Homebrew)
brew install fontconfig
```

### Issue: Font not showing in applications

```bash
# Force rebuild font cache
fc-cache -fv

# Verify font is registered
fc-list | grep "FontName"
```

### Issue: Google Fonts API rate limited

Get a free API key at https://developers.google.com/fonts/docs/developer_api and set `GOOGLE_FONTS_API_KEY`.

## Dependencies

- `bash` (4.0+)
- `curl` (download fonts)
- `unzip` (extract archives)
- `fontconfig` (`fc-cache`, `fc-list` — font management)
- Optional: `jq` (for API parsing, falls back to grep)
