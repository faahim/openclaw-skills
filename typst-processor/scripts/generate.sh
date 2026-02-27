#!/bin/bash
# Generate documents from templates
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates"

# Defaults
OUTPUT=""
COMPILE=true

usage() {
  cat << 'EOF'
Usage: generate.sh <template> [options]

Templates: resume, invoice, letter, report, slides, notes

Resume options:
  --name NAME          Full name
  --title TITLE        Job title
  --email EMAIL        Email address
  --phone PHONE        Phone number
  --output FILE        Output PDF path

Invoice options:
  --from COMPANY       Your company name
  --to CLIENT          Client name
  --items ITEMS        Pipe-separated: "desc:qty:rate|desc:qty:rate"
  --invoice-no NUM     Invoice number
  --output FILE        Output PDF path

Letter options:
  --from NAME          Sender name
  --to NAME            Recipient name
  --subject SUBJ       Letter subject
  --body FILE          Body text file (or pass via stdin)
  --output FILE        Output PDF path

Report options:
  --title TITLE        Report title
  --author AUTHOR      Author name
  --output FILE        Output PDF path

Common:
  --no-compile         Generate .typ only, don't compile
  --output FILE        Output file path (default: <template>.pdf)
EOF
  exit 1
}

[ $# -lt 1 ] && usage
TEMPLATE="$1"; shift

# Parse common + template-specific args
declare -A ARGS
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-compile) COMPILE=false; shift ;;
    --output)     OUTPUT="$2"; shift 2 ;;
    --*)          key="${1#--}"; ARGS["$key"]="$2"; shift 2 ;;
    *)            echo "Unknown arg: $1"; exit 1 ;;
  esac
done

[ -z "$OUTPUT" ] && OUTPUT="${TEMPLATE}.pdf"
TYP_FILE="${OUTPUT%.pdf}.typ"

generate_resume() {
  local name="${ARGS[name]:-Your Name}"
  local title="${ARGS[title]:-Software Engineer}"
  local email="${ARGS[email]:-email@example.com}"
  local phone="${ARGS[phone]:-+1-234-567-8900}"
  
  cat > "$TYP_FILE" << TYPEOF
#set page(paper: "a4", margin: (x: 2cm, y: 1.5cm))
#set text(font: "DejaVu Sans", size: 10.5pt)
#set par(justify: true)

#align(center)[
  #text(size: 22pt, weight: "bold")[${name}]
  #v(4pt)
  #text(size: 12pt, fill: rgb("#555"))[${title}]
  #v(4pt)
  #text(size: 9.5pt)[#raw("${email}") · ${phone}]
]

#v(0.5cm)
#line(length: 100%, stroke: 0.5pt + rgb("#ccc"))
#v(0.3cm)

== Experience

*Senior Software Engineer* — Acme Corp #h(1fr) _2022 — Present_
- Led team of 5 engineers building distributed systems
- Reduced API latency by 40% through caching optimization
- Designed and shipped real-time notification system

*Software Engineer* — StartupXYZ #h(1fr) _2019 — 2022_
- Built core payment processing pipeline handling 2M+/month in transactions
- Migrated monolith to microservices architecture
- Mentored 3 junior developers

#v(0.3cm)
== Education

*B.S. Computer Science* — State University #h(1fr) _2015 — 2019_
- GPA: 3.8/4.0, Dean's List

#v(0.3cm)
== Skills

#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 8pt,
  [- TypeScript/JavaScript], [- Python], [- Go],
  [- React/Next.js], [- PostgreSQL], [- Docker/K8s],
  [- AWS/GCP], [- GraphQL], [- System Design],
)
TYPEOF
}

generate_invoice() {
  local from="${ARGS[from]:-Your Company}"
  local to="${ARGS[to]:-Client Name}"
  local invoice_no="${ARGS[invoice-no]:-INV-001}"
  local items_raw="${ARGS[items]:-Web Development:40:150|Design Review:8:120}"
  local today=$(date +%Y-%m-%d)
  local due=$(date -d "+30 days" +%Y-%m-%d 2>/dev/null || date -v+30d +%Y-%m-%d 2>/dev/null || echo "Due in 30 days")
  
  # Parse items into typst table rows
  local rows=""
  local total=0
  IFS='|' read -ra ITEMS <<< "$items_raw"
  for item in "${ITEMS[@]}"; do
    IFS=':' read -r desc qty rate <<< "$item"
    local amt=$((qty * rate))
    total=$((total + amt))
    rows+="  [${desc}], [${qty}], [\\$${rate}], [\\$${amt}],
"
  done
  
  cat > "$TYP_FILE" << TYPEOF
#set page(paper: "a4", margin: 2cm)
#set text(font: "DejaVu Sans", size: 11pt)

#grid(
  columns: (1fr, 1fr),
  align(left)[
    #text(size: 20pt, weight: "bold")[INVOICE]
    #v(4pt)
    #text(fill: rgb("#555"))[${invoice_no}]
  ],
  align(right)[
    #text(weight: "bold")[${from}]
    #linebreak()
    Date: ${today}
    #linebreak()
    Due: ${due}
  ],
)

