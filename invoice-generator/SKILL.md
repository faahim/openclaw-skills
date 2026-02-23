---
name: invoice-generator
description: >-
  Generate professional PDF invoices from the command line using templates and structured data.
categories: [finance, productivity]
dependencies: [wkhtmltopdf, jq, bash]
---

# Invoice Generator

## What This Does

Generate professional PDF invoices from structured JSON data and HTML templates. No SaaS subscription, no manual formatting — pass in line items and get a polished PDF ready to send.

**Example:** "Generate invoice #INV-2026-042 for Acme Corp, 3 line items, net-30 terms → professional PDF in `invoices/INV-2026-042.pdf`"

## Quick Start (5 minutes)

### 1. Install Dependencies

```bash
# Install wkhtmltopdf (generates PDFs from HTML)
# Ubuntu/Debian
sudo apt-get install -y wkhtmltopdf

# macOS
brew install wkhtmltopdf

# Verify
wkhtmltopdf --version
which jq || sudo apt-get install -y jq
```

### 2. Generate Your First Invoice

```bash
# Quick single invoice
bash scripts/generate.sh \
  --number "INV-2026-001" \
  --from "Your Business Name" \
  --to "Client Name" \
  --item "Web Development|40|75.00" \
  --item "Design Work|10|90.00" \
  --due-days 30 \
  --output invoices/

# Output: invoices/INV-2026-001.pdf
```

### 3. Generate from JSON Data

```bash
# Create invoice data file
cat > invoice-data.json << 'EOF'
{
  "number": "INV-2026-002",
  "date": "2026-02-23",
  "due_date": "2026-03-25",
  "from": {
    "name": "Fahim's Studio",
    "address": "123 Dev Lane\nDhaka, Bangladesh",
    "email": "hello@fahim.dev"
  },
  "to": {
    "name": "Acme Corporation",
    "address": "456 Business Ave\nNew York, NY 10001",
    "email": "billing@acme.com"
  },
  "items": [
    {"description": "Frontend Development", "quantity": 40, "rate": 75.00},
    {"description": "UI/UX Design", "quantity": 15, "rate": 90.00},
    {"description": "Code Review & QA", "quantity": 8, "rate": 60.00}
  ],
  "currency": "USD",
  "tax_rate": 0,
  "notes": "Payment via bank transfer. Net 30.",
  "terms": "Late payments subject to 1.5% monthly interest."
}
EOF

bash scripts/generate.sh --json invoice-data.json --output invoices/
```

## Core Workflows

### Workflow 1: Quick Invoice from CLI

**Use case:** Generate a simple invoice without a JSON file.

```bash
bash scripts/generate.sh \
  --number "INV-2026-003" \
  --from "Your Name" \
  --to "Client Name" \
  --item "Consulting|5|150.00" \
  --item "Implementation|20|100.00" \
  --tax 10 \
  --currency "USD" \
  --due-days 14 \
  --notes "Thank you for your business!" \
  --output invoices/
```

### Workflow 2: Batch Generate from Directory

**Use case:** Generate multiple invoices from a folder of JSON files.

```bash
# Place JSON files in a directory
ls pending-invoices/
# client-a.json  client-b.json  client-c.json

bash scripts/batch.sh --input pending-invoices/ --output invoices/
# Generated: invoices/INV-2026-010.pdf
# Generated: invoices/INV-2026-011.pdf
# Generated: invoices/INV-2026-012.pdf
```

### Workflow 3: Custom Template

**Use case:** Use your own branded HTML template.

```bash
bash scripts/generate.sh \
  --json invoice-data.json \
  --template templates/custom.html \
  --output invoices/
```

### Workflow 4: Invoice Tracking

**Use case:** Keep a ledger of all generated invoices.

```bash
# List all invoices
bash scripts/ledger.sh --list

# Output:
# INV-2026-001  2026-02-01  Acme Corp       $3,900.00  PAID
# INV-2026-002  2026-02-15  Beta Inc        $4,830.00  PENDING
# INV-2026-003  2026-02-23  Gamma LLC       $2,750.00  OVERDUE

# Mark as paid
bash scripts/ledger.sh --paid INV-2026-002

# Check overdue invoices
bash scripts/ledger.sh --overdue
```

## Configuration

### Default Settings

```bash
# Create config file (optional — overrides defaults)
cat > ~/.invoice-generator.conf << 'EOF'
# Business defaults
DEFAULT_FROM_NAME="Your Business Name"
DEFAULT_FROM_ADDRESS="123 Your Street\nYour City, Country"
DEFAULT_FROM_EMAIL="billing@yourbusiness.com"
DEFAULT_CURRENCY="USD"
DEFAULT_TAX_RATE=0
DEFAULT_DUE_DAYS=30
DEFAULT_NOTES="Thank you for your business!"
DEFAULT_TERMS="Net 30. Late payments subject to 1.5% monthly interest."

# Output
INVOICE_DIR="$HOME/invoices"
LEDGER_FILE="$HOME/invoices/ledger.json"

# Numbering
AUTO_NUMBER=true
NUMBER_PREFIX="INV"
NUMBER_YEAR=true
EOF
```

### Custom Templates

Templates use HTML with `{{placeholder}}` variables:

```
{{invoice_number}}, {{date}}, {{due_date}}
{{from_name}}, {{from_address}}, {{from_email}}
{{to_name}}, {{to_address}}, {{to_email}}
{{items_table}}, {{subtotal}}, {{tax}}, {{total}}
{{currency}}, {{notes}}, {{terms}}
```

## Troubleshooting

### Issue: "wkhtmltopdf: command not found"

```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y wkhtmltopdf

# If headless server (no X11)
sudo apt-get install -y xvfb wkhtmltopdf
# Use xvfb-run wrapper (script handles this automatically)
```

### Issue: PDF looks broken / missing fonts

```bash
# Install common fonts
sudo apt-get install -y fonts-liberation fonts-dejavu-core

# For CJK support
sudo apt-get install -y fonts-noto-cjk
```

### Issue: Currency symbol not showing

Make sure your template uses UTF-8 encoding. The default template handles USD ($), EUR (€), GBP (£), BDT (৳), and others.

## Dependencies

- `bash` (4.0+)
- `wkhtmltopdf` (HTML to PDF conversion)
- `jq` (JSON parsing)
- Optional: `xvfb` (for headless servers without X11)
