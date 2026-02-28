---
name: ascii-art-generator
description: >-
  Generate ASCII art from text, images, and banners using figlet, toilet, jp2a, and ImageMagick.
categories: [fun, media]
dependencies: [figlet, toilet, jp2a, imagemagick]
---

# ASCII Art Generator

## What This Does

Transform text into large ASCII banners, convert images to ASCII art, and create stylized text with custom fonts and effects. Uses real rendering tools — not text-generation approximations.

**Example:** Turn "HELLO" into a massive banner, convert a photo into terminal-displayable ASCII, or create colorized ANSI text art.

## Quick Start (2 minutes)

### 1. Install Dependencies

```bash
bash scripts/install.sh
```

### 2. Generate a Text Banner

```bash
bash scripts/run.sh banner "Hello World"
```

Output:
```
 _   _      _ _        __        __         _     _
| | | | ___| | | ___   \ \      / /__  _ __| | __| |
| |_| |/ _ \ | |/ _ \   \ \ /\ / / _ \| '__| |/ _` |
|  _  |  __/ | | (_) |   \ V  V / (_) | |  | | (_| |
|_| |_|\___|_|_|\___/     \_/\_/ \___/|_|  |_|\__,_|
```

### 3. Convert an Image to ASCII

```bash
bash scripts/run.sh image photo.jpg --width 80
```

### 4. Stylized Text with Effects

```bash
bash scripts/run.sh style "COOL" --font future --filter metal
```

## Core Workflows

### Workflow 1: Text Banners (figlet)

Create large text banners with 100+ fonts.

```bash
# Default font
bash scripts/run.sh banner "Deploy!"

# Specific font
bash scripts/run.sh banner "ALERT" --font slant

# List available fonts
bash scripts/run.sh fonts
```

**Popular fonts:** standard, slant, banner, big, block, bubble, digital, ivrit, lean, mini, script, shadow, small, smslant, speed, star

### Workflow 2: Styled Text (toilet)

Create colorized, styled text with border effects.

```bash
# Metal filter (shiny gradient)
bash scripts/run.sh style "WARNING" --filter metal

# Gay filter (rainbow colors)
bash scripts/run.sh style "PRIDE" --filter gay

# Border around text
bash scripts/run.sh style "BOXED" --filter border

# Combine font + filter
bash scripts/run.sh style "FANCY" --font future --filter metal
```

**Filters:** crop, gay, metal, flip, flop, 180, left, right, border

### Workflow 3: Image to ASCII (jp2a)

Convert JPEG/PNG images to ASCII art for terminal display.

```bash
# Basic conversion
bash scripts/run.sh image photo.jpg

# Set width (characters)
bash scripts/run.sh image photo.jpg --width 120

# Invert colors (for light terminals)
bash scripts/run.sh image photo.jpg --invert

# Use custom character set
bash scripts/run.sh image photo.jpg --chars " .:-=+*#%@"

# Convert from URL
bash scripts/run.sh image https://example.com/photo.jpg --width 80

# Save to file
bash scripts/run.sh image photo.jpg --width 80 --output art.txt
```

### Workflow 4: Batch Generation

Generate multiple banners or process multiple images.

```bash
# Generate banners for a list of words
bash scripts/run.sh batch-banner words.txt --font slant --output banners/

# Convert all images in a directory
bash scripts/run.sh batch-image ./photos/ --width 60 --output ascii-art/
```

### Workflow 5: Random Art

Generate random ASCII art for fun or decoration.

```bash
# Random font banner
bash scripts/run.sh random "Hello"

# Random styled text
bash scripts/run.sh random-style "Party Time"
```

## Configuration

### Environment Variables

```bash
# Default image width (characters)
export ASCII_WIDTH=80

# Default figlet font
export ASCII_FONT=standard

# Default toilet filter
export ASCII_FILTER=crop

# Custom character ramp for jp2a
export ASCII_CHARS=" .,:;i1tfLCG08@"
```

## Advanced Usage

### Pipe-Friendly

```bash
# Pipe text in
echo "Server OK" | bash scripts/run.sh banner --font mini

# Chain with other tools
bash scripts/run.sh banner "$(hostname)" --font small >> /etc/motd

# Use in scripts
STATUS=$(bash scripts/run.sh banner "DEPLOYED" --font slant)
echo "$STATUS" | mail -s "Deploy Complete" team@example.com
```

### Image Pre-Processing

For better ASCII art results, pre-process images:

```bash
# Increase contrast before converting
bash scripts/run.sh image photo.jpg --enhance --width 100

# Grayscale + high contrast
bash scripts/run.sh image photo.jpg --grayscale --width 80
```

### MOTD / Login Banner

```bash
# Set server login banner
bash scripts/run.sh banner "$(hostname)" --font slant | sudo tee /etc/motd

# Add system info
bash scripts/run.sh banner "PROD-01" --font small > /tmp/motd
echo "Uptime: $(uptime -p)" >> /tmp/motd
sudo mv /tmp/motd /etc/motd
```

## Troubleshooting

### Issue: "figlet: command not found"

```bash
bash scripts/install.sh
# Or manually:
sudo apt-get install -y figlet  # Debian/Ubuntu
brew install figlet              # macOS
```

### Issue: jp2a can't read PNG files

jp2a natively handles JPEG. The script auto-converts PNG→JPEG using ImageMagick:
```bash
sudo apt-get install -y imagemagick
```

### Issue: toilet filters not showing colors

Ensure your terminal supports ANSI colors. Pipe through `cat` to force color:
```bash
bash scripts/run.sh style "TEST" --filter metal | cat
```

### Issue: Image ASCII looks distorted

Adjust width to match your terminal:
```bash
# Check terminal width
tput cols

# Use 80% of terminal width
bash scripts/run.sh image photo.jpg --width $(($(tput cols) * 80 / 100))
```

## Dependencies

- `figlet` — Text banner generation (100+ fonts)
- `toilet` — Styled/colorized text with filters
- `jp2a` — Image to ASCII conversion
- `imagemagick` — Image pre-processing (PNG→JPEG, contrast, resize)
- `curl` — Download images from URLs
