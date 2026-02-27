#!/bin/bash
# Resume Builder — Main Build Script
# Converts YAML resume data to PDF, HTML, or Markdown
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Defaults
INPUT=""
FORMAT="${RESUME_FORMAT:-pdf}"
TEMPLATE="${RESUME_TEMPLATE:-modern}"
OUTPUT_DIR="${RESUME_OUTPUT_DIR:-./output}"
PAPER="${RESUME_PAPER:-letter}"
ENGINE="pdflatex"
SECTIONS=""
FILTER_SKILLS=""
OUTPUT_FILE=""
ALL_FORMATS=false
COVER_LETTER=false
COMPANY=""
ROLE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --format) FORMAT="$2"; shift 2 ;;
        --template) TEMPLATE="$2"; shift 2 ;;
        --output) OUTPUT_FILE="$2"; shift 2 ;;
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --paper) PAPER="$2"; shift 2 ;;
        --engine) ENGINE="$2"; shift 2 ;;
        --sections) SECTIONS="$2"; shift 2 ;;
        --filter-skills) FILTER_SKILLS="$2"; shift 2 ;;
        --cover-letter) COVER_LETTER=true; shift ;;
        --company) COMPANY="$2"; shift 2 ;;
        --role) ROLE="$2"; shift 2 ;;
        --all) ALL_FORMATS=true; shift ;;
        --help|-h)
            echo "Usage: bash build.sh <resume.yaml> [options]"
            echo ""
            echo "Options:"
            echo "  --format pdf|html|md    Output format (default: pdf)"
            echo "  --template NAME         Template: modern, classic, compact (default: modern)"
            echo "  --output FILE           Output filename"
            echo "  --output-dir DIR        Output directory (default: ./output)"
            echo "  --paper letter|a4       Paper size (default: letter)"
            echo "  --engine ENGINE         LaTeX engine: pdflatex, xelatex (default: pdflatex)"
            echo "  --sections LIST         Comma-separated sections to include"
            echo "  --filter-skills LIST    Only show these skills (comma-separated)"
            echo "  --cover-letter          Generate cover letter"
            echo "  --company NAME          Company name (for cover letter)"
            echo "  --role NAME             Role name (for cover letter)"
            echo "  --all                   Generate all formats (pdf, html, md)"
            exit 0
            ;;
        *)
            if [[ -z "$INPUT" ]]; then
                INPUT="$1"
            else
                echo "❌ Unknown option: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$INPUT" ]]; then
    echo "❌ Usage: bash build.sh <resume.yaml> [options]"
    exit 1
fi

if [[ ! -f "$INPUT" ]]; then
    echo "❌ File not found: $INPUT"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

# Convert YAML to JSON for easier processing
yaml_to_json() {
    python3 -c "
import sys, json, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
print(json.dumps(data, indent=2))
" "$1"
}

# Generate Markdown from YAML data
generate_markdown() {
    local input="$1"
    local sections="$2"
    local filter_skills="$3"
    python3 "$SCRIPT_DIR/yaml2md.py" "$input" "$sections" "$filter_skills"
}

# Generate cover letter markdown
generate_cover_letter() {
    local input="$1"
    local company="$2"
    local role="$3"
    python3 "$SCRIPT_DIR/yaml2cover.py" "$input" "$company" "$role"
}

# Get template file
get_template_header() {
    local template="$1"
    local template_file="$SKILL_DIR/templates/${template}.tex"

    if [[ -f "$template_file" ]]; then
        echo "$template_file"
    else
        echo ""
    fi
}

# Build function
build_format() {
    local fmt="$1"
    local md_content="$2"
    local base_name="${OUTPUT_FILE:-resume}"
    base_name="${base_name%.*}"

    case "$fmt" in
        pdf)
            local output_path="$OUTPUT_DIR/${base_name}.pdf"
            local template_header=$(get_template_header "$TEMPLATE")
            local header_opt=""

            if [[ -n "$template_header" ]]; then
                header_opt="-H $template_header"
            fi

            echo "$md_content" | pandoc \
                -f markdown \
                -o "$output_path" \
                --pdf-engine="$ENGINE" \
                -V geometry:margin=0.75in \
                -V papersize:"$PAPER" \
                -V fontsize:11pt \
                -V colorlinks:true \
                -V linkcolor:blue \
                -V urlcolor:blue \
                $header_opt \
                2>/dev/null

            local pages=$(pdfinfo "$output_path" 2>/dev/null | grep Pages | awk '{print $2}' || echo "?")
            local size=$(du -h "$output_path" | awk '{print $1}')
            echo "✅ $output_path ($pages pages, $size)"
            ;;
        html)
            local output_path="$OUTPUT_DIR/${base_name}.html"
            echo "$md_content" | pandoc \
                -f markdown \
                -o "$output_path" \
                --standalone \
                --metadata title="" \
                -c "https://cdn.jsdelivr.net/npm/water.css@2/out/water.min.css" \
                2>/dev/null
            local size=$(du -h "$output_path" | awk '{print $1}')
            echo "✅ $output_path ($size)"
            ;;
        md|markdown)
            local output_path="$OUTPUT_DIR/${base_name}.md"
            echo "$md_content" > "$output_path"
            local size=$(du -h "$output_path" | awk '{print $1}')
            echo "✅ $output_path ($size)"
            ;;
        *)
            echo "❌ Unknown format: $fmt"
            exit 1
            ;;
    esac
}

# Main
echo "📄 Building resume from $INPUT..."
echo "📐 Template: $TEMPLATE"

# Generate markdown
MD_CONTENT=$(generate_markdown "$INPUT" "$SECTIONS" "$FILTER_SKILLS")

if $ALL_FORMATS; then
    echo "🔨 Generating all formats..."
    build_format "pdf" "$MD_CONTENT"
    build_format "html" "$MD_CONTENT"
    build_format "md" "$MD_CONTENT"
elif $COVER_LETTER; then
    echo "✉️  Generating cover letter..."
    CL_CONTENT=$(generate_cover_letter "$INPUT" "$COMPANY" "$ROLE")
    OUTPUT_FILE="${OUTPUT_FILE:-cover-letter}"
    build_format "$FORMAT" "$CL_CONTENT"
else
    echo "🔨 Generating $FORMAT..."
    build_format "$FORMAT" "$MD_CONTENT"
fi

echo ""
echo "🎉 Done!"