#v(1cm)

*Bill To:*
#v(4pt)
${to}

#v(1cm)

#table(
  columns: (2fr, 0.5fr, 1fr, 1fr),
  stroke: 0.5pt + rgb("#ddd"),
  fill: (_, row) => if row == 0 { rgb("#f5f5f5") },
  [*Description*], [*Qty*], [*Rate*], [*Amount*],
${rows})

#v(0.5cm)
#align(right)[
  #text(size: 14pt, weight: "bold")[Total: \\$${total}]
]

#v(2cm)
#text(size: 9pt, fill: rgb("#888"))[
  Payment terms: Net 30. Please include invoice number with payment.
]
TYPEOF
}

generate_letter() {
  local from="${ARGS[from]:-Your Name}"
  local to="${ARGS[to]:-Recipient}"
  local subject="${ARGS[subject]:-Subject}"
  local body_file="${ARGS[body]:-}"
  local today=$(date +"%B %d, %Y")
  
  local body_text="Thank you for your time. I am writing to discuss the matter referenced above.

Please do not hesitate to reach out if you have any questions or require further information.

I look forward to hearing from you."

  if [ -n "$body_file" ] && [ -f "$body_file" ]; then
    body_text=$(cat "$body_file")
  fi
  
  cat > "$TYP_FILE" << TYPEOF
#set page(paper: "a4", margin: 2.5cm)
#set text(font: "DejaVu Sans", size: 11pt)
#set par(justify: true)

#align(right)[${today}]

#v(1cm)

*${to}*

#v(0.5cm)

*Re: ${subject}*

#v(0.5cm)

Dear ${to},

${body_text}

#v(1cm)

Sincerely,

#v(1cm)

*${from}*
TYPEOF
}

generate_report() {
  local title="${ARGS[title]:-Report Title}"
  local author="${ARGS[author]:-Author Name}"
  local today=$(date +"%B %d, %Y")
  
  cat > "$TYP_FILE" << TYPEOF
#set page(paper: "a4", margin: 2cm)
#set text(font: "DejaVu Sans", size: 11pt)
#set par(justify: true)
#set heading(numbering: "1.1")

#align(center)[
  #v(3cm)
  #text(size: 28pt, weight: "bold")[${title}]
  #v(1cm)
  #text(size: 14pt)[${author}]
  #v(0.5cm)
  #text(size: 12pt, fill: rgb("#666"))[${today}]
  #v(2cm)
]

#outline(title: "Table of Contents", indent: auto)
#pagebreak()

= Executive Summary

Provide a brief overview of the report's key findings and recommendations here.

= Background

Describe the context and motivation for this report.

== Problem Statement

Detail the specific problem or opportunity being addressed.

== Methodology

Explain the approach used for analysis.

= Findings

== Finding 1

Description of the first major finding with supporting data.

#table(
  columns: (1fr, 1fr, 1fr),
  [*Metric*], [*Current*], [*Target*],
  [Revenue], [\\\$100K], [\\\$150K],
  [Users], [1,200], [2,000],
  [Churn], [5%], [3%],
)

== Finding 2

Description of the second major finding.

= Recommendations

+ First recommendation with expected impact
+ Second recommendation with timeline
+ Third recommendation with resource requirements

= Conclusion

Summarize key takeaways and next steps.
TYPEOF
}

# Dispatch to template generator
case "$TEMPLATE" in
  resume)  generate_resume ;;
  invoice) generate_invoice ;;
  letter)  generate_letter ;;
  report)  generate_report ;;
  *)       echo "❌ Unknown template: $TEMPLATE"; usage ;;
esac

echo "📝 Generated: $TYP_FILE"

# Compile
if $COMPILE; then
  if command -v typst >/dev/null 2>&1; then
    typst compile "$TYP_FILE" "$OUTPUT"
    echo "✅ Compiled: $OUTPUT"
  elif [ -f "$HOME/.local/bin/typst" ]; then
    "$HOME/.local/bin/typst" compile "$TYP_FILE" "$OUTPUT"
    echo "✅ Compiled: $OUTPUT"
  else
    echo "⚠️  Typst not found. Run: bash scripts/install.sh"
    echo "   Then compile with: typst compile $TYP_FILE"
  fi
fi
